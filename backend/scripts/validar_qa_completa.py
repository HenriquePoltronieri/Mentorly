"""Integracao real em banco exclusivo de QA. Nunca usa a base pessoal."""
import os
import sys
import re
import uuid
import unittest
from pathlib import Path
from datetime import timedelta
from concurrent.futures import ThreadPoolExecutor

os.environ.update(DB_NAME='mentorly_qa_completa', MAIL_SERVER='', SMTP_HOST='', APP_ENV='development',
                  DEV_EXPOSE_AUTH_CODES='false')
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app import create_app
from database.connection import init_database, install_schema, install_procedures, query_one, execute, insert
from config import DB_CONFIG
from auth.jwt_utils import gerar_token
from auth.downloads import gerar_permissao
from services.auth.cadastro_coordenacao import CadastroCoordenacaoService
from services.acesso_escola import alterar, consultar, hoje, iniciar_teste, cadastrar_escolas_existentes
from services.rate_limit import limiter, _consumir_no_banco, LimiteExcedido
from werkzeug.security import generate_password_hash
from services.professor.notas import LancarNotasService
from services.academico.calculo import calcular_desempenho_etapa

assert DB_CONFIG['database'] == 'mentorly_qa_completa'


class IntegracaoCompletaTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        init_database()
        install_schema()
        install_procedures()
        cls.app = create_app()
        cls.app.config.update(TESTING=True)
        chave = uuid.uuid4().hex
        cls.admin_email = f'admin-{chave}@qa.invalid'
        cls.admin = insert('INSERT INTO administrador(nome,email,senha_hash) VALUES (%s,%s,%s)',
                           ('Responsável QA', cls.admin_email, generate_password_hash('senha-segura-qa-123')))
        cls.escolas = []
        for nome in ('Escola QA <script>alert(1)</script>', 'Outra escola QA'):
            res = CadastroCoordenacaoService().execute(nome, uuid.uuid4().hex+'@qa.invalid', 'senha-qa-123')
            cls.escolas.append(res['usuario']['id'])
        cls.escola = cls.escolas[0]
        cls.coord = {'Authorization': 'Bearer '+gerar_token(cls.escola, 'coordenacao', cls.escola)}
        cls.prof = insert('INSERT INTO professor(coordenacao_id,nome,email,senha_hash) VALUES (%s,%s,%s,%s)',
                          (cls.escola, 'Professor QA', uuid.uuid4().hex+'@qa.invalid', generate_password_hash('senha-qa-123')))
        cls.prof_headers = {'Authorization': 'Bearer '+gerar_token(cls.prof, 'professor', cls.escola)}
        insert("INSERT INTO ano_letivo(coordenacao_id,ano,status) VALUES (%s,2026,'atual')", (cls.escola,))
        cls.turma = insert("INSERT INTO turma(coordenacao_id,nome,disciplina,turno,ano_letivo) VALUES (%s,'QA','Matemática','Manhã',2026)", (cls.escola,))
        insert('INSERT INTO professor_turma(coordenacao_id,professor_id,turma_id) VALUES (%s,%s,%s)', (cls.escola, cls.prof, cls.turma))
        cls.aluno = insert("INSERT INTO aluno(turma_id,nome,matricula) VALUES (%s,'Aluno fictício','QA1')", (cls.turma,))
        cls.etapa = insert("INSERT INTO etapa(coordenacao_id,nome,ordem,ano_letivo,nota_minima,nota_maxima) VALUES (%s,'Etapa QA',1,2026,6,10)", (cls.escola,))
        cls.criterio = insert("INSERT INTO criterio(coordenacao_id,etapa_id,nome,peso,nota_maxima) VALUES (%s,%s,'Avaliações',100,10)", (cls.escola, cls.etapa))
        cls.atividade = insert("INSERT INTO atividade(coordenacao_id,turma_id,professor_id,etapa_id,criterio_id,titulo,nota_maxima) VALUES (%s,%s,%s,%s,%s,'Atividade de 2 pontos',2)", (cls.escola, cls.turma, cls.prof, cls.etapa, cls.criterio))

    def setUp(self):
        limiter.reset()
        execute("UPDATE acesso_escola SET situacao='teste',valido_ate=%s WHERE coordenacao_id=%s", (hoje()+timedelta(days=14), self.escola))
        self.client = self.app.test_client()

    def logar_admin(self):
        csrf = self.client.get('/api/admin/sessao').json['csrf']
        r = self.client.post('/api/admin/login', headers={'X-CSRF-Token': csrf},
                             json={'email': self.admin_email, 'senha': 'senha-segura-qa-123'})
        self.assertEqual(r.status_code, 200)
        return r.json['csrf']

    def dados_acesso(self, **extras):
        linha = query_one('SELECT versao FROM acesso_escola WHERE coordenacao_id=%s', (self.escola,))
        return {'versao': linha['versao'], 'situacao': 'cortesia', 'plano_codigo': 'escolar',
                'valido_ate': '', 'motivo': 'Demonstração autorizada', **extras}

    def test_16_crud_turmas_e_busca_passam_pelas_camadas(self):
        nome = 'Turma QA ' + uuid.uuid4().hex[:8]
        criado = self.client.post('/api/classes', headers=self.coord,
                                  json={'name': nome, 'ano_letivo': 2026})
        self.assertEqual(criado.status_code, 201, criado.text)
        turma_id = criado.json['id']
        self.assertEqual(query_one('SELECT nome FROM turma WHERE id=%s', (turma_id,))['nome'], nome)
        self.assertIn(turma_id, [t['id'] for t in self.client.get('/api/classes', headers=self.coord).json])
        relatorio_coord = self.client.get('/api/classes/relatorio/atividades', headers=self.coord)
        relatorio_prof = self.client.get('/api/classes/relatorio/atividades', headers=self.prof_headers)
        self.assertEqual(relatorio_coord.status_code, 200, relatorio_coord.text)
        self.assertEqual(relatorio_prof.status_code, 200, relatorio_prof.text)
        self.assertIn(turma_id, [t['id'] for t in relatorio_coord.json])
        self.assertNotIn(turma_id, [t['id'] for t in relatorio_prof.json])
        outro_nome = nome + ' editada'
        editado = self.client.put(f'/api/classes/{turma_id}', headers=self.coord,
                                  json={'name': outro_nome})
        self.assertEqual(editado.status_code, 200, editado.text)
        self.assertEqual(query_one('SELECT nome FROM turma WHERE id=%s', (turma_id,))['nome'], outro_nome)
        self.assertEqual(self.client.delete(f'/api/classes/{turma_id}', headers=self.coord).status_code, 204)
        self.assertIsNone(query_one('SELECT id FROM turma WHERE id=%s', (turma_id,)))
        self.assertEqual(self.client.get('/api/activities/buscar', headers=self.prof_headers).status_code, 200)
        boletim = self.client.get(f'/api/professor/turmas/{self.turma}/boletim',
                                  headers=self.prof_headers)
        self.assertEqual(boletim.status_code, 200, boletim.text)
        self.assertEqual(boletim.json['turma_id'], self.turma)

    def test_01_teste_inicial_nao_renova_quando_reinicia(self):
        antes = consultar(self.escola)['valido_ate']
        iniciar_teste(self.escola)
        cadastrar_escolas_existentes()
        self.assertEqual(consultar(self.escola)['valido_ate'], antes)

    def test_02_suspensao_bloqueia_tokens_antigos_dos_dois_papeis(self):
        execute("UPDATE acesso_escola SET situacao='suspensa' WHERE coordenacao_id=%s", (self.escola,))
        for url, cabecalho in (('/api/classes', self.coord), ('/api/professor/turmas', self.prof_headers)):
            r = self.client.get(url, headers=cabecalho)
            self.assertEqual((r.status_code, r.json['code']), (403, 'escola_sem_acesso'))
        self.assertEqual(self.client.get('/api/acesso', headers=self.coord).status_code, 200)
        self.assertFalse(self.client.get('/api/acesso', headers=self.coord).json['liberado'])

    def test_03_cortesia_libera_sem_pagamento(self):
        alterar(self.escola, self.admin, self.dados_acesso())
        self.assertTrue(consultar(self.escola)['liberado'])
        self.assertEqual(self.client.get('/api/professor/turmas', headers=self.prof_headers).status_code, 200)

    def test_04_prazo_vencido_bloqueia_tambem_download(self):
        execute('UPDATE acesso_escola SET valido_ate=%s WHERE coordenacao_id=%s', (hoje()-timedelta(days=1), self.escola))
        caminho = f'/api/atividades/{self.atividade}/notas/modelo-planilha'
        ticket = gerar_permissao({'id': self.prof, 'tipo': 'professor', 'coordenacao_id': self.escola}, caminho)
        self.assertEqual(self.client.get(caminho+'?token='+ticket).status_code, 403)

    def test_05_escola_nao_pode_virar_admin(self):
        self.assertEqual(self.client.get('/api/admin/escolas', headers=self.coord).status_code, 401)
        r = self.client.put('/api/admin/escolas/%s/acesso' % self.escola, headers=self.coord, json=self.dados_acesso())
        self.assertEqual(r.status_code, 400)
        self.assertEqual(consultar(self.escola)['situacao'], 'teste')

    def test_06_admin_formulario_historico_escape_e_reenvio(self):
        csrf = self.logar_admin()
        dados = self.dados_acesso(motivo='<script>texto de teste</script>')
        caminho = f'/api/admin/escolas/{self.escola}/acesso'
        quantidade = query_one('SELECT COUNT(*) AS n FROM acesso_historico WHERE coordenacao_id=%s', (self.escola,))['n']
        self.assertEqual(self.client.put(caminho, json=dados, headers={'X-CSRF-Token': csrf}).status_code, 200)
        repetido = self.client.put(caminho, json=dados, headers={'X-CSRF-Token': csrf})
        self.assertEqual(repetido.status_code, 400)
        self.assertIn('já foi alterado', repetido.json['error'])
        self.assertEqual(query_one('SELECT COUNT(*) AS n FROM acesso_historico WHERE coordenacao_id=%s', (self.escola,))['n'], quantidade+1)
        r = self.client.get('/api/admin/escolas')
        self.assertEqual(r.mimetype, 'application/json')
        self.assertEqual(r.headers['X-Content-Type-Options'], 'nosniff')
        self.assertEqual(r.json['historico'][0]['motivo'], '<script>texto de teste</script>')

    def test_07_duas_alteracoes_simultaneas_nao_se_sobrepoem(self):
        dados = self.dados_acesso()
        def gravar(_):
            try:
                alterar(self.escola, self.admin, dados)
                return 'salvo'
            except ValueError:
                return 'recusado'
        with ThreadPoolExecutor(max_workers=2) as pool:
            resultados = list(pool.map(gravar, range(2)))
        self.assertEqual(sorted(resultados), ['recusado', 'salvo'])

    def test_08_entrada_invalida_nao_altera_acesso(self):
        for extras in ({'situacao': 'administrador'}, {'plano_codigo': "' OR 1=1 --"},
                       {'situacao': 'paga', 'valido_ate': ''}, {'valido_ate': 'data inválida'}, {'motivo': ''}):
            with self.subTest(extras=extras), self.assertRaises(ValueError):
                alterar(self.escola, self.admin, self.dados_acesso(**extras))

    def test_09_notas_repetidas_nao_duplicam_e_nao_inflam(self):
        for _ in range(15):
            LancarNotasService().execute(self.atividade, self.prof, {'notas': [{'aluno_id': self.aluno, 'valor': 2}]})
        self.assertEqual(query_one('SELECT COUNT(*) AS n FROM nota WHERE atividade_id=%s AND aluno_id=%s', (self.atividade, self.aluno))['n'], 1)
        etapa = {'id': self.etapa, 'coordenacao_id': self.escola, 'nota_minima': 6, 'nota_maxima': 10}
        resultado = calcular_desempenho_etapa(self.aluno, self.turma, etapa)
        self.assertEqual(resultado['nota_parcial'], 2)
        self.assertIsNone(resultado['nota_calculada'])
        for valor in (-1, 2.01, 1.999, float('nan'), float('inf'), True):
            with self.subTest(valor=valor), self.assertRaises(ValueError):
                LancarNotasService().execute(self.atividade, self.prof, {'notas': [{'aluno_id': self.aluno, 'valor': valor}]})

    def test_10_download_permissao_curta_e_isolamento(self):
        caminho = f'/atividades/{self.atividade}/notas/modelo-planilha'
        r = self.client.get('/api/downloads/autorizar', query_string={'caminho': caminho}, headers=self.prof_headers)
        self.assertEqual(r.status_code, 200)
        ticket = r.json['token']
        self.assertEqual(self.client.get('/api'+caminho, query_string={'token': ticket}).status_code, 200)
        self.assertEqual(self.client.get('/api'+caminho, query_string={'token': self.prof_headers['Authorization'][7:]}).status_code, 401)
        self.assertEqual(self.client.get('/api/classes', query_string={'token': ticket}).status_code, 401)
        self.assertEqual(self.client.get('/api/downloads/autorizar', query_string={'caminho': '/classes'}, headers=self.prof_headers).status_code, 400)

    def test_11_limite_persistente_sob_concorrencia(self):
        chave = uuid.uuid4().hex
        def tentar(_):
            try:
                _consumir_no_banco('qa', chave, 5, 60, 'Devagar')
                return True
            except LimiteExcedido:
                return False
        with ThreadPoolExecutor(max_workers=10) as pool:
            resultados = list(pool.map(tentar, range(20)))
        self.assertEqual(sum(resultados), 5)

    def test_12_admin_desativado_perde_sessao(self):
        self.logar_admin()
        execute('UPDATE administrador SET versao_sessao=versao_sessao+1 WHERE id=%s', (self.admin,))
        self.assertEqual(self.client.get('/api/admin/escolas').status_code, 401)

    def test_13_tamper_json_e_upload_gigante(self):
        for corpo in ([], 'texto', 42, True):
            r = self.client.post('/api/classes', json=corpo, headers=self.coord)
            self.assertEqual(r.status_code, 400)
        r = self.client.post('/api/auth/login-coordenacao', data=b'x'*(5*1024*1024+1), content_type='application/json')
        self.assertEqual(r.status_code, 413)

    def test_14_uma_escola_nao_consulta_outra(self):
        outro = self.escolas[1]
        headers = {'Authorization': 'Bearer '+gerar_token(outro, 'coordenacao', outro)}
        self.assertEqual(self.client.get(f'/api/coordenacao/turmas/{self.turma}/alunos', headers=headers).status_code, 404)
        self.assertNotEqual(self.client.get('/api/acesso', headers=headers).json['coordenacao_id'], self.escola)

    def test_15_migracao_repetida_preserva_notas_senhas_e_cortesias(self):
        from database.connection import install_comercial
        alterar(self.escola, self.admin, self.dados_acesso())
        senha = query_one('SELECT senha_hash FROM coordenacao WHERE id=%s', (self.escola,))['senha_hash']
        quantidade = query_one('SELECT COUNT(*) AS n FROM nota WHERE atividade_id=%s', (self.atividade,))['n']
        for _ in range(2):
            install_comercial()
        self.assertEqual(consultar(self.escola)['situacao'], 'cortesia')
        self.assertEqual(query_one('SELECT senha_hash FROM coordenacao WHERE id=%s', (self.escola,))['senha_hash'], senha)
        self.assertEqual(query_one('SELECT COUNT(*) AS n FROM nota WHERE atividade_id=%s', (self.atividade,))['n'], quantidade)


if __name__ == '__main__':
    unittest.main(verbosity=2)

"""QA administrativo com MySQL real e banco ficticio exclusivo de testes.

Inclui as regressões de escolas/notas da suite de integracao e os ataques
contra sessao, CSRF, login, permissao, reenvio e validacao administrativa.
"""
import sys
import time
import uuid
import io
from pathlib import Path
from contextlib import redirect_stdout
from unittest import main
from unittest.mock import patch
from concurrent.futures import ThreadPoolExecutor

sys.path.insert(0, str(Path(__file__).resolve().parent))
import validar_qa_completa as qa
from database.connection import query_one, execute, insert
from werkzeug.security import generate_password_hash, check_password_hash
from services.rate_limit import limiter
from services.acesso_escola import consultar
from services.auth.cadastro_coordenacao import CadastroCoordenacaoService
from scripts import criar_admin


class AdminSegurancaTest(qa.IntegracaoCompletaTest):
    def test_admin_csrf_ausente_errado_unicode_e_longo_nao_quebram(self):
        self.client.get('/api/admin/sessao')
        for token in ('', 'errado', 'não-é-o-código', 'x'*8000):
            with self.subTest(token_tamanho=len(token)):
                r = self.client.post('/api/admin/login', json={'email': self.admin_email, 'senha': 'x'},
                                     headers={'X-CSRF-Token': token})
                self.assertEqual(r.status_code, 400)
                self.assertNotIn('Traceback', r.text)

    def test_admin_login_roda_csrf_e_revoga_codigo_anterior(self):
        antigo = self.client.get('/api/admin/sessao').json['csrf']
        novo = self.logar_admin()
        self.assertNotEqual(antigo, novo)
        r = self.client.put(f'/api/admin/escolas/{self.escola}/acesso', json=self.dados_acesso(),
                            headers={'X-CSRF-Token': antigo})
        self.assertEqual(r.status_code, 400)
        self.assertEqual(consultar(self.escola)['situacao'], 'teste')

    def test_admin_cookie_falso_e_token_escolar_nao_autorizam(self):
        self.client.set_cookie('mentorly_admin', 'cookie-forjado')
        for headers in ({}, self.coord, self.prof_headers):
            self.assertEqual(self.client.get('/api/admin/escolas', headers=headers).status_code, 401)

    def test_admin_login_injecao_sql_senha_errada_e_inexistente(self):
        csrf = self.client.get('/api/admin/sessao').json['csrf']
        for email, senha in (("' OR 1=1 --", 'x'), (self.admin_email, "' OR 1=1 --"),
                             ('nao-existe@qa.invalid', 'x'), (self.admin_email, '')):
            with self.subTest(email=email):
                r = self.client.post('/api/admin/login', json={'email': email, 'senha': senha},
                                     headers={'X-CSRF-Token': csrf})
                self.assertEqual(r.status_code, 401)
                self.assertEqual(r.json, {'error': 'E-mail ou senha inválidos.'})

    def test_admin_login_campos_malformados_sao_400(self):
        csrf = self.client.get('/api/admin/sessao').json['csrf']
        for dados in ({'email': [], 'senha': 'x'}, {'email': self.admin_email, 'senha': {}},
                      {'email': self.admin_email, 'senha': 'x'*129}, {'email': 'a'*151, 'senha': 'x'}):
            self.assertEqual(self.client.post('/api/admin/login', json=dados,
                headers={'X-CSRF-Token': csrf}).status_code, 400)

    def test_admin_forca_bruta_11a_tentativa_e_429(self):
        csrf = self.client.get('/api/admin/sessao').json['csrf']
        for _ in range(10):
            r = self.client.post('/api/admin/login', json={'email': self.admin_email, 'senha': 'errada'},
                                 headers={'X-CSRF-Token': csrf})
            self.assertEqual(r.status_code, 401)
        r = self.client.post('/api/admin/login', json={'email': self.admin_email, 'senha': 'senha-segura-qa-123'},
                             headers={'X-CSRF-Token': csrf})
        self.assertEqual(r.status_code, 429)
        self.assertGreater(int(r.headers['Retry-After']), 0)

    def test_admin_desativado_nao_entra_nem_reutiliza_cookie(self):
        self.logar_admin()
        execute('UPDATE administrador SET ativo=0 WHERE id=%s', (self.admin,))
        try:
            self.assertEqual(self.client.get('/api/admin/escolas').status_code, 401)
            csrf = self.client.get('/api/admin/sessao').json['csrf']
            r = self.client.post('/api/admin/login', json={'email': self.admin_email, 'senha': 'senha-segura-qa-123'},
                                 headers={'X-CSRF-Token': csrf})
            self.assertEqual(r.status_code, 401)
        finally:
            execute('UPDATE administrador SET ativo=1 WHERE id=%s', (self.admin,))

    def test_admin_sair_invalida_cookie_copiado(self):
        csrf = self.logar_admin()
        cookie = self.client.get_cookie('mentorly_admin').value
        self.assertEqual(self.client.post('/api/admin/sair', json={}, headers={'X-CSRF-Token': csrf}).status_code, 200)
        repeticao = self.app.test_client()
        repeticao.set_cookie('mentorly_admin', cookie)
        self.assertEqual(repeticao.get('/api/admin/escolas').status_code, 401)

    def test_admin_cookie_expira_apos_duas_horas(self):
        self.logar_admin()
        futuro = time.time() + 7201
        with patch('itsdangerous.timed.time.time', return_value=futuro):
            self.assertEqual(self.client.get('/api/admin/escolas').status_code, 401)

    def test_admin_logout_sem_csrf_nao_encerra_sessao(self):
        self.logar_admin()
        self.assertEqual(self.client.post('/api/admin/sair', json={}).status_code, 400)
        self.assertEqual(self.client.get('/api/admin/escolas').status_code, 200)

    def test_admin_nao_tem_cadastro_publico(self):
        self.assertIn(self.client.post('/api/admin/cadastro', json={}).status_code, (404, 405))

    def test_admin_respostas_nao_expoem_hash_cookie_ou_dados_de_alunos(self):
        self.logar_admin()
        r = self.client.get('/api/admin/escolas')
        self.assertEqual(r.status_code, 200)
        for proibido in ('senha_hash', 'Aluno fictício', 'DB_PASSWORD', 'SECRET_KEY'):
            self.assertNotIn(proibido, r.text)
        self.assertEqual(r.headers['Cache-Control'], 'no-store')

    def test_admin_cookie_httponly_samesite_e_seguro_em_producao(self):
        with patch.object(qa.create_app.__globals__['config'], 'PRODUCAO', True), \
                patch.object(qa.create_app.__globals__['config'], 'validar_producao'):
            import os
            with patch.dict(os.environ, {'TRUSTED_HOSTS': 'localhost'}):
                r = qa.create_app().test_client().get('/api/admin/sessao', base_url='https://localhost')
        cookie = r.headers['Set-Cookie']
        for regra in ('HttpOnly', 'Secure', 'SameSite=Strict'):
            self.assertIn(regra, cookie)

    def test_admin_cors_nao_confia_em_origem_desconhecida(self):
        self.logar_admin()
        r = self.client.get('/api/admin/escolas', headers={'Origin': 'https://invasor.invalid'})
        self.assertNotIn('Access-Control-Allow-Origin', r.headers)
        self.assertNotIn('Access-Control-Allow-Credentials', r.headers)

    def test_admin_dados_malformados_nao_geram_500_ou_alteracao(self):
        csrf = self.logar_admin()
        antes = query_one('SELECT versao FROM acesso_escola WHERE coordenacao_id=%s', (self.escola,))['versao']
        for extra in ({'situacao': []}, {'situacao': {}}, {'motivo': 'x'*501}, {'versao': True},
                      {'versao': 'invalida'}, {'valido_ate': '0001-01-01'}, {'valido_ate': '2026-02-30'}):
            r = self.client.put(f'/api/admin/escolas/{self.escola}/acesso',
                                json=self.dados_acesso(**extra), headers={'X-CSRF-Token': csrf})
            self.assertEqual(r.status_code, 400, r.text)
        self.assertEqual(query_one('SELECT versao FROM acesso_escola WHERE coordenacao_id=%s', (self.escola,))['versao'], antes)

    def test_admin_autor_do_historico_vem_da_sessao(self):
        csrf = self.logar_admin()
        r = self.client.put(f'/api/admin/escolas/{self.escola}/acesso',
                            json=self.dados_acesso(administrador_id=999999), headers={'X-CSRF-Token': csrf})
        self.assertEqual(r.status_code, 200)
        registro = query_one('SELECT administrador_id FROM acesso_historico WHERE coordenacao_id=%s ORDER BY id DESC LIMIT 1', (self.escola,))
        self.assertEqual(registro['administrador_id'], self.admin)

    def test_admin_escola_inexistente_nao_cria_registro(self):
        csrf = self.logar_admin()
        r = self.client.put('/api/admin/escolas/2147483647/acesso', json=self.dados_acesso(), headers={'X-CSRF-Token': csrf})
        self.assertEqual(r.status_code, 400)

    def test_admin_duplo_clique_http_grava_uma_vez(self):
        csrf = self.logar_admin()
        cookie = self.client.get_cookie('mentorly_admin').value
        dados = self.dados_acesso()
        quantidade = query_one('SELECT COUNT(*) AS n FROM acesso_historico WHERE coordenacao_id=%s', (self.escola,))['n']
        def salvar(_):
            client = self.app.test_client()
            client.set_cookie('mentorly_admin', cookie)
            return client.put(f'/api/admin/escolas/{self.escola}/acesso', json=dados,
                              headers={'X-CSRF-Token': csrf}).status_code
        with ThreadPoolExecutor(max_workers=2) as pool:
            resultados = list(pool.map(salvar, range(2)))
        self.assertEqual(sorted(resultados), [200, 400])
        self.assertEqual(query_one('SELECT COUNT(*) AS n FROM acesso_historico WHERE coordenacao_id=%s', (self.escola,))['n'], quantidade+1)

    def test_admin_segundo_cadastro_preserva_primeiro_e_aceita_senha_curta(self):
        email = 'segundo-'+uuid.uuid4().hex+'@qa.invalid'
        with patch('builtins.input', side_effect=['Segundo administrador', email]), \
                patch.object(criar_admin, 'getpass', side_effect=['a', 'a']), redirect_stdout(io.StringIO()):
            criar_admin.criar_admin()
        novo = query_one('SELECT id,senha_hash FROM administrador WHERE email=%s', (email,))
        self.assertNotEqual(novo['id'], self.admin)
        self.assertTrue(check_password_hash(novo['senha_hash'], 'a'))
        self.assertIsNotNone(query_one('SELECT id FROM administrador WHERE id=%s', (self.admin,)))
        execute('DELETE FROM administrador WHERE id=%s', (novo['id'],))

    def test_admin_reset_de_senha_revoga_sessao_antiga(self):
        self.logar_admin()
        with patch('builtins.input', side_effect=['Responsável QA', self.admin_email]), \
                patch.object(criar_admin, 'getpass', side_effect=['senha-segura-qa-123']*2), redirect_stdout(io.StringIO()):
            criar_admin.criar_admin()
        self.assertEqual(self.client.get('/api/admin/escolas').status_code, 401)


    def test_z_admin_exclui_escola_com_confirmacao_e_dependencias(self):
        criada = CadastroCoordenacaoService().execute(
            'Escola para excluir', uuid.uuid4().hex + '@qa.invalid', 'senha-qa-123')
        escola_id = criada['usuario']['id']
        email = criada['usuario']['email']
        professor_id = insert(
            'INSERT INTO professor(coordenacao_id,nome,email,senha_hash) VALUES (%s,%s,%s,%s)',
            (escola_id, 'Professor excluido', uuid.uuid4().hex + '@qa.invalid',
             generate_password_hash('senha-qa-123')))
        insert("INSERT INTO ano_letivo(coordenacao_id,ano,status) VALUES (%s,2026,'atual')", (escola_id,))
        turma_id = insert("INSERT INTO turma(coordenacao_id,nome,ano_letivo) VALUES (%s,'Turma excluida',2026)", (escola_id,))
        aluno_id = insert("INSERT INTO aluno(turma_id,nome) VALUES (%s,'Aluno excluido')", (turma_id,))
        etapa_id = insert("INSERT INTO etapa(coordenacao_id,nome,ordem,ano_letivo) VALUES (%s,'Etapa excluida',1,2026)", (escola_id,))
        criterio_id = insert("INSERT INTO criterio(coordenacao_id,etapa_id,nome,peso) VALUES (%s,%s,'Criterio excluido',100)", (escola_id, etapa_id))
        atividade_id = insert("INSERT INTO atividade(coordenacao_id,turma_id,professor_id,etapa_id,criterio_id,titulo) VALUES (%s,%s,%s,%s,%s,'Atividade excluida')", (escola_id, turma_id, professor_id, etapa_id, criterio_id))
        insert('INSERT INTO nota(atividade_id,aluno_id,valor) VALUES (%s,%s,8)', (atividade_id, aluno_id))

        csrf = self.logar_admin()
        caminho = f'/api/admin/escolas/{escola_id}'
        recusada = self.client.delete(caminho, json={'email_confirmacao': 'errado@qa.invalid'},
                                      headers={'X-CSRF-Token': csrf})
        self.assertEqual(recusada.status_code, 400)
        self.assertIsNotNone(query_one('SELECT id FROM coordenacao WHERE id=%s', (escola_id,)))

        removida = self.client.delete(caminho, json={'email_confirmacao': email},
                                      headers={'X-CSRF-Token': csrf})
        self.assertEqual(removida.status_code, 200)
        for tabela, coluna, valor in (
                ('coordenacao', 'id', escola_id), ('acesso_escola', 'coordenacao_id', escola_id),
                ('professor', 'coordenacao_id', escola_id), ('turma', 'coordenacao_id', escola_id),
                ('etapa', 'coordenacao_id', escola_id), ('atividade', 'id', atividade_id),
                ('aluno', 'id', aluno_id), ('nota', 'atividade_id', atividade_id)):
            self.assertIsNone(query_one(
                'SELECT 1 FROM %s WHERE %s=%%s' % (tabela, coluna), (valor,)), tabela)


if __name__ == '__main__':
    main(verbosity=2)

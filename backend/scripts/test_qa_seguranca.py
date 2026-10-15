"""Regressoes de seguranca e notas, sem banco nem servicos externos."""
import io
import sys
import zipfile
from datetime import date, timedelta
from pathlib import Path
from unittest import TestCase, main
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import jwt
import config
from app import create_app
from auth.jwt_utils import decodificar_token, gerar_token
from auth.downloads import gerar_permissao, ler_permissao
from services.acesso_escola import apresentar
from services.academico.calculo import calcular_desempenho_etapa
from services.planilha.leitor import ler_planilha, PlanilhaInvalida
from services.planilha.modelo import modelo_notas
from openpyxl import load_workbook
from cryptography.fernet import Fernet, InvalidToken
from scripts.backup import criptografar, descriptografar


def calcular(atividades, notas, criterios=None):
    etapa = {'id': 1, 'nome': 'Etapa', 'coordenacao_id': 1, 'nota_minima': 6, 'nota_maxima': 10}
    criterios = criterios or [{'id': 1, 'nome': 'Avaliações', 'peso': 100}]
    dados = {'criterios': {1: criterios}, 'atividades': {(1, c['id']):
             [a for a in atividades if a.get('criterio_id', 1) == c['id']] for c in criterios},
             'notas': {1: notas}}
    return calcular_desempenho_etapa(1, 1, etapa, dados)


class NotasSemInflacaoTest(TestCase):
    def test_importacao_nao_arredonda_nota_silenciosamente(self):
        from services.planilha.validacao import validar_linha_nota
        self.assertIsNotNone(validar_linha_nota({'nota': '1,999'}, 2)[1])
        self.assertIsNotNone(validar_linha_nota({'nota': '2'}, None)[1])
        self.assertEqual(validar_linha_nota({'nota': '1,99'}, 2)[0]['valor'], 1.99)
    def test_dois_de_dois_nao_vira_dez(self):
        resultado = calcular([{'id': 1, 'nota_maxima': 2}], {1: 2})
        self.assertEqual(resultado['nota_parcial'], 2)
        self.assertIsNone(resultado['nota_calculada'])
        self.assertFalse(resultado['completo'])
        self.assertIn('Planejamento incompleto', resultado['mensagem'])

    def test_cadastrar_oito_pontos_pendentes_nao_altera_os_dois_obtidos(self):
        r = calcular([{'id': 1, 'nota_maxima': 2}, {'id': 2, 'nota_maxima': 8}], {1: 2})
        self.assertEqual(r['nota_parcial'], 2)
        self.assertEqual(r['atividades_sem_nota'], 1)
        self.assertIsNone(r['nota_calculada'])

    def test_dois_mais_quatro_resultam_seis(self):
        r = calcular([{'id': 1, 'nota_maxima': 2}, {'id': 2, 'nota_maxima': 8}], {1: 2, 2: 4})
        self.assertEqual(r['nota_calculada'], 6)
        self.assertEqual(r['situacao'], 'adequado')

    def test_zero_nao_e_ausencia(self):
        r = calcular([{'id': 1, 'nota_maxima': 10}], {1: 0})
        self.assertEqual(r['nota_calculada'], 0)
        self.assertTrue(r['completo'])
        self.assertIsNone(calcular([{'id': 1, 'nota_maxima': 10}], {})['nota_parcial'])

    def test_pesos_preservados_sem_aumentar_atividade_pequena(self):
        r = calcular([{'id': 1, 'criterio_id': 1, 'nota_maxima': 2}], {1: 2},
                     [{'id': 1, 'nome': 'Provas', 'peso': 70}, {'id': 2, 'nome': 'Trabalhos', 'peso': 30}])
        self.assertEqual(r['nota_parcial'], 2)

    def test_bases_maiores_preservam_ponderacao_sem_exceder_etapa(self):
        for maximo in (10, 20, 100):
            r = calcular([{'id': 1, 'nota_maxima': maximo}], {1: maximo / 2})
            self.assertEqual(r['nota_calculada'], 5)


class AcessoTest(TestCase):
    def test_prazo_inclusivo_e_expiracao(self):
        hoje = date(2026, 10, 15)
        for situacao in ('teste', 'paga', 'cortesia'):
            self.assertTrue(apresentar({'situacao': situacao, 'valido_ate': hoje}, hoje)['liberado'])
            self.assertFalse(apresentar({'situacao': situacao, 'valido_ate': hoje-timedelta(days=1)}, hoje)['liberado'])

    def test_so_cortesia_pode_nao_ter_prazo(self):
        for situacao in ('teste', 'paga', 'cortesia', 'suspensa', 'pendente'):
            self.assertEqual(apresentar({'situacao': situacao, 'valido_ate': None})['liberado'], situacao == 'cortesia')

    def test_ausente_pendente_e_suspensa_bloqueiam(self):
        self.assertFalse(apresentar(None)['liberado'])
        for situacao in ('pendente', 'suspensa'):
            self.assertFalse(apresentar({'situacao': situacao, 'valido_ate': date(2099, 1, 1)})['liberado'])


class CredenciaisTest(TestCase):
    def test_cadastro_recusa_senha_curta_e_email_malformado_antes_do_banco(self):
        from services.auth.cadastro_coordenacao import CadastroCoordenacaoService
        with patch('services.auth.cadastro_coordenacao.Coordenacao.find_by_email') as consulta:
            for email, senha in (('ana@escola.test', '1234567'), ('email inválido', 'senha-segura')):
                with self.assertRaises(ValueError):
                    CadastroCoordenacaoService().execute('Escola', email, senha)
            consulta.assert_not_called()

    def test_login_sem_conta_tambem_verifica_hash(self):
        from auth.passwords import conferir_senha
        with patch('auth.passwords.check_password_hash', return_value=False) as verificar:
            self.assertFalse(conferir_senha(None, 'senha-digitada'))
            verificar.assert_called_once()

    def test_producao_recusa_configuracao_insegura(self):
        import os
        with patch.object(config, 'PRODUCAO', True), patch.object(config, 'DEBUG', True), \
                patch.dict(os.environ, {'SECRET_KEY': '', 'BACKUP_KEY': '', 'TRUSTED_HOSTS': ''}):
            with self.assertRaises(RuntimeError):
                config.validar_producao()

    def test_host_invalido_nao_vira_erro_interno(self):
        import os
        with patch.object(config, 'PRODUCAO', True), patch.object(config, 'validar_producao'), \
                patch.dict(os.environ, {'TRUSTED_HOSTS': 'mentorly.test'}):
            app = create_app()
            self.assertEqual(app.test_client().get('/api/acesso', headers={'Host': 'invasor.invalid'}).status_code, 400)

    def test_arquivos_do_backend_nao_sao_servidos(self):
        raiz = Path(__file__).resolve().parents[2]
        pasta = str(raiz/'frontend/app_mentorly/web')
        with patch.object(config, 'WEB_BUILD_DIR', pasta):
            client = create_app().test_client()
            self.assertEqual(client.get('/').status_code, 200)
            for caminho in ('/backend/.env', '/../backend/.env', '/CON', '/admin/arquivo-inexistente'):
                self.assertEqual(client.get(caminho).status_code, 404)

    def test_jwt_falso_e_algoritmo_nao_autorizado(self):
        valido = gerar_token(1, 'coordenacao', 1)
        self.assertIsNotNone(decodificar_token(valido))
        self.assertIsNone(decodificar_token(valido + 'alterado'))
        self.assertIsNone(decodificar_token(jwt.encode({'uid': 1}, '', algorithm='none')))

    def test_jwt_sem_expiracao_papel_estranho_e_escola_incoerente(self):
        from datetime import datetime, timezone
        base = jwt.decode(gerar_token(1, 'coordenacao', 1), config.SECRET_KEY, algorithms=['HS256'])
        for campo, valor in [('tipo', 'administrador'), ('uid', True), ('coordenacao_id', 2), ('exp', 0)]:
            self.assertIsNone(decodificar_token(jwt.encode({**base, campo: valor}, config.SECRET_KEY, algorithm='HS256')))
        del base['exp']
        self.assertIsNone(decodificar_token(jwt.encode(base, config.SECRET_KEY, algorithm='HS256')))

    def test_download_nao_e_sessao_e_so_abre_um_caminho(self):
        usuario = {'id': 1, 'coordenacao_id': 1, 'tipo': 'coordenacao'}
        ticket = gerar_permissao(usuario, '/api/arquivo')
        self.assertIsNotNone(ler_permissao(ticket, '/api/arquivo'))
        self.assertIsNone(ler_permissao(ticket, '/api/outro'))
        self.assertIsNone(decodificar_token(ticket))
        self.assertIsNone(ler_permissao(gerar_token(1, 'coordenacao', 1), '/api/arquivo'))
        with patch('itsdangerous.timed.time.time', return_value=9999999999):
            self.assertIsNone(ler_permissao(ticket, '/api/arquivo'))

    def test_admin_exige_csrf_antes_de_consultar_banco(self):
        client = create_app().test_client()
        with patch('routes.admin_routes.query_one') as banco:
            self.assertEqual(client.post('/api/admin/login', json={'email': 'a@b.com', 'senha': 'x'}).status_code, 400)
            banco.assert_not_called()

    def test_admin_sem_sessao_nao_recebe_dados(self):
        r = create_app().test_client().get('/api/admin/escolas')
        self.assertEqual(r.status_code, 401)

    def test_cors_e_cabecalhos(self):
        client = create_app().test_client()
        r = client.get('/api/acesso', headers={'Origin': 'https://invasor.invalid'})
        self.assertNotIn('Access-Control-Allow-Origin', r.headers)
        self.assertEqual(r.headers['Cache-Control'], 'no-store')
        self.assertEqual(r.headers['X-Content-Type-Options'], 'nosniff')
        r = client.get('/api/admin/sessao')
        self.assertIn('HttpOnly', r.headers['Set-Cookie'])
        self.assertIn('SameSite=Strict', r.headers['Set-Cookie'])
        self.assertIn("frame-ancestors 'none'", r.headers['Content-Security-Policy'])


class PlanilhaTest(TestCase):
    def test_xml_com_entidades_e_recusado_inclusive_utf16(self):
        for codificacao in ('utf-8', 'utf-16', 'utf-32'):
            arquivo = io.BytesIO()
            with zipfile.ZipFile(arquivo, 'w') as z:
                z.writestr('xl/workbook.xml', '<!DOCTYPE x [<!ENTITY segredo "texto">]><x>&segredo;</x>'.encode(codificacao))
            with self.assertRaises(PlanilhaInvalida):
                ler_planilha('dados.xlsx', arquivo.getvalue())

    def test_xlsx_comprimido_acima_do_limite_e_recusado(self):
        arquivo = io.BytesIO()
        with zipfile.ZipFile(arquivo, 'w', compression=zipfile.ZIP_DEFLATED) as z:
            z.writestr('xl/worksheets/sheet1.xml', b' ' * (41 * 1024 * 1024))
        with self.assertRaises(PlanilhaInvalida):
            ler_planilha('dados.xlsx', arquivo.getvalue())

    def test_colunas_duplicadas_e_muitas_linhas(self):
        for dados in (b'nome;nome\nAna;Bia', b'nome\n' + b'Ana\n' * 5001):
            with self.assertRaises(PlanilhaInvalida):
                ler_planilha('dados.csv', dados)

    def test_formula_no_nome_e_matricula_e_exportada_como_texto(self):
        wb = load_workbook(modelo_notas([{'nome': '=HYPERLINK("https://invasor.invalid")', 'matricula': '=1+1'}]), data_only=False)
        self.assertEqual(wb.active['A2'].data_type, 's')
        self.assertEqual(wb.active['B2'].data_type, 's')
        wb.close()

    def test_backup_exige_chave_correta_e_detecta_adulteracao(self):
        chave = Fernet.generate_key()
        dados = criptografar(b'CREATE TABLE teste(id INT);', chave)
        self.assertNotIn(b'CREATE TABLE', dados)
        self.assertEqual(descriptografar(dados, chave), b'CREATE TABLE teste(id INT);')
        with self.assertRaises(InvalidToken):
            descriptografar(dados, Fernet.generate_key())
        with self.assertRaises(InvalidToken):
            descriptografar(dados[:-5] + b'xxxxx', chave)


if __name__ == '__main__':
    main()

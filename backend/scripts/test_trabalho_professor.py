"""Regras novas sem banco: autorização, situação sem nota e exportação segura."""
import sys
from pathlib import Path
from datetime import date, datetime
from contextlib import ExitStack
from unittest import TestCase
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app import create_app
from auth.jwt_utils import gerar_token
from erros import RecursoNaoEncontrado
from services.professor.notas import LancarNotasService
from services.professor.trabalho import criar_acompanhamento, concluir_acompanhamento, painel_trabalho
from services.professor.estatisticas_turma import resumir


class SituacaoTest(TestCase):
    def setUp(self):
        self.stack = ExitStack()
        self.addCleanup(self.stack.close)
        self.stack.enter_context(patch('services.professor.notas._atividade_do_professor', return_value={'id': 8, 'turma_id': 7, 'coordenacao_id': 1, 'nota_maxima': 10}))
        self.stack.enter_context(patch('services.professor.notas.exigir_ano_aberto_da_atividade'))
        self.stack.enter_context(patch('services.professor.notas.Aluno.find_all_by_turma', return_value=[{'id': 2}, {'id': 3}]))
        self.gravar = self.stack.enter_context(patch('services.professor.notas.Nota.lancar_em_lote'))

    def test_ausencia_sem_nota_nao_cria_zero(self):
        r = LancarNotasService().execute(8, 1, {'notas': [{'aluno_id': 2, 'valor': None, 'situacao': 'Ausente'}]})
        self.assertEqual(r['lancadas'], 0)
        self.gravar.assert_called_once_with(8, [], {2: 'Ausente'})

    def test_zero_explicitamente_digitado_e_nota(self):
        r = LancarNotasService().execute(8, 1, {'notas': [{'aluno_id': 2, 'valor': 0, 'situacao': 'Não entregou'}]})
        self.assertEqual(r['lancadas'], 1)
        self.assertEqual(self.gravar.call_args.args[1][0]['valor'], 0)

    def test_sem_nota_de_aluno_alheio_tambem_e_bloqueado(self):
        with self.assertRaises(RecursoNaoEncontrado):
            LancarNotasService().execute(8, 1, {'notas': [{'aluno_id': 99, 'situacao': 'Ausente'}]})
        self.gravar.assert_not_called()

    def test_lote_invalido_nao_salva_situacao_parcial(self):
        with self.assertRaises(ValueError):
            LancarNotasService().execute(8, 1, {'notas': [{'aluno_id': 2, 'situacao': 'Ausente'}, {'aluno_id': 3, 'valor': 11}]})
        self.gravar.assert_not_called()

    def test_situacao_invalida_e_duplicatas_nao_gravam(self):
        for itens in [[{'aluno_id': 2, 'situacao': 'Inventado'}], [{'aluno_id': 2, 'valor': 1}, {'aluno_id': 2, 'valor': 2}]]:
            with self.assertRaises(ValueError): LancarNotasService().execute(8, 1, {'notas': itens})
        self.gravar.assert_not_called()

    def test_estatisticas_preservam_ausencia_sem_inventar_media(self):
        d = resumir({'id': 7, 'nome': '7A'}, [], None,
                    [{'id': 8, 'titulo': 'Prova', 'etapa_id': None, 'nota_maxima': 10}],
                    [{'id': 2, 'nome': 'Ana'}],
                    [{'aluno_id': 2, 'atividade_id': 8, 'valor': None, 'situacao': 'Ausente'}])
        self.assertIsNone(d['alunos'][0]['media'])
        self.assertEqual(d['alunos'][0]['atividades'][0]['status'], 'Ausente')
        self.assertEqual(d['alunos'][0]['sem_nota'], 1)


class AcompanhamentoTest(TestCase):
    def test_vinculo_alheio_bloqueia_criacao(self):
        with patch('services.professor.trabalho.Turma.find_by_id', return_value=None), patch('services.professor.trabalho.insert') as gravar:
            with self.assertRaises(RecursoNaoEncontrado): criar_acompanhamento(1, 1, 7, 2, {})
            gravar.assert_not_called()

    def test_validacao_nao_aceita_texto_vazio_data_invalida_ou_aluno_alheio(self):
        with patch('services.professor.trabalho.turma_autorizada', return_value={'ano_letivo': 2026}), patch('services.professor.trabalho.exigir_ano_nao_encerrado'), patch('services.professor.trabalho.Aluno.find_by_id', return_value={'turma_id': 7}), patch('services.professor.trabalho.insert') as gravar:
            for payload in [{'descricao': ' ', 'retorno_em': '2026-10-20'}, {'descricao': 'Revisar leitura', 'retorno_em': '2026-99-01'}]:
                with self.assertRaises(ValueError): criar_acompanhamento(1, 1, 7, 2, payload)
            gravar.assert_not_called()
        with patch('services.professor.trabalho.turma_autorizada', return_value={'ano_letivo': 2026}), patch('services.professor.trabalho.exigir_ano_nao_encerrado'), patch('services.professor.trabalho.Aluno.find_by_id', return_value={'turma_id': 99}):
            with self.assertRaises(RecursoNaoEncontrado): criar_acompanhamento(1, 1, 7, 2, {})

    def test_criacao_e_retorno(self):
        with patch('services.professor.trabalho.turma_autorizada', return_value={'ano_letivo': 2026}), patch('services.professor.trabalho.exigir_ano_nao_encerrado'), patch('services.professor.trabalho.Aluno.find_by_id', return_value={'turma_id': 7}), patch('services.professor.trabalho.insert', return_value=12) as gravar:
            self.assertEqual(criar_acompanhamento(1, 1, 7, 2, {'descricao': ' Revisar leitura ', 'retorno_em': '2026-10-20'}), {'id': 12})
            self.assertEqual(gravar.call_args.args[1], (1, 7, 2, 'Revisar leitura', date(2026, 10, 20)))

    def test_concluir_registro_alheio_e_bloqueado(self):
        with patch('services.professor.trabalho.listar_acompanhamentos', return_value=[]), patch('services.professor.trabalho.execute') as gravar:
            with self.assertRaises(RecursoNaoEncontrado): concluir_acompanhamento(1, 1, 99, {'concluido': True})
            gravar.assert_not_called()

    def test_sem_ano_atual_nao_busca_tarefas_de_outros_anos(self):
        with patch('services.professor.trabalho.AnoLetivo.atual', return_value=None), patch('services.professor.trabalho.query_all') as consulta:
            self.assertEqual(painel_trabalho(1, 1)['pendencias'], [])
            consulta.assert_not_called()


class RotasTrabalhoTest(TestCase):
    def setUp(self):
        self.client = create_app().test_client()
        self.token = gerar_token(1, 'professor', 1)
        self.auth = {'Authorization': 'Bearer '+self.token}
        self.habilitado = patch('auth.decorators._professor_habilitado', return_value=True)
        self.habilitado.start()
        self.addCleanup(self.habilitado.stop)
        acesso = patch('auth.decorators._conferir_acesso', return_value=None)
        acesso.start()
        self.addCleanup(acesso.stop)

    def test_sem_login_e_coordenacao_nao_acessam(self):
        for url in ['/trabalho', '/turmas/7/grade', '/turmas/7/resumo-reuniao', '/turmas/7/alunos/2/acompanhamentos']:
            self.assertEqual(self.client.get('/api/professor'+url).status_code, 401)
            token = gerar_token(1, 'coordenacao', 1)
            self.assertEqual(self.client.get('/api/professor'+url, headers={'Authorization': 'Bearer '+token}).status_code, 403)

    def test_token_em_url_apenas_no_download(self):
        self.assertEqual(self.client.get('/api/professor/trabalho?token='+self.token).status_code, 401)
        self.assertEqual(self.client.get('/api/professor/turmas/7/grade?token='+self.token).status_code, 401)

    def test_relatorio_escapa_conteudo_e_nao_e_cacheado(self):
        dados = {'turma': {'nome': '<script>turma</script>'}, 'etapas': [], 'alunos': [{'nome': '<img onerror=alert(1)>', 'risco': 'Sem dados', 'pontos_obtidos': None, 'pontos_avaliados': None, 'sem_nota': 1}]}
        with patch('routes.trabalho_routes.grade_dados', return_value=dados), patch('routes.trabalho_routes.listar_acompanhamentos', return_value=[]):
            from auth.downloads import gerar_permissao
            caminho = '/api/professor/turmas/7/resumo-reuniao'
            ticket = gerar_permissao({'id': 1, 'tipo': 'professor', 'coordenacao_id': 1}, caminho)
            resposta = self.client.get(caminho+'?token='+ticket)
            self.assertEqual(resposta.status_code, 200)
            self.assertNotIn('<script>turma', resposta.text)
            self.assertIn('&lt;img', resposta.text)
            self.assertEqual(resposta.headers['Cache-Control'], 'no-store')

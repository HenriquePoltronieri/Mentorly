"""Falhas de provedor continuam oferecendo analise local sem fingir geracao por IA."""
import sys
import unittest
from contextlib import ExitStack
from pathlib import Path
from unittest.mock import MagicMock
from decimal import Decimal
import json

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from scripts.test_fluxos_professor import fixture
from scripts.test_ia_insights_privacidade import ALUNOS, cenario
from services.ia.client import AIConfigurationError, AIProviderError, AIResponseError
from services.ia.chat_professor import ChatProfessorService
from services.rate_limit import limiter
from erros import AcessoNegado


class ContingenciaTest(unittest.TestCase):
    def setUp(self):
        limiter.reset()

    def test_decimal_do_mysql_e_enviado_como_numero_json(self):
        from services.ia.client import AIClient
        from scripts.test_ia import RespostaFalsa, ENVELOPE_VALIDO
        pedidos = []
        def abrir(req, **kwargs):
            pedidos.append(json.loads(req.data))
            return RespostaFalsa(json.dumps(ENVELOPE_VALIDO).encode())
        AIClient(api_key='teste', opener=abrir).gerar({'minimo': Decimal('18.50'), 'maximo': Decimal('30.00')})
        enviado = pedidos[0]['messages'][1]['content']
        self.assertIn('"minimo":18.5', enviado)
        self.assertIn('"maximo":30.0', enviado)

    def test_troca_aluno_numerico_e_nao_reutiliza_foco_antigo(self):
        stats, client = MagicMock(), MagicMock()
        turma = fixture()
        for a in turma['alunos']:
            a['nome'] = 'Aluno Teste Um' if a['id'] == 3 else 'Aluno Teste Dois'
        stats.execute.return_value = turma
        client.gerar.side_effect = AIProviderError('falha')
        service = ChatProfessorService(client, stats)
        r = service.execute(1, 1, {'turma_id': 7, 'aluno_id': 3,
            'mensagem': 'E para o aluno teste 2?', 'foco_anterior': {'turma_id': 7, 'aluno_id': 3}})
        self.assertIn('Aluno Teste Dois', r['resposta'])
        self.assertNotIn('Aluno Teste Um', r['resposta'])
        self.assertEqual(r['atalhos'][0]['aluno_id'], 2)

    def test_outro_aluno_pede_nome_sem_repetir_o_anterior(self):
        stats, client = MagicMock(), MagicMock()
        stats.execute.return_value = fixture()
        r = ChatProfessorService(client, stats).execute(1, 1, {
            'turma_id': 7, 'mensagem': 'desempenho de outro aluno',
            'foco_anterior': {'turma_id': 7, 'aluno_id': 3}})
        self.assertTrue(r['limpar_foco'])
        self.assertIn('Ana teste', r['resposta'])
        self.assertNotIn('Bia teste', r['resposta'])
        client.gerar.assert_not_called()

    def test_insights_identificam_modo_local_em_falhas_esperadas(self):
        for erro in (AIConfigurationError('segredo'), AIProviderError('segredo'),
                     AIResponseError('segredo')):
            client = MagicMock()
            client.gerar.side_effect = erro
            service, patches = cenario(ALUNOS, client)
            with ExitStack() as stack:
                for p in patches:
                    stack.enter_context(p)
                resposta = service.execute(10, 20, 2)
            self.assertFalse(resposta['geradoPorIA'])
            self.assertEqual(resposta['modo'], 'local')
            self.assertIn('localmente', resposta['aviso'])
            self.assertNotIn('segredo', str(resposta))
            self.assertTrue(resposta['insights']['pontosAtencao'])

    def test_chat_local_diferencia_risco_medidas_e_dificuldade(self):
        stats, client = MagicMock(), MagicMock()
        stats.execute.return_value = fixture()
        client.gerar.side_effect = AIProviderError('segredo', status=429)
        service = ChatProfessorService(client, stats)
        risco = service.execute(1, 1, {'turma_id': 7, 'mensagem': 'Qual aluno precisa de atenção no final da etapa?'})
        medidas = service.execute(1, 1, {'turma_id': 7, 'mensagem': 'Quais medidas posso aplicar?',
                                      'foco_anterior': {'turma_id': 7, 'aluno_id': 3}})
        dificuldade = service.execute(1, 1, {'turma_id': 7, 'mensagem': 'Onde a turma tem mais dificuldade?'})
        self.assertIn('Bia teste', risco['resposta'])
        self.assertIn('Medidas sugeridas', medidas['resposta'])
        self.assertIn('Bia teste', medidas['resposta'])
        self.assertNotEqual(risco['resposta'], medidas['resposta'])
        self.assertIn('menor média em B', dificuldade['resposta'])
        self.assertEqual(risco['codigo'], 'ia_cota')
        self.assertFalse(risco['geradoPorIA'])

    def test_contingencia_nao_contorna_acesso_ou_erros_de_programacao(self):
        stats, client = MagicMock(), MagicMock()
        service = ChatProfessorService(client, stats)
        stats.execute.side_effect = AcessoNegado('sem vinculo')
        with self.assertRaises(AcessoNegado):
            service.execute(1, 1, {'turma_id': 7, 'mensagem': 'Resumo'})
        client.gerar.assert_not_called()
        stats.execute.side_effect = None
        stats.execute.return_value = fixture()
        client.gerar.side_effect = TypeError('bug')
        with self.assertRaises(TypeError):
            service.execute(1, 1, {'turma_id': 7, 'mensagem': 'Resumo'})


if __name__ == '__main__':
    unittest.main()

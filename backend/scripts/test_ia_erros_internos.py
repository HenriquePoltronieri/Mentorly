"""Regressao: erro INTERNO nao pode virar erro 400 de entrada nos controllers de IA.

O 9D descobriu que `except (ValueError, TypeError) -> 400` escondeu um bug de
serializacao (Decimal) como se fosse culpa do usuario. Aqui se prova, para os
quatro endpoints de IA, que:

- um TypeError levantado pelo service (bug interno) NAO e convertido em 400:
  ele sobe e, numa rota real, vira 500;
- os erros realmente esperados continuam com o mesmo codigo (ValueError -> 400
  onde ja era, RecursoNaoEncontrado -> 404, DadosInsuficientesError -> 422, AIError -> 503).

Sem banco e sem rede: os services sao substituidos por dubles.
"""

import inspect
import os
import sys
import unittest
from unittest.mock import MagicMock, patch

from flask import Flask

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from erros import RecursoNaoEncontrado

from controllers import professor_controller as modulo
from controllers.professor_controller import ProfessorController
from services.ia.client import AIProviderError, AIResponseError
from services.ia.gerar_insights_turma import DadosInsuficientesError
from services import rate_limit


# (metodo do controller, nome da classe de service importada no modulo, argumento da rota,
#  excecoes esperadas por codigo: o 9A nunca mapeou ValueError)
ENDPOINTS = (
    ("insights_turma", "GerarInsightsTurmaService", False),
    ("gerar_atividade", "GerarAtividadeIaService", True),
    ("corrigir_resposta", "CorrigirRespostaIaService", True),
    ("feedback_aluno", "GerarFeedbackIaService", True),
)


def _app(controller, metodo):
    """App minimo, com PROPAGATE_EXCEPTIONS desligado: como em producao, erro nao tratado vira 500."""
    app = Flask(__name__)
    app.config.update(TESTING=False, PROPAGATE_EXCEPTIONS=False)
    app.logger.disabled = True
    app.add_url_rule(
        "/ia", "ia", lambda: getattr(controller, metodo)(1), methods=["POST"]
    )
    return app


class _Base(unittest.TestCase):
    def setUp(self):
        # O controller agora limita a IA por Professor (M-08): estes testes
        # chamam as mesmas rotas dezenas de vezes com o mesmo usuario falso.
        rate_limit.limiter.reset()

    def _controller_com(self, servico, excecao):
        """Controller cujo service levanta `excecao` ao executar."""
        instancia = MagicMock()
        instancia.execute.side_effect = excecao
        classe = MagicMock(return_value=instancia)
        patches = [
            patch.object(modulo, servico, classe),
            patch.object(modulo, "usuario_atual_id", return_value=1),
            patch.object(modulo, "coordenacao_atual", return_value=2),
        ]
        for p in patches:
            p.start()
            self.addCleanup(p.stop)
        return ProfessorController()


class ErroInternoNaoViraErroDeEntradaTest(_Base):
    def test_typeerror_interno_sobe_em_vez_de_virar_400(self):
        for metodo, servico, _ in ENDPOINTS:
            with self.subTest(endpoint=metodo):
                controller = self._controller_com(servico, TypeError("bug interno: Decimal nao serializa"))
                with Flask(__name__).test_request_context(json={}):
                    with self.assertRaises(TypeError):
                        getattr(controller, metodo)(1)

    def test_typeerror_interno_vira_500_na_rota_nunca_400(self):
        for metodo, servico, _ in ENDPOINTS:
            with self.subTest(endpoint=metodo):
                controller = self._controller_com(servico, TypeError("bug interno"))
                resposta = _app(controller, metodo).test_client().post("/ia", json={})
                self.assertEqual(resposta.status_code, 500)
                self.assertNotEqual(resposta.status_code, 400)

    def test_erro_interno_comum_tambem_vira_500(self):
        for metodo, servico, _ in ENDPOINTS:
            for erro in (AttributeError("x"), ZeroDivisionError(), RuntimeError("interno")):
                with self.subTest(endpoint=metodo, erro=type(erro).__name__):
                    controller = self._controller_com(servico, erro)
                    resposta = _app(controller, metodo).test_client().post("/ia", json={})
                    self.assertEqual(resposta.status_code, 500)

    def test_keyerror_e_indexerror_internos_viram_500_e_nunca_404(self):
        """M-10: KeyError/IndexError sao bugs internos; antes (LookupError) viravam 404."""
        for metodo, servico, _ in ENDPOINTS:
            for erro in (KeyError("campo"), IndexError("indice")):
                with self.subTest(endpoint=metodo, erro=type(erro).__name__):
                    controller = self._controller_com(servico, erro)
                    resposta = _app(controller, metodo).test_client().post("/ia", json={})
                    self.assertEqual(resposta.status_code, 500)

    def test_nenhum_controller_de_ia_trata_typeerror(self):
        """Trava contra a volta do padrao: o codigo-fonte dos quatro metodos nao menciona TypeError."""
        for metodo, _, _ in ENDPOINTS:
            with self.subTest(endpoint=metodo):
                fonte = inspect.getsource(getattr(ProfessorController, metodo))
                self.assertNotIn("TypeError", fonte)


class ErrosEsperadosContinuamIguaisTest(_Base):
    def _post(self, metodo, servico, erro):
        controller = self._controller_com(servico, erro)
        resposta = _app(controller, metodo).test_client().post("/ia", json={})
        return resposta.status_code, resposta.get_json()

    def test_valueerror_de_entrada_continua_400_onde_ja_era(self):
        for metodo, servico, mapeia_valueerror in ENDPOINTS:
            if not mapeia_valueerror:
                continue
            with self.subTest(endpoint=metodo):
                codigo, corpo = self._post(metodo, servico, ValueError("Informe o tema da atividade"))
                self.assertEqual(codigo, 400)
                self.assertEqual(corpo["error"], "Informe o tema da atividade")

    def test_recurso_nao_encontrado_continua_404(self):
        for metodo, servico, _ in ENDPOINTS:
            with self.subTest(endpoint=metodo):
                codigo, corpo = self._post(metodo, servico, RecursoNaoEncontrado("Turma nao encontrada"))
                self.assertEqual(codigo, 404)
                self.assertEqual(corpo["error"], "Turma nao encontrada")

    def test_dados_insuficientes_continua_422_onde_ja_era(self):
        for metodo, servico in (("insights_turma", "GerarInsightsTurmaService"),
                                ("feedback_aluno", "GerarFeedbackIaService")):
            with self.subTest(endpoint=metodo):
                codigo, _ = self._post(metodo, servico, DadosInsuficientesError("sem dados"))
                self.assertEqual(codigo, 422)

    def test_falha_da_ia_continua_503_amigavel(self):
        for metodo, servico, _ in ENDPOINTS:
            for erro in (AIProviderError("detalhe tecnico secreto"), AIResponseError("detalhe tecnico secreto")):
                with self.subTest(endpoint=metodo, erro=type(erro).__name__):
                    codigo, corpo = self._post(metodo, servico, erro)
                    self.assertEqual(codigo, 503)
                    if metodo != "insights_turma":  # o 9A ja devolvia str(erro): comportamento mantido
                        self.assertNotIn("secreto", corpo["error"])

    def test_sucesso_continua_200(self):
        for metodo, servico, _ in ENDPOINTS:
            with self.subTest(endpoint=metodo):
                controller = self._controller_com(servico, None)
                modulo_servico = getattr(modulo, servico)
                modulo_servico.return_value.execute.side_effect = None
                modulo_servico.return_value.execute.return_value = {"ok": True}
                resposta = _app(controller, metodo).test_client().post("/ia", json={})
                self.assertEqual((resposta.status_code, resposta.get_json()), (200, {"ok": True}))


if __name__ == "__main__":
    unittest.main(verbosity=2)

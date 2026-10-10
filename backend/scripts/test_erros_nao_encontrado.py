"""M-10: "nao encontrado" (404) separado de bug interno (500), sem banco.

Antes, os controllers faziam `except LookupError -> 404`. KeyError e IndexError
herdam de LookupError, entao um bug interno (chave ou indice errado) virava um
404 com a chave no texto. Agora so RecursoNaoEncontrado vira 404; o resto cai no
handler 500 generico (M-01), sem detalhe para o cliente.

Uso: python scripts/test_erros_nao_encontrado.py
"""

import os
import re
import sys
import unittest
from unittest.mock import MagicMock, patch

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app import create_app
from auth.jwt_utils import TIPO_COORDENACAO, TIPO_PROFESSOR, gerar_token
from controllers import (
    activity_controller,
    class_controller,
    config_controller,
    coordenacao_controller,
    professor_controller,
)
from erros import RecursoNaoEncontrado
from services import rate_limit

BACKEND = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GENERICO = {"error": "Erro interno do servidor."}

# (rotulo, metodo, url, papel, modulo do controller, nome patchado, corpo)
# O nome patchado e uma classe de service (instanciada no controller) ou, no
# caso de excluir_turma, uma funcao.
CASOS = (
    ("turma (coordenacao)", "get", "/api/coordenacao/turmas/1/alunos", "coord",
     coordenacao_controller, "ListarAlunosService", None),
    ("etapa (coordenacao)", "get", "/api/config/etapas/1", "coord",
     config_controller, "BuscarEtapaService", None),
    ("turma (excluir)", "delete", "/api/classes/1", "coord",
     class_controller, "excluir_turma", None),
    ("atividade (excluir)", "delete", "/api/activities/1", "prof",
     activity_controller, "DeleteActivityService", None),
    ("notas da atividade", "get", "/api/atividades/1/notas", "prof",
     professor_controller, "ListarNotasService", None),
    ("9A insights", "post", "/api/professor/turmas/1/insights", "prof",
     professor_controller, "GerarInsightsTurmaService", {}),
    ("9B gerar atividade", "post", "/api/professor/turmas/1/atividades/gerar", "prof",
     professor_controller, "GerarAtividadeIaService", {"tema": "x"}),
    ("9C correcao", "post", "/api/professor/atividades/1/correcao-assistida", "prof",
     professor_controller, "CorrigirRespostaIaService", {}),
    ("9D feedback", "post", "/api/professor/alunos/1/feedback-ia", "prof",
     professor_controller, "GerarFeedbackIaService", {}),
)


def _app():
    """App real, configurado como em producao: erro nao tratado vira 500, nao excecao."""
    app = create_app()
    app.config.update(TESTING=False, PROPAGATE_EXCEPTIONS=False)
    app.logger.disabled = True
    return app


def _chamar(app, caso, erro):
    _, metodo, url, papel, modulo, alvo, corpo = caso
    token = (gerar_token(1, TIPO_PROFESSOR, 1) if papel == "prof"
             else gerar_token(1, TIPO_COORDENACAO, 1))
    if alvo == "excluir_turma":
        substituto = MagicMock(side_effect=erro)
    else:
        instancia = MagicMock()
        instancia.execute.side_effect = erro
        substituto = MagicMock(return_value=instancia)
    rate_limit.limiter.reset()
    with patch.object(modulo, alvo, substituto), \
            patch("auth.decorators._professor_habilitado", return_value=True):
        kwargs = {"headers": {"Authorization": "Bearer %s" % token}}
        if corpo is not None:
            kwargs["json"] = corpo
        return getattr(app.test_client(), metodo)(url, **kwargs)


class NaoEncontradoTest(unittest.TestCase):
    def test_a_excecao_nao_e_um_lookuperror(self):
        self.assertFalse(issubclass(RecursoNaoEncontrado, LookupError))
        self.assertFalse(issubclass(KeyError, RecursoNaoEncontrado))
        self.assertFalse(issubclass(IndexError, RecursoNaoEncontrado))

    def test_service_levanta_recurso_nao_encontrado_controller_responde_404(self):
        app = _app()
        for caso in CASOS:
            with self.subTest(caso=caso[0]):
                resposta = _chamar(app, caso, RecursoNaoEncontrado("Turma nao encontrada"))
                self.assertEqual(resposta.status_code, 404)
                self.assertEqual(resposta.get_json(), {"error": "Turma nao encontrada"})


class BugInternoTest(unittest.TestCase):
    def test_keyerror_interno_e_500_generico_e_nao_404(self):
        app = _app()
        for caso in CASOS:
            with self.subTest(caso=caso[0]):
                resposta = _chamar(app, caso, KeyError("coluna_secreta_xyz"))
                self.assertEqual(resposta.status_code, 500)
                self.assertEqual(resposta.get_json(), GENERICO)
                self.assertNotIn("coluna_secreta_xyz", resposta.get_data(as_text=True))

    def test_indexerror_interno_e_500_generico_e_nao_404(self):
        app = _app()
        for caso in CASOS:
            with self.subTest(caso=caso[0]):
                resposta = _chamar(app, caso, IndexError("indice_secreto_42"))
                self.assertEqual(resposta.status_code, 500)
                self.assertEqual(resposta.get_json(), GENERICO)
                self.assertNotIn("indice_secreto_42", resposta.get_data(as_text=True))

    def test_typeerror_interno_continua_500_generico(self):
        app = _app()
        for caso in CASOS:
            with self.subTest(caso=caso[0]):
                resposta = _chamar(app, caso, TypeError("detalhe_tipo_secreto"))
                self.assertEqual(resposta.status_code, 500)
                self.assertEqual(resposta.get_json(), GENERICO)
                self.assertNotIn("detalhe_tipo_secreto", resposta.get_data(as_text=True))

    def test_o_detalhe_fica_no_log_do_servidor(self):
        import logging

        registros = []

        class Captura(logging.Handler):
            def emit(self, registro):
                registros.append(registro)

        app = _app()
        app.logger.disabled = False
        from flask.logging import default_handler
        app.logger.removeHandler(default_handler)
        app.logger.addHandler(Captura())
        _chamar(app, CASOS[0], KeyError("coluna_secreta_xyz"))
        self.assertTrue(any(
            r.exc_info and isinstance(r.exc_info[1], KeyError) and "coluna_secreta_xyz" in str(r.exc_info[1])
            for r in registros))


class OutrosErrosPreservadosTest(unittest.TestCase):
    def test_valueerror_vira_400_e_demais_mapeamentos_seguem(self):
        from services.conflito import ConflitoDeIntegridade
        from services.ia.gerar_insights_turma import DadosInsuficientesError
        from services.ia.client import AIProviderError
        from services.rate_limit import LimiteExcedido

        app = _app()
        por_nome = {c[0]: c for c in CASOS}
        # 400
        r = _chamar(app, por_nome["atividade (excluir)"], ValueError("etapa fechada"))
        self.assertEqual((r.status_code, r.get_json()), (400, {"error": "etapa fechada"}))
        # 409
        r = _chamar(app, por_nome["turma (excluir)"], ConflitoDeIntegridade("tem dados vinculados"))
        self.assertEqual((r.status_code, r.get_json()), (409, {"error": "tem dados vinculados"}))
        # 422
        r = _chamar(app, por_nome["9A insights"], DadosInsuficientesError("sem dados"))
        self.assertEqual(r.status_code, 422)
        # 503
        r = _chamar(app, por_nome["9B gerar atividade"], AIProviderError("x"))
        self.assertEqual(r.status_code, 503)
        # 429
        r = _chamar(app, por_nome["9A insights"], LimiteExcedido("devagar", 30))
        self.assertEqual((r.status_code, r.headers["Retry-After"]), (429, "30"))

    def test_sem_token_continua_401_e_papel_errado_403(self):
        app = _app()
        self.assertEqual(app.test_client().get("/api/coordenacao/turmas/1/alunos").status_code, 401)
        token_prof = gerar_token(1, TIPO_PROFESSOR, 1)
        with patch("auth.decorators._professor_habilitado", return_value=True):
            r = app.test_client().get(
                "/api/coordenacao/turmas/1/alunos",
                headers={"Authorization": "Bearer %s" % token_prof})
        self.assertEqual(r.status_code, 403)


class TravaDeCodigoFonteTest(unittest.TestCase):
    """O backend inteiro (fora dos testes) nao usa mais LookupError como 'nao encontrado'."""

    def _fontes(self):
        for raiz, pastas, arquivos in os.walk(BACKEND):
            pastas[:] = [p for p in pastas if p not in ("scripts", "__pycache__", ".venv", "venv")]
            for nome in arquivos:
                if nome.endswith(".py"):
                    caminho = os.path.join(raiz, nome)
                    with open(caminho, encoding="utf-8") as arquivo:
                        yield os.path.relpath(caminho, BACKEND), arquivo.read()

    def test_nenhum_except_lookuperror_no_backend(self):
        padrao = re.compile(r"^\s*except\b[^\n#]*\bLookupError\b", re.MULTILINE)
        achados = [nome for nome, texto in self._fontes() if padrao.search(texto)]
        self.assertEqual(achados, [])

    def test_nenhum_raise_lookuperror_no_backend(self):
        padrao = re.compile(r"^\s*raise\s+LookupError\b", re.MULTILINE)
        achados = [nome for nome, texto in self._fontes() if padrao.search(texto)]
        self.assertEqual(achados, [])

    def test_controllers_nao_capturam_keyerror_nem_indexerror(self):
        # Converter KeyError/IndexError em 404 recriaria o problema.
        padrao = re.compile(r"^\s*except\b[^\n#]*\b(KeyError|IndexError)\b", re.MULTILINE)
        achados = [nome for nome, texto in self._fontes()
                   if nome.startswith("controllers") and padrao.search(texto)]
        self.assertEqual(achados, [])

    def test_todos_os_controllers_que_respondiam_404_usam_a_excecao_nova(self):
        for nome, texto in self._fontes():
            if nome.startswith("controllers"):
                if "RecursoNaoEncontrado" in texto:
                    self.assertIn("from erros import RecursoNaoEncontrado", texto, nome)


if __name__ == "__main__":
    unittest.main()

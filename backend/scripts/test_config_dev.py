"""Interruptores de desenvolvimento (M-06), sem banco: python scripts/test_config_dev.py

Cobre o que nao precisa de MySQL: os padroes seguros de FLASK_DEBUG e
DEV_EXPOSE_AUTH_CODES, o app.py sem debug fixo, o .env.example e a ausencia de
segredo real nos arquivos de teste. O comportamento das respostas da API
(codigo/convite com e sem SMTP) esta na secao [M-06] do smoke_api.py.
"""

import os
import re
import subprocess
import sys
import unittest
from unittest.mock import patch

BACKEND = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, BACKEND)

import config


def _ler_config(**ambiente):
    """Importa o config em um processo novo com as variaveis dadas.

    Variavel definida (mesmo vazia) vence o backend/.env, entao o resultado nao
    depende do .env da maquina que roda o teste.
    """
    env = dict(os.environ)
    env.update(ambiente)
    saida = subprocess.run(
        [sys.executable, "-c",
         "import config; print(config.DEBUG, config.DEV_EXPOSE_AUTH_CODES)"],
        cwd=BACKEND, env=env, capture_output=True, text=True, timeout=60,
    )
    assert saida.returncode == 0, saida.stderr
    debug, expor = saida.stdout.split()[-2:]
    return debug == "True", expor == "True"


class PadroesSegurosTest(unittest.TestCase):
    def test_variavel_ausente_ou_vazia_e_falsa(self):
        with patch.dict(os.environ, {}, clear=False):
            os.environ.pop("VARIAVEL_QUE_NAO_EXISTE_M06", None)
            self.assertIs(config._booleano_env("VARIAVEL_QUE_NAO_EXISTE_M06"), False)
        self.assertEqual(_ler_config(FLASK_DEBUG="", DEV_EXPOSE_AUTH_CODES=""),
                         (False, False))

    def test_so_valores_explicitos_ligam(self):
        for valor in ("true", "TRUE", "True", "1", "sim", "yes", "on", " true "):
            with patch.dict(os.environ, {"X_M06": valor}):
                self.assertIs(config._booleano_env("X_M06"), True, valor)
        for valor in ("false", "0", "", "nao", "no", "off", "talvez", "2", "tru"):
            with patch.dict(os.environ, {"X_M06": valor}):
                self.assertIs(config._booleano_env("X_M06"), False, valor)

    def test_debug_so_liga_com_a_variavel_explicita(self):
        self.assertEqual(_ler_config(FLASK_DEBUG="false", DEV_EXPOSE_AUTH_CODES="false"),
                         (False, False))
        self.assertEqual(_ler_config(FLASK_DEBUG="true", DEV_EXPOSE_AUTH_CODES="false"),
                         (True, False))

    def test_expor_codigos_so_liga_com_a_variavel_explicita(self):
        self.assertEqual(_ler_config(FLASK_DEBUG="false", DEV_EXPOSE_AUTH_CODES="true"),
                         (False, True))

    def test_os_dois_interruptores_sao_independentes(self):
        self.assertEqual(_ler_config(FLASK_DEBUG="true", DEV_EXPOSE_AUTH_CODES="true"),
                         (True, True))

    def test_smtp_ausente_nao_liga_nada(self):
        # SMTP vazio nao e permissao: os interruptores seguem desligados.
        self.assertEqual(
            _ler_config(SMTP_HOST="", FLASK_DEBUG="", DEV_EXPOSE_AUTH_CODES=""),
            (False, False))


class AppSemDebugFixoTest(unittest.TestCase):
    def test_app_py_nao_tem_debug_fixo(self):
        with open(os.path.join(BACKEND, "app.py"), encoding="utf-8") as arquivo:
            fonte = arquivo.read()
        self.assertNotIn("debug=True", fonte)
        self.assertIn("app.run(debug=DEBUG)", fonte)
        self.assertIn("from config import DEBUG", fonte)

    def test_expor_codigos_dev_le_a_configuracao_vigente(self):
        from services import email_service
        with patch.object(config, "DEV_EXPOSE_AUTH_CODES", False):
            self.assertFalse(email_service.expor_codigos_dev())
        with patch.object(config, "DEV_EXPOSE_AUTH_CODES", True):
            self.assertTrue(email_service.expor_codigos_dev())

    def test_sem_smtp_e_sem_dev_nada_e_enviado_nem_impresso(self):
        import io
        from contextlib import redirect_stdout
        from services import email_service
        saida = io.StringIO()
        with patch.object(config, "DEV_EXPOSE_AUTH_CODES", False), \
                patch.dict(email_service.SMTP_CONFIG, {"host": ""}), \
                redirect_stdout(saida):
            enviado = email_service.enviar_codigo_verificacao("a@b.cc", "123456")
            convite = email_service.enviar_convite_professor(
                "Ana", "a@b.cc", "TOKEN-SECRETO-DE-TESTE", "Escola")
        self.assertFalse(enviado)
        self.assertFalse(convite)
        self.assertEqual(saida.getvalue(), "")

    def test_sem_smtp_com_dev_imprime_no_console_e_conta_como_entregue(self):
        import io
        from contextlib import redirect_stdout
        from services import email_service
        saida = io.StringIO()
        with patch.object(config, "DEV_EXPOSE_AUTH_CODES", True), \
                patch.dict(email_service.SMTP_CONFIG, {"host": ""}), \
                redirect_stdout(saida):
            enviado = email_service.enviar_codigo_verificacao("a@b.cc", "123456")
        self.assertTrue(enviado)
        self.assertIn("123456", saida.getvalue())


class SemSegredoRealTest(unittest.TestCase):
    def test_env_example_traz_os_interruptores_desligados_e_sem_valores_secretos(self):
        with open(os.path.join(BACKEND, ".env.example"), encoding="utf-8") as arquivo:
            linhas = [l.strip() for l in arquivo if "=" in l and not l.startswith("#")]
        valores = dict(l.split("=", 1) for l in linhas)
        self.assertEqual(valores["FLASK_DEBUG"], "false")
        self.assertEqual(valores["DEV_EXPOSE_AUTH_CODES"], "false")
        for chave in ("SECRET_KEY", "AI_API_KEY", "DB_PASSWORD", "SMTP_PASSWORD"):
            self.assertEqual(valores.get(chave, ""), "", chave)

    def test_nenhum_segredo_da_configuracao_aparece_nos_scripts_nem_no_exemplo(self):
        # Compara os valores reais carregados (sem imprimi-los) com o texto dos
        # arquivos versionados de teste e do .env.example.
        segredos = [v for v in (config.SECRET_KEY, config.AI_CONFIG["api_key"],
                                config.DB_CONFIG["password"],
                                config.SMTP_CONFIG["password"])
                    if v and len(v) >= 8]
        alvos = [os.path.join(BACKEND, ".env.example")]
        pasta = os.path.join(BACKEND, "scripts")
        alvos += [os.path.join(pasta, nome) for nome in os.listdir(pasta)
                  if nome.endswith(".py")]
        for caminho in alvos:
            with open(caminho, encoding="utf-8") as arquivo:
                texto = arquivo.read()
            for segredo in segredos:
                self.assertNotIn(segredo, texto, os.path.basename(caminho))
            self.assertIsNone(re.search(r"gsk_[A-Za-z0-9]{20,}", texto),
                              os.path.basename(caminho))
            self.assertIsNone(re.search(r"sk-[A-Za-z0-9]{30,}", texto),
                              os.path.basename(caminho))


if __name__ == "__main__":
    unittest.main()

"""Servidor local de QA, isolado da base pessoal e sem envio externo."""
import os
import sys
import logging

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ["DB_NAME"] = "mentorly_interface_regressao"
os.environ["MAIL_SERVER"] = ""
os.environ["SMTP_HOST"] = ""
os.environ["FRONTEND_URL"] = "http://127.0.0.1:18080"
os.environ["DEV_EXPOSE_AUTH_CODES"] = "false"

from app import create_app
from database.connection import init_database, install_schema, install_procedures
from models.coordenacao_model import Coordenacao
from services.auth.cadastro_coordenacao import CadastroCoordenacaoService
from services.config.anos_letivos import CriarAnoLetivoService


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    init_database()
    install_schema()
    install_procedures()
    if not Coordenacao.find_by_email("validacao@escola.invalid"):
        usuario = CadastroCoordenacaoService().execute("Escola de validação", "validacao@escola.invalid", "validacao123", "11999999999")
        CriarAnoLetivoService().execute(usuario["usuario"]["id"], 2026, "atual")
    create_app().run(host="127.0.0.1", port=5001, debug=False)

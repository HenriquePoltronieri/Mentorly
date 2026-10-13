"""Envia UM convite autorizado para a escola de QA, sem imprimir segredos."""
import os
import sys
import json

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ["DB_NAME"] = "mentorly_interface_regressao"
os.environ["FRONTEND_URL"] = "http://127.0.0.1:18080"
os.environ["DEV_EXPOSE_AUTH_CODES"] = "false"

from app import create_app
from auth.jwt_utils import gerar_token
from models.coordenacao_model import Coordenacao
from database.connection import query_one


if __name__ == "__main__":
    escola = Coordenacao.find_by_email("validacao@escola.invalid")
    if not escola:
        raise SystemExit("Inicie servir_validacao.py primeiro.")
    existente = query_one("SELECT id FROM professor WHERE email=%s AND coordenacao_id=%s", (sys.argv[1], escola["id"]))
    caminho = ("/api/coordenacao/professores/%s/reenviar-convite" % existente["id"]
               if existente else "/api/coordenacao/professores")
    resposta = create_app().test_client().post(caminho, headers={
        "Authorization": "Bearer " + gerar_token(escola["id"], "coordenacao", escola["id"]),
    }, json={"nome": "Luca — teste de convite", "email": sys.argv[1], "disciplina": "Validação"})
    dados = resposta.get_json()
    print(json.dumps({"status": resposta.status_code, "conviteEnviado": dados.get("conviteEnviado"),
                      "erro": dados.get("error")}, ensure_ascii=True))

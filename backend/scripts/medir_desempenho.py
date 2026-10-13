"""Mede leituras reais sem alterar dados nem enviar e-mails."""
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from app import create_app
from auth.jwt_utils import gerar_token
from database.connection import query_one


def medir():
    escola = query_one("SELECT id FROM coordenacao ORDER BY id LIMIT 1")
    if not escola:
        raise SystemExit("Cadastre uma escola para medir as leituras.")
    cliente = create_app().test_client()
    headers = {"Authorization": "Bearer " + gerar_token(escola["id"], "coordenacao", escola["id"])}
    resultados = {}
    for rota in ("/api/coordenacao/professores", "/api/config/etapas", "/api/config/anos-letivos", "/api/classes", "/api/dashboard/resumo"):
        inicio = time.perf_counter()
        resposta = cliente.get(rota, headers=headers)
        resultados[rota] = {"ms": round((time.perf_counter() - inicio) * 1000, 2), "status": resposta.status_code}
    return resultados


if __name__ == "__main__":
    resultado = medir()
    print(json.dumps(resultado, indent=2))
    if len(sys.argv) > 1:
        with open(sys.argv[1], "w", encoding="utf-8") as arquivo:
            json.dump(resultado, arquivo, indent=2)

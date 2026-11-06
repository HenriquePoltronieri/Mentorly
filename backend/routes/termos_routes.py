"""Consulta publica dos documentos e decisoes autenticadas."""

from flask import Blueprint, g, jsonify, request

from auth.decorators import auth_required
from services.termos import (documentos_atuais, historico, registrar_decisoes,
                            situacao)


termos_blueprint = Blueprint("termos", __name__, url_prefix="/api/termos")


@termos_blueprint.get("/atuais")
def atuais():
    resposta = jsonify({"documentos": documentos_atuais()})
    resposta.headers["Cache-Control"] = "no-store"
    return resposta


@termos_blueprint.get("/status")
@auth_required
def status():
    return jsonify(situacao(g.usuario))


@termos_blueprint.post("/decisoes")
@auth_required
def decidir():
    try:
        return jsonify(registrar_decisoes(g.usuario, request.get_json(silent=True)))
    except ValueError as erro:
        return jsonify({"error": str(erro)}), 400


@termos_blueprint.get("/historico")
@auth_required
def consultar_historico():
    return jsonify({"eventos": historico(g.usuario)})

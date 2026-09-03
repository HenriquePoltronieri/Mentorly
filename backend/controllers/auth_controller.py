"""Controller de autenticacao: so HTTP, nada de SQL nem regra de negocio.

O contrato de resposta ({token, usuario}) e o que o AuthService do Flutter
(core/services/authService.dart) ja espera.
"""

from flask import jsonify, request

from services.auth.cadastro_coordenacao import CadastroCoordenacaoService
from services.auth.criar_senha_professor import CriarSenhaProfessorService
from services.auth.login_coordenacao import LoginCoordenacaoService
from services.auth.login_professor import LoginProfessorService
from services.auth.verificacao_duas_etapas import (
    ConfirmarCodigoService,
    EnviarCodigoService,
)


class AuthController:
    def cadastro_coordenacao(self):
        dados = request.get_json(silent=True) or {}
        try:
            resultado = CadastroCoordenacaoService().execute(
                dados.get("nome"),
                dados.get("email"),
                dados.get("senha"),
                dados.get("telefone"),
            )
        except ValueError as erro:
            return jsonify({"error": str(erro)}), 400
        return jsonify(resultado), 201

    def login_coordenacao(self):
        dados = request.get_json(silent=True) or {}
        try:
            resultado = LoginCoordenacaoService().execute(
                dados.get("email"), dados.get("senha")
            )
        except ValueError as erro:
            return jsonify({"error": str(erro)}), 400
        except PermissionError as erro:
            return jsonify({"error": str(erro)}), 401
        return jsonify(resultado)

    def login_professor(self):
        dados = request.get_json(silent=True) or {}
        try:
            resultado = LoginProfessorService().execute(
                dados.get("email"), dados.get("senha")
            )
        except ValueError as erro:
            return jsonify({"error": str(erro)}), 400
        except PermissionError as erro:
            return jsonify({"error": str(erro)}), 401
        return jsonify(resultado)

    def criar_senha_professor(self):
        dados = request.get_json(silent=True) or {}
        try:
            resultado = CriarSenhaProfessorService().execute(
                dados.get("email"), dados.get("senha"), dados.get("token")
            )
        except ValueError as erro:
            return jsonify({"error": str(erro)}), 400
        except PermissionError as erro:
            return jsonify({"error": str(erro)}), 403
        return jsonify(resultado)

    def enviar_codigo(self):
        dados = request.get_json(silent=True) or {}
        try:
            resultado = EnviarCodigoService().execute(dados.get("email"))
        except ValueError as erro:
            return jsonify({"error": str(erro)}), 400
        return jsonify(resultado)

    def confirmar_codigo(self):
        dados = request.get_json(silent=True) or {}
        try:
            resultado = ConfirmarCodigoService().execute(
                dados.get("email"), dados.get("codigo")
            )
        except ValueError as erro:
            return jsonify({"error": str(erro)}), 400
        return jsonify(resultado)

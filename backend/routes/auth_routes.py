from flask import Blueprint

from controllers.auth_controller import AuthController

auth_blueprint = Blueprint("auth", __name__, url_prefix="/api/auth")
auth_controller = AuthController()


@auth_blueprint.post("/cadastro-coordenacao")
def cadastro_coordenacao():
    return auth_controller.cadastro_coordenacao()


@auth_blueprint.post("/login-coordenacao")
def login_coordenacao():
    return auth_controller.login_coordenacao()


@auth_blueprint.post("/login-professor")
def login_professor():
    return auth_controller.login_professor()


@auth_blueprint.post("/criar-senha-professor")
def criar_senha_professor():
    return auth_controller.criar_senha_professor()


@auth_blueprint.post("/enviar-codigo")
def enviar_codigo():
    return auth_controller.enviar_codigo()


@auth_blueprint.post("/confirmar-codigo")
def confirmar_codigo():
    return auth_controller.confirmar_codigo()

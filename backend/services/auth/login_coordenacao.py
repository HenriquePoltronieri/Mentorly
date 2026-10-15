from auth.passwords import conferir_senha

from auth.jwt_utils import TIPO_COORDENACAO, gerar_token
from models.coordenacao_model import Coordenacao
from services import entrada


class LoginCoordenacaoService:
    """Login da Coordenacao.

    A mensagem de erro e a mesma para email inexistente e senha errada, de
    proposito: nao vale entregar quais emails estao cadastrados.
    """

    def execute(self, email, senha):
        email = entrada.texto(email, "O email", entrada.LIMITE_EMAIL).lower()
        senha = entrada.senha(senha)
        if not email or not senha:
            raise ValueError("Informe email e senha")

        linha = Coordenacao.find_by_email(email)
        if not conferir_senha(linha['senha_hash'] if linha else None, senha):
            raise PermissionError("Email ou senha invalidos")

        return {
            "token": gerar_token(linha["id"], TIPO_COORDENACAO, linha["id"]),
            "usuario": Coordenacao.to_dict(linha),
        }

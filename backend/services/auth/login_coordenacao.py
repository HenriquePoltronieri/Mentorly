from werkzeug.security import check_password_hash

from auth.jwt_utils import TIPO_COORDENACAO, gerar_token
from models.coordenacao_model import Coordenacao


class LoginCoordenacaoService:
    """Login da Coordenacao.

    A mensagem de erro e a mesma para email inexistente e senha errada, de
    proposito: nao vale entregar quais emails estao cadastrados.
    """

    def execute(self, email, senha):
        email = (email or "").strip().lower()
        if not email or not senha:
            raise ValueError("Informe email e senha")

        linha = Coordenacao.find_by_email(email)
        if not linha or not check_password_hash(linha["senha_hash"], senha):
            raise PermissionError("Email ou senha invalidos")

        return {
            "token": gerar_token(linha["id"], TIPO_COORDENACAO, linha["id"]),
            "usuario": Coordenacao.to_dict(linha),
        }

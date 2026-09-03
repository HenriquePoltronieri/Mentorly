from werkzeug.security import generate_password_hash

from auth.jwt_utils import TIPO_COORDENACAO, gerar_token
from models.coordenacao_model import Coordenacao


class CadastroCoordenacaoService:
    """Cadastra uma nova escola.

    Cada cadastro de coordenacao cria uma escola independente: a partir
    daqui, todo dado criado por este login fica isolado dos demais.
    """

    def execute(self, nome, email, senha, telefone=None):
        nome = (nome or "").strip()
        email = (email or "").strip().lower()

        if not nome:
            raise ValueError("O nome e obrigatorio")
        if not email:
            raise ValueError("O email e obrigatorio")
        if not senha or len(senha) < 6:
            raise ValueError("A senha precisa ter ao menos 6 caracteres")

        if Coordenacao.find_by_email(email):
            raise ValueError("Ja existe uma coordenacao com este email")

        coordenacao_id = Coordenacao.create(
            nome, email, generate_password_hash(senha), telefone
        )
        linha = Coordenacao.find_by_id(coordenacao_id)

        return {
            "token": gerar_token(coordenacao_id, TIPO_COORDENACAO, coordenacao_id),
            "usuario": Coordenacao.to_dict(linha),
        }

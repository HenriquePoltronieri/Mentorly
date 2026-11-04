from werkzeug.security import generate_password_hash

from auth.jwt_utils import TIPO_COORDENACAO, gerar_token
from models.coordenacao_model import Coordenacao
from models.codigo_model import CodigoVerificacao
from services import entrada


class CadastroCoordenacaoService:
    """Cadastra uma nova escola.

    Cada cadastro de coordenacao cria uma escola independente: a partir
    daqui, todo dado criado por este login fica isolado dos demais.
    """

    def execute(self, nome, email, senha, telefone=None,
                codigo_verificacao=None, exigir_verificacao=False):
        nome = entrada.texto(nome, "O nome", entrada.LIMITE_NOME)
        email = entrada.email(email)
        senha = entrada.senha(senha)
        telefone = entrada.telefone_brasileiro(telefone)

        if not nome:
            raise ValueError("O nome e obrigatorio")
        if not senha or len(senha) < 8:
            raise ValueError("A senha precisa ter ao menos 8 caracteres")

        if Coordenacao.find_by_email(email):
            raise ValueError("Ja existe uma coordenacao com este email")

        if exigir_verificacao:
            codigo = entrada.texto(
                codigo_verificacao, "O código", entrada.LIMITE_CODIGO
            )
            if not codigo or not CodigoVerificacao.validar(email, codigo):
                raise entrada.EntradaInvalida(
                    "Código inválido ou expirado. Peça um novo código."
                )

        coordenacao_id = Coordenacao.create(
            nome, email, generate_password_hash(senha), telefone
        )
        linha = Coordenacao.find_by_id(coordenacao_id)

        return {
            "token": gerar_token(coordenacao_id, TIPO_COORDENACAO, coordenacao_id),
            "usuario": Coordenacao.to_dict(linha),
        }

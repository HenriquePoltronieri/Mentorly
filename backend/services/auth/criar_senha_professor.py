from datetime import datetime

from werkzeug.security import generate_password_hash

from auth.jwt_utils import TIPO_PROFESSOR, gerar_token
from models.professor_model import Professor
from services import entrada


class CriarSenhaProfessorService:
    """Primeiro acesso do professor, pelo convite enviado por email.

    O convite e de uso unico: definir_senha limpa o convite_token, entao o
    mesmo link nao funciona duas vezes.
    """

    def execute(self, email, senha, token):
        email = entrada.texto(email, "O email", entrada.LIMITE_EMAIL).lower()
        senha = entrada.senha(senha)
        token = entrada.texto(token, "O convite", entrada.LIMITE_CODIGO)

        if not senha or len(senha) < 6:
            raise ValueError("A senha precisa ter ao menos 6 caracteres")
        if not token:
            raise ValueError("Convite invalido")

        linha = Professor.find_by_convite(token)
        if not linha:
            raise PermissionError("Convite invalido ou ja utilizado")

        if not linha.get("habilitado", True):
            raise PermissionError("Professor desativado. Procure a Coordenacao.")

        # O email digitado precisa bater com o dono do convite: sem isso,
        # quem tivesse o link poderia ativar a conta de outro professor.
        if email and linha["email"].lower() != email:
            raise PermissionError("O convite nao pertence a este email")

        expira_em = linha.get("convite_expira_em")
        if expira_em and expira_em < datetime.now():
            raise PermissionError("Convite expirado. Peca um novo a coordenacao.")

        Professor.definir_senha(linha["id"], generate_password_hash(senha))
        atualizado = Professor.find_by_id(linha["id"])

        return {
            "token": gerar_token(
                linha["id"], TIPO_PROFESSOR, linha["coordenacao_id"]
            ),
            "usuario": Professor.to_dict(atualizado),
        }

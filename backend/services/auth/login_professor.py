from auth.passwords import conferir_senha

from auth.jwt_utils import TIPO_PROFESSOR, gerar_token
from models.professor_model import Professor
from services import entrada


class LoginProfessorService:
    """Login do Professor.

    O token carrega a coordenacao_id da escola dele: e por ela que as
    consultas do professor sao limitadas depois.
    """

    def execute(self, email, senha):
        email = entrada.texto(email, "O email", entrada.LIMITE_EMAIL).lower()
        senha = entrada.senha(senha)
        if not email or not senha:
            raise ValueError("Informe email e senha")

        linha = Professor.find_by_email(email)
        if not conferir_senha(linha.get('senha_hash') if linha else None, senha):
            raise PermissionError("Email ou senha invalidos")

        if not linha.get("habilitado", True):
            raise PermissionError("Professor desativado. Procure a Coordenacao.")

        return {
            "token": gerar_token(
                linha["id"], TIPO_PROFESSOR, linha["coordenacao_id"]
            ),
            "usuario": Professor.to_dict(linha),
        }

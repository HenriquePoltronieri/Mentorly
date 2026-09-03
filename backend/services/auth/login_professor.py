from werkzeug.security import check_password_hash

from auth.jwt_utils import TIPO_PROFESSOR, gerar_token
from models.professor_model import Professor


class LoginProfessorService:
    """Login do Professor.

    O token carrega a coordenacao_id da escola dele: e por ela que as
    consultas do professor sao limitadas depois.
    """

    def execute(self, email, senha):
        email = (email or "").strip().lower()
        if not email or not senha:
            raise ValueError("Informe email e senha")

        linha = Professor.find_by_email(email)
        if not linha:
            raise PermissionError("Email ou senha invalidos")

        # Professor cadastrado pela coordenacao que ainda nao abriu o convite
        # nao tem senha. Aqui a mensagem e especifica porque ajuda o usuario
        # e nao revela nada que ele ja nao saiba.
        if not linha["senha_hash"]:
            raise PermissionError(
                "Voce ainda nao criou sua senha. Use o link do convite "
                "enviado por email."
            )

        if not check_password_hash(linha["senha_hash"], senha):
            raise PermissionError("Email ou senha invalidos")

        return {
            "token": gerar_token(
                linha["id"], TIPO_PROFESSOR, linha["coordenacao_id"]
            ),
            "usuario": Professor.to_dict(linha),
        }

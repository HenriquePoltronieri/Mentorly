from datetime import datetime, timedelta

from auth.jwt_utils import gerar_token_convite
from config import CONVITE_EXPIRACAO_HORAS
from models.coordenacao_model import Coordenacao
from models.professor_model import Professor
from services.email_service import enviar_convite_professor, modo_dev


class CadastrarProfessorService:
    """Cadastra um professor NA ESCOLA de quem esta logado.

    O professor nao escolhe a escola dele e nao cria a propria conta: quem
    cadastra e a Coordenacao. Ele recebe um convite por email e so define a
    senha.
    """

    def execute(self, coordenacao_id, nome, email, disciplina=None):
        nome = (nome or "").strip()
        email = (email or "").strip().lower()

        if not nome:
            raise ValueError("O nome do professor e obrigatorio")
        if not email:
            raise ValueError("O email do professor e obrigatorio")

        existente = Professor.find_by_email(email)
        if existente:
            if existente["coordenacao_id"] == coordenacao_id:
                raise ValueError("Este professor ja esta cadastrado nesta escola")
            # Email global unico: um professor pertence a uma escola so.
            raise ValueError("Este email ja esta em uso por outra escola")

        token = gerar_token_convite()
        expira_em = datetime.now() + timedelta(hours=CONVITE_EXPIRACAO_HORAS)

        professor_id = Professor.create(
            coordenacao_id, nome, email, disciplina, token, expira_em
        )

        escola = Coordenacao.find_by_id(coordenacao_id)
        enviado = enviar_convite_professor(
            nome, email, token, escola["nome"] if escola else "sua escola"
        )

        resposta = Professor.to_dict(Professor.find_by_id(professor_id))
        resposta["conviteEnviado"] = enviado
        if modo_dev():
            # Sem SMTP configurado, a coordenacao precisa do token na tela
            # para conseguir passar o primeiro acesso ao professor.
            resposta["conviteToken"] = token
        return resposta

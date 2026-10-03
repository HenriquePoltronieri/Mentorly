"""Casos de uso administrativos do ciclo de vida do Professor.

O identificador da Coordenacao e sempre recebido do JWT pelo controller.
Assim, todos os comandos abaixo primeiro encontram o professor dentro da
escola logada antes de qualquer alteracao.
"""

from datetime import datetime, timedelta

from auth.jwt_utils import gerar_token_convite
from config import CONVITE_EXPIRACAO_HORAS
from models.coordenacao_model import Coordenacao
from models.professor_model import Professor
from services.email_service import enviar_convite_professor, modo_dev


def _professor_da_escola(coordenacao_id, professor_id):
    professor = Professor.find_by_id(professor_id, coordenacao_id)
    if not professor:
        raise LookupError("Professor nao encontrado")
    return professor


def _novo_convite(coordenacao_id, professor):
    token = gerar_token_convite()
    expira_em = datetime.now() + timedelta(hours=CONVITE_EXPIRACAO_HORAS)
    Professor.atualizar_convite(professor["id"], token, expira_em)
    escola = Coordenacao.find_by_id(coordenacao_id)
    enviado = enviar_convite_professor(
        professor["nome"], professor["email"], token,
        escola["nome"] if escola else "sua escola",
    )
    resposta = Professor.to_dict(Professor.find_by_id(professor["id"], coordenacao_id))
    resposta["conviteEnviado"] = enviado
    if modo_dev():
        resposta["conviteToken"] = token
    return resposta


class EditarProfessorService:
    def execute(self, coordenacao_id, professor_id, nome=None, email=None,
                disciplina=None):
        professor = _professor_da_escola(coordenacao_id, professor_id)
        campos = {}
        if nome is not None:
            nome = str(nome).strip()
            if not nome:
                raise ValueError("O nome do professor e obrigatorio")
            campos["nome"] = nome
        if email is not None:
            email = str(email).strip().lower()
            if not email:
                raise ValueError("O email do professor e obrigatorio")
            existente = Professor.find_by_email(email)
            if existente and existente["id"] != professor_id:
                raise ValueError("Este email ja esta em uso por outro professor")
            campos["email"] = email
        if disciplina is not None:
            campos["disciplina"] = str(disciplina).strip() or None

        if not campos:
            raise ValueError("Informe ao menos um dado para editar")
        Professor.update(professor_id, coordenacao_id, **campos)
        atualizado = Professor.find_by_id(professor_id, coordenacao_id)

        # O antigo destinatario nao pode aproveitar convite pendente depois
        # que a Coordenacao troca o endereco. Conta ativa mantem a senha.
        if ("email" in campos and not atualizado.get("senha_hash")
                and atualizado.get("habilitado", True)):
            return _novo_convite(coordenacao_id, atualizado)
        return Professor.to_dict(atualizado)


class DesativarProfessorService:
    def execute(self, coordenacao_id, professor_id):
        _professor_da_escola(coordenacao_id, professor_id)
        Professor.definir_habilitado(professor_id, coordenacao_id, False)
        return Professor.to_dict(Professor.find_by_id(professor_id, coordenacao_id))


class ReativarProfessorService:
    def execute(self, coordenacao_id, professor_id):
        _professor_da_escola(coordenacao_id, professor_id)
        Professor.definir_habilitado(professor_id, coordenacao_id, True)
        return Professor.to_dict(Professor.find_by_id(professor_id, coordenacao_id))


class ReenviarConviteProfessorService:
    def execute(self, coordenacao_id, professor_id):
        professor = _professor_da_escola(coordenacao_id, professor_id)
        if not professor.get("habilitado", True):
            raise ValueError("Professor desativado nao pode receber convite")
        if professor.get("senha_hash"):
            raise ValueError("Este professor ja criou a senha")
        return _novo_convite(coordenacao_id, professor)

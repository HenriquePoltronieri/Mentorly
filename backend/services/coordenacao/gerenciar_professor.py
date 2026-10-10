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
from services import entrada
from services.rate_limit import limitar_convite
from services.email_service import enviar_convite_professor, expor_codigos_dev


def _professor_da_escola(coordenacao_id, professor_id):
    professor = Professor.find_by_id(professor_id, coordenacao_id)
    if not professor:
        raise LookupError("Professor nao encontrado")
    return professor


def _novo_convite(coordenacao_id, professor, contar=True):
    # Reenviar o convite e trocar o e-mail de um professor pendente mandam um
    # e-mail novo: o limite e por escola + professor (a Coordenacao trabalha
    # normalmente; so o martelar do mesmo professor e barrado).
    if contar:
        limitar_convite(coordenacao_id, professor["id"])
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
    if expor_codigos_dev():
        resposta["conviteToken"] = token
    return resposta


class EditarProfessorService:
    def execute(self, coordenacao_id, professor_id, nome=None, email=None,
                disciplina=None):
        professor = _professor_da_escola(coordenacao_id, professor_id)
        campos = {}
        if nome is not None:
            nome = entrada.texto(nome, "O nome do professor", entrada.LIMITE_NOME)
            if not nome:
                raise ValueError("O nome do professor e obrigatorio")
            campos["nome"] = nome
        if email is not None:
            email = entrada.texto(
                email, "O email do professor", entrada.LIMITE_EMAIL
            ).lower()
            if not email:
                raise ValueError("O email do professor e obrigatorio")
            existente = Professor.find_by_email(email)
            if existente and existente["id"] != professor_id:
                raise ValueError("Este email ja esta em uso por outro professor")
            campos["email"] = email
        if disciplina is not None:
            campos["disciplina"] = entrada.texto(
                disciplina, "A disciplina", entrada.LIMITE_DISCIPLINA
            ) or None

        if not campos:
            raise ValueError("Informe ao menos um dado para editar")
        # O antigo destinatario nao pode aproveitar convite pendente depois
        # que a Coordenacao troca o endereco. Conta ativa mantem a senha.
        renova_convite = ("email" in campos and not professor.get("senha_hash")
                          and professor.get("habilitado", True))
        if renova_convite:
            # Confere o limite ANTES de gravar o e-mail novo: um 429 nao pode
            # deixar o e-mail trocado com o convite antigo ainda valendo.
            limitar_convite(coordenacao_id, professor_id)
        Professor.update(professor_id, coordenacao_id, **campos)
        atualizado = Professor.find_by_id(professor_id, coordenacao_id)

        if renova_convite:
            return _novo_convite(coordenacao_id, atualizado, contar=False)
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

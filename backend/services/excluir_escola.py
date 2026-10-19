"""Exclusao definitiva de uma escola pela administracao do Mentorly."""

from models.coordenacao_model import Coordenacao
from services import entrada


class ExcluirEscolaService:
    """Remove uma coordenacao e todos os dados que pertencem a ela.

    A confirmacao pelo e-mail evita que um clique ou uma tela desatualizada
    apague uma escola diferente. Os deletes ficam em uma transacao: se alguma
    relacao inesperada impedir a exclusao, nenhum dado e removido pela metade.
    """

    def execute(self, escola_id, email_confirmacao):
        email_confirmacao = entrada.texto(
            email_confirmacao, 'O e-mail de confirmacao', entrada.LIMITE_EMAIL
        ).lower()

        Coordenacao.excluir_com_dependencias(escola_id, email_confirmacao)

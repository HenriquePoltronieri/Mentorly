"""Exclusao definitiva de uma escola pela administracao do Mentorly."""

from database.connection import transacao
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

        with transacao() as cursor:
            cursor.execute(
                'SELECT id,email FROM coordenacao WHERE id=%s FOR UPDATE',
                (escola_id,),
            )
            escola = cursor.fetchone()
            if not escola:
                raise ValueError('Esta escola ja nao existe. Atualize a lista.')
            if email_confirmacao != escola['email']:
                raise ValueError('Digite exatamente o e-mail da escola para confirmar a exclusao.')

            # Codigos temporarios nao possuem FK e nao podem sobreviver a conta.
            cursor.execute('DELETE FROM codigo_verificacao WHERE email=%s', (escola['email'],))
            cursor.execute(
                'DELETE cv FROM codigo_verificacao cv '
                'INNER JOIN professor p ON p.email=cv.email '
                'WHERE p.coordenacao_id=%s',
                (escola_id,),
            )

            # Atividades precisam sair antes de professor, etapa e criterio;
            # notas e situacoes vinculadas sao apagadas pelas FKs em cascata.
            cursor.execute('DELETE FROM atividade WHERE coordenacao_id=%s', (escola_id,))
            cursor.execute(
                'DELETE al FROM aluno al INNER JOIN turma t ON t.id=al.turma_id '
                'WHERE t.coordenacao_id=%s',
                (escola_id,),
            )
            cursor.execute('DELETE FROM professor_turma WHERE coordenacao_id=%s', (escola_id,))
            cursor.execute('DELETE FROM professor WHERE coordenacao_id=%s', (escola_id,))
            cursor.execute('DELETE FROM criterio WHERE coordenacao_id=%s', (escola_id,))
            cursor.execute('DELETE FROM etapa WHERE coordenacao_id=%s', (escola_id,))
            cursor.execute('DELETE FROM turma WHERE coordenacao_id=%s', (escola_id,))
            cursor.execute('DELETE FROM ano_letivo WHERE coordenacao_id=%s', (escola_id,))
            cursor.execute('DELETE FROM coordenacao WHERE id=%s', (escola_id,))

"""Consultas de turma que nao sao CRUD simples.

A regra da arquitetura: CRUD fica na Model, relatorio/agregacao fica aqui,
e o CALL de procedure so acontece via database.procedure.call_procedure.
"""

from database.procedure import call_procedure
from models.utils import normalizar_lista


class TurmaRepository:
    def relatorio_turmas_atividades(self, coordenacao_id):
        """Turmas da escola com a contagem de atividades (procedure).

        Recebe coordenacao_id porque a procedure filtra por escola: o
        relatorio de uma coordenacao nunca inclui turma de outra.
        """
        return normalizar_lista(
            call_procedure("sp_relatorio_turmas_atividades", coordenacao_id)
        )

    def turmas_do_professor(self, professor_id):
        """Turmas vinculadas ao professor (procedure)."""
        return normalizar_lista(
            call_procedure("sp_turmas_do_professor", professor_id)
        )

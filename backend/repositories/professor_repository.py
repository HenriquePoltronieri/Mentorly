"""Consultas de professor que nao sao CRUD simples."""

from database.procedure import call_procedure
from models.utils import normalizar_lista


class ProfessorRepository:
    def professores_por_coordenacao(self, coordenacao_id):
        """Professores da escola, com a contagem de turmas (procedure).

        Substitui a antiga sp_usuarios_por_role, que devolvia todos os
        professores do sistema sem filtro nenhum de escola.
        """
        return normalizar_lista(
            call_procedure("sp_professores_por_coordenacao", coordenacao_id)
        )

    def alunos_em_risco(self, professor_id, ano_letivo):
        """Alunos com media abaixo da nota minima da escola (procedure)."""
        return normalizar_lista(
            call_procedure("sp_alunos_em_risco", professor_id, ano_letivo)
        )

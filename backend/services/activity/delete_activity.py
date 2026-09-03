from models.atividade_model import Atividade
from models.professor_turma_model import ProfessorTurma


class DeleteActivityService:
    """Exclui a atividade. As notas dela caem junto (CASCADE no schema)."""

    def execute(self, atividade_id, professor_id):
        atual = Atividade.find_by_id(atividade_id)
        if not atual:
            raise LookupError("Atividade nao encontrada")
        if not ProfessorTurma.professor_leciona_na_turma(
            professor_id, atual["turma_id"]
        ):
            raise LookupError("Atividade nao encontrada")
        Atividade.delete(atividade_id)

from models.turma_model import Turma


class DeleteClassService:
    """Exclui a turma. O schema cascateia alunos, atividades e notas dela."""

    def execute(self, turma_id, coordenacao_id):
        if not Turma.find_by_id(turma_id, coordenacao_id):
            raise LookupError("Turma nao encontrada")
        Turma.delete(turma_id, coordenacao_id)

from models.atividade_model import Atividade
from models.professor_turma_model import ProfessorTurma


class GetActivityService:
    def execute(self, atividade_id, coordenacao_id, professor_id=None):
        linha = Atividade.find_by_id(atividade_id)
        if not linha:
            return None

        # Atividade de outra escola: trata como inexistente.
        if linha["coordenacao_id"] != coordenacao_id:
            return None

        if professor_id is not None and not ProfessorTurma.professor_leciona_na_turma(
            professor_id, linha["turma_id"]
        ):
            return None

        return Atividade.to_dict(linha)

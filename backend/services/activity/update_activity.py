from models.atividade_model import Atividade
from models.professor_turma_model import ProfessorTurma
from services.activity.create_activity import parse_data


class UpdateActivityService:
    def execute(self, atividade_id, professor_id, titulo=None, descricao=None,
                turma_id=None, data_entrega=None, etapa_id=None,
                criterio_id=None, nota_maxima=None):
        atual = Atividade.find_by_id(atividade_id)
        if not atual:
            raise LookupError("Atividade nao encontrada")

        # A atividade tem que estar em uma turma do professor logado.
        if not ProfessorTurma.professor_leciona_na_turma(
            professor_id, atual["turma_id"]
        ):
            raise LookupError("Atividade nao encontrada")

        if titulo is not None:
            titulo = titulo.strip()
            if not titulo:
                raise ValueError("O titulo nao pode ficar vazio")

        # Mover a atividade para outra turma so vale se a turma destino
        # tambem for do professor.
        if turma_id is not None and turma_id != atual["turma_id"]:
            if not ProfessorTurma.professor_leciona_na_turma(
                professor_id, turma_id
            ):
                raise LookupError("Turma nao encontrada")

        Atividade.update(
            atividade_id, titulo, descricao, turma_id,
            parse_data(data_entrega), etapa_id, criterio_id, nota_maxima,
        )
        return Atividade.to_dict(Atividade.find_by_id(atividade_id))

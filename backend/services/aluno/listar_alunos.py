from models.aluno_model import Aluno
from services.aluno.acesso_turma import turma_acessivel


class ListarAlunosService:
    def execute(self, turma_id, coordenacao_id, professor_id=None):
        turma_acessivel(turma_id, coordenacao_id, professor_id)
        linhas = Aluno.find_all_by_turma(turma_id)
        return [Aluno.to_dict(linha) for linha in linhas]

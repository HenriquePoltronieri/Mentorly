from models.turma_model import Turma
from repositories.turma_repository import TurmaRepository


class ListarTurmasDoProfessorService:
    """Turmas que o professor logado leciona.

    Fonte unica: o vinculo professor_turma criado pela Coordenacao. Um
    professor nunca ve turma de outro professor, nem turma da propria escola
    que nao foi vinculada a ele.
    """

    def __init__(self):
        self._repositorio = TurmaRepository()

    def execute(self, professor_id):
        linhas = self._repositorio.turmas_do_professor(professor_id)

        # A procedure devolve as chaves em portugues, mas parte das telas do
        # app usa TurmaModel.fromJson, que le "name"/"description". Sem os
        # dois formatos, a lista de atividades aparece com o nome em branco.
        return [
            {
                "id": linha["id"],
                "name": linha.get("nome"),
                "nome": linha.get("nome"),
                "description": linha.get("descricao"),
                "descricao": linha.get("descricao"),
                "disciplina": linha.get("disciplina"),
                "turno": linha.get("turno"),
                "anoLetivo": linha.get("anoLetivo"),
                "totalAlunos": linha.get("totalAlunos", 0),
            }
            for linha in linhas
        ]


class ListarAlunosDaTurmaService:
    """Alunos de uma turma do professor."""

    def execute(self, turma_id, professor_id):
        from models.aluno_model import Aluno

        if not Turma.find_by_id_para_professor(turma_id, professor_id):
            raise LookupError("Turma nao encontrada")
        return [Aluno.to_dict(a) for a in Aluno.find_all_by_turma(turma_id)]

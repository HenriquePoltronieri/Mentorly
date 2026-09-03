from datetime import date

from models.professor_model import Professor
from models.professor_turma_model import ProfessorTurma
from repositories.professor_repository import ProfessorRepository


class DashboardProfessorService:
    """Resumo do professor logado.

    Devolve o formato que dashboardScreen.dart documenta no cabecalho:
    nome, email, totalTurmas, totalAlunos e alunosEmRisco.

    'Aluno em risco' usa a nota minima configurada pela Coordenacao no
    fluxo de ano letivo - por isso o numero so aparece depois de a escola
    configurar as etapas.
    """

    def __init__(self):
        self._repositorio = ProfessorRepository()

    def execute(self, professor_id, ano_letivo=None):
        ano_letivo = ano_letivo or date.today().year

        professor = Professor.find_by_id(professor_id)
        turmas = ProfessorTurma.turmas_do_professor(professor_id)
        total_alunos = sum(t.get("total_alunos") or 0 for t in turmas)

        em_risco = self._repositorio.alunos_em_risco(professor_id, ano_letivo)

        return {
            "nome": professor["nome"] if professor else "",
            "email": professor["email"] if professor else "",
            "totalTurmas": len(turmas),
            "totalAlunos": total_alunos,
            "alunosEmRisco": [
                {
                    "id": linha["id"],
                    "nome": linha["nome"],
                    "turma": linha["turma"],
                    "media": linha["media"],
                    "notaMinima": linha.get("nota_minima"),
                }
                for linha in em_risco
            ],
        }

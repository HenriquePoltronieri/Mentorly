from models.professor_turma_model import ProfessorTurma
from models.turma_model import Turma
from models.professor_model import Professor


class ListarProfessoresService:
    """Professores da escola de quem esta logado.

    Devolve tambem a lista "turmas" de cada professor: a tela de vinculo
    (listaTurmasProfessorScreen) usa ela para mostrar quantas turmas o
    professor ja tem e para deixar os checkboxes pre-marcados.
    """

    def execute(self, coordenacao_id):
        linhas = Professor.find_all_by_coordenacao(coordenacao_id)

        professores = []
        for linha in linhas:
            turmas = ProfessorTurma.turmas_do_professor(linha["id"])
            professor = Professor.to_dict(linha)
            professor["totalTurmas"] = len(turmas)
            professor["turmas"] = [Turma.to_dict(t) for t in turmas]
            professores.append(professor)
        return professores

from models.professor_model import Professor
from models.professor_turma_model import ProfessorTurma
from models.turma_model import Turma


class VincularTurmasService:
    """Define quais turmas um professor leciona.

    Valida que o professor E todas as turmas sao da escola de quem chamou.
    A FK composta de professor_turma ja recusaria no banco, mas validar aqui
    devolve uma mensagem util em vez de um erro de integridade.

    Um professor pode ser vinculado a varias turmas.
    """

    def execute(self, coordenacao_id, professor_id, turma_ids):
        professor = Professor.find_by_id(professor_id, coordenacao_id)
        if not professor:
            raise LookupError("Professor nao encontrado")

        if turma_ids is None:
            raise ValueError("Informe as turmas")

        ids_limpos = []
        for turma_id in turma_ids:
            try:
                turma_id = int(turma_id)
            except (TypeError, ValueError):
                raise ValueError("Lista de turmas invalida")
            if not Turma.find_by_id(turma_id, coordenacao_id):
                raise LookupError("Turma %s nao pertence a esta escola" % turma_id)
            ids_limpos.append(turma_id)

        ProfessorTurma.definir_turmas(coordenacao_id, professor_id, ids_limpos)

        vinculadas = ProfessorTurma.turmas_do_professor(professor_id)
        return {
            "professorId": professor_id,
            "vinculadas": len(ids_limpos),
            "turmas": [Turma.to_dict(linha) for linha in vinculadas],
        }


class ListarTurmasDoProfessorService:
    """Turmas ja vinculadas a um professor (visao da Coordenacao)."""

    def execute(self, coordenacao_id, professor_id):
        if not Professor.find_by_id(professor_id, coordenacao_id):
            raise LookupError("Professor nao encontrado")
        linhas = ProfessorTurma.turmas_do_professor(professor_id)
        return [Turma.to_dict(linha) for linha in linhas]

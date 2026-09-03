from models.professor_turma_model import ProfessorTurma
from models.turma_model import Turma
from repositories.professor_repository import ProfessorRepository


class ListarProfessoresService:
    """Professores da escola de quem esta logado.

    Usa a procedure sp_professores_por_coordenacao, que ja filtra por
    coordenacao_id e traz a contagem de turmas de cada professor.

    Devolve tambem a lista "turmas" de cada professor: a tela de vinculo
    (listaTurmasProfessorScreen) usa ela para mostrar quantas turmas o
    professor ja tem e para deixar os checkboxes pre-marcados.
    """

    def __init__(self):
        self._repositorio = ProfessorRepository()

    def execute(self, coordenacao_id):
        linhas = self._repositorio.professores_por_coordenacao(coordenacao_id)

        professores = []
        for linha in linhas:
            turmas = ProfessorTurma.turmas_do_professor(linha["id"])
            professores.append({
                "id": linha["id"],
                "nome": linha["nome"],
                "email": linha["email"],
                "disciplina": linha.get("disciplina"),
                "tipo": "professor",
                "ativo": bool(linha.get("ativo")),
                "totalTurmas": linha.get("total_turmas", 0),
                "turmas": [Turma.to_dict(t) for t in turmas],
            })
        return professores

"""Regra unica de quem pode mexer nos alunos de uma turma.

Os dois papeis chegam nos alunos, mas por caminhos diferentes:
  - Coordenacao: qualquer turma da escola dela;
  - Professor: so as turmas que a Coordenacao vinculou a ele.

Concentrar isso aqui evita a checagem ser escrita de novo (e esquecida)
em cada endpoint de aluno.
"""

from models.professor_turma_model import ProfessorTurma
from models.turma_model import Turma


def turma_acessivel(turma_id, coordenacao_id, professor_id=None):
    """Devolve a turma se o usuario pode acessa-la, senao levanta LookupError.

    Sempre LookupError (-> 404), nunca 403: negar a existencia da turma nao
    revela ids de outra escola.
    """
    if professor_id is not None:
        turma = Turma.find_by_id_para_professor(turma_id, professor_id)
        if not turma:
            raise LookupError("Turma nao encontrada")
        return turma

    turma = Turma.find_by_id(turma_id, coordenacao_id)
    if not turma:
        raise LookupError("Turma nao encontrada")
    return turma


def aluno_acessivel(aluno_id, coordenacao_id, professor_id=None):
    """Mesma ideia, partindo do aluno: valida a turma dele."""
    from models.aluno_model import Aluno

    aluno = Aluno.find_com_turma(aluno_id)
    if not aluno:
        raise LookupError("Aluno nao encontrado")

    if aluno["coordenacao_id"] != coordenacao_id:
        raise LookupError("Aluno nao encontrado")

    if professor_id is not None and not ProfessorTurma.professor_leciona_na_turma(
        professor_id, aluno["turma_id"]
    ):
        raise LookupError("Aluno nao encontrado")

    return aluno

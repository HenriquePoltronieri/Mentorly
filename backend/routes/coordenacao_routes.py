from flask import Blueprint

from auth.decorators import coordenacao_required
from controllers.coordenacao_controller import CoordenacaoController

coordenacao_blueprint = Blueprint(
    "coordenacao", __name__, url_prefix="/api/coordenacao"
)
coordenacao_controller = CoordenacaoController()


# Toda rota aqui e exclusiva da Coordenacao.

@coordenacao_blueprint.get("/professores")
@coordenacao_required
def listar_professores():
    return coordenacao_controller.listar_professores()


@coordenacao_blueprint.post("/professores")
@coordenacao_required
def cadastrar_professor():
    return coordenacao_controller.cadastrar_professor()


@coordenacao_blueprint.get("/professores/<int:professor_id>/turmas")
@coordenacao_required
def listar_turmas_do_professor(professor_id):
    return coordenacao_controller.listar_turmas_do_professor(professor_id)


@coordenacao_blueprint.post("/professores/<int:professor_id>/turmas")
@coordenacao_required
def vincular_turmas(professor_id):
    return coordenacao_controller.vincular_turmas(professor_id)


@coordenacao_blueprint.get("/turmas/<int:turma_id>/alunos")
@coordenacao_required
def listar_alunos(turma_id):
    return coordenacao_controller.listar_alunos(turma_id)


@coordenacao_blueprint.post("/turmas/<int:turma_id>/alunos")
@coordenacao_required
def cadastrar_aluno(turma_id):
    return coordenacao_controller.cadastrar_aluno(turma_id)


@coordenacao_blueprint.get("/turmas/<int:turma_id>/alunos/modelo-planilha")
@coordenacao_required
def modelo_planilha_alunos(turma_id):
    return coordenacao_controller.modelo_planilha_alunos(turma_id)


@coordenacao_blueprint.post("/turmas/<int:turma_id>/alunos/importar")
@coordenacao_required
def importar_alunos(turma_id):
    return coordenacao_controller.importar_alunos(turma_id)

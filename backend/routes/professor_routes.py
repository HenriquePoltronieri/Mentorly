from flask import Blueprint

from auth.decorators import professor_required
from controllers.professor_controller import ProfessorController

professor_blueprint = Blueprint(
    "professor", __name__, url_prefix="/api/professor"
)
# As rotas de nota/atividade nao ficam sob /api/professor porque o app ja
# as chama em /api/atividades/<id>/notas...
atividade_notas_blueprint = Blueprint(
    "atividade_notas", __name__, url_prefix="/api/atividades"
)

professor_controller = ProfessorController()


# ---------------------------------------------------------------------
# /api/professor - tudo exclusivo do Professor
# ---------------------------------------------------------------------

@professor_blueprint.get("/turmas")
@professor_required
def listar_turmas():
    return professor_controller.listar_turmas()


@professor_blueprint.get("/turmas/<int:turma_id>/alunos")
@professor_required
def listar_alunos(turma_id):
    return professor_controller.listar_alunos(turma_id)


@professor_blueprint.post("/turmas/<int:turma_id>/alunos")
@professor_required
def cadastrar_aluno(turma_id):
    return professor_controller.cadastrar_aluno(turma_id)


@professor_blueprint.get("/turmas/<int:turma_id>/alunos/modelo-planilha")
@professor_required
def modelo_planilha_alunos(turma_id):
    return professor_controller.modelo_planilha_alunos(turma_id)


@professor_blueprint.post("/turmas/<int:turma_id>/alunos/importar")
@professor_required
def importar_alunos(turma_id):
    return professor_controller.importar_alunos(turma_id)


@professor_blueprint.get("/dashboard")
@professor_required
def dashboard():
    return professor_controller.dashboard()


@professor_blueprint.get("/alunos/<int:aluno_id>/estatisticas")
@professor_required
def estatisticas_aluno(aluno_id):
    return professor_controller.estatisticas_aluno(aluno_id)


# ---------------------------------------------------------------------
# /api/atividades/<id>/notas - lancamento de notas
# Conteudo pedagogico: a Coordenacao recebe 403 aqui.
# ---------------------------------------------------------------------

@atividade_notas_blueprint.get("/<int:atividade_id>/notas")
@professor_required
def listar_notas(atividade_id):
    return professor_controller.listar_notas(atividade_id)


@atividade_notas_blueprint.post("/<int:atividade_id>/notas")
@professor_required
def lancar_notas(atividade_id):
    return professor_controller.lancar_notas(atividade_id)


@atividade_notas_blueprint.get("/<int:atividade_id>/notas/modelo-planilha")
@professor_required
def modelo_planilha_notas(atividade_id):
    return professor_controller.modelo_planilha_notas(atividade_id)


@atividade_notas_blueprint.post("/<int:atividade_id>/notas/importar")
@professor_required
def importar_notas(atividade_id):
    return professor_controller.importar_notas(atividade_id)

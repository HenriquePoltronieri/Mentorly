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


@coordenacao_blueprint.put("/professores/<int:professor_id>")
@coordenacao_required
def editar_professor(professor_id):
    return coordenacao_controller.editar_professor(professor_id)


@coordenacao_blueprint.post("/professores/<int:professor_id>/desativar")
@coordenacao_required
def desativar_professor(professor_id):
    return coordenacao_controller.desativar_professor(professor_id)


@coordenacao_blueprint.post("/professores/<int:professor_id>/reativar")
@coordenacao_required
def reativar_professor(professor_id):
    return coordenacao_controller.reativar_professor(professor_id)


@coordenacao_blueprint.post("/professores/<int:professor_id>/reenviar-convite")
@coordenacao_required
def reenviar_convite_professor(professor_id):
    return coordenacao_controller.reenviar_convite_professor(professor_id)


@coordenacao_blueprint.get("/professores/<int:professor_id>/turmas")
@coordenacao_required
def listar_turmas_do_professor(professor_id):
    return coordenacao_controller.listar_turmas_do_professor(professor_id)


@coordenacao_blueprint.post("/professores/<int:professor_id>/turmas")
@coordenacao_required
def vincular_turmas(professor_id):
    return coordenacao_controller.vincular_turmas(professor_id)


@coordenacao_blueprint.delete("/professores/<int:professor_id>/turmas/<int:turma_id>")
@coordenacao_required
def desvincular_turma(professor_id, turma_id):
    return coordenacao_controller.desvincular_turma(professor_id, turma_id)


@coordenacao_blueprint.get("/turmas/<int:turma_id>/alunos")
@coordenacao_required
def listar_alunos(turma_id):
    return coordenacao_controller.listar_alunos(turma_id)


@coordenacao_blueprint.post("/turmas/<int:turma_id>/alunos")
@coordenacao_required
def cadastrar_aluno(turma_id):
    return coordenacao_controller.cadastrar_aluno(turma_id)


@coordenacao_blueprint.put("/alunos/<int:aluno_id>")
@coordenacao_required
def atualizar_aluno(aluno_id):
    return coordenacao_controller.atualizar_aluno(aluno_id)


@coordenacao_blueprint.delete("/alunos/<int:aluno_id>")
@coordenacao_required
def excluir_aluno(aluno_id):
    return coordenacao_controller.excluir_aluno(aluno_id)


@coordenacao_blueprint.post("/alunos/<int:aluno_id>/transferir")
@coordenacao_required
def transferir_aluno(aluno_id):
    return coordenacao_controller.transferir_aluno(aluno_id)


@coordenacao_blueprint.get("/alunos/<int:aluno_id>/historico")
@coordenacao_required
def historico_aluno(aluno_id):
    return coordenacao_controller.historico_aluno(aluno_id)


@coordenacao_blueprint.get("/turmas/<int:turma_id>/alunos/modelo-planilha")
@coordenacao_required
def modelo_planilha_alunos(turma_id):
    return coordenacao_controller.modelo_planilha_alunos(turma_id)


@coordenacao_blueprint.post("/turmas/<int:turma_id>/alunos/importar")
@coordenacao_required
def importar_alunos(turma_id):
    return coordenacao_controller.importar_alunos(turma_id)


@coordenacao_blueprint.get("/turmas/<int:turma_id>/boletim")
@coordenacao_required
def boletim_turma(turma_id):
    return coordenacao_controller.boletim_turma(turma_id)

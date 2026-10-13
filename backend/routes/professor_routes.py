from flask import Blueprint, jsonify, request

from auth.decorators import professor_required, token_na_url_so_neste_download, usuario_atual_id, coordenacao_atual
from services.professor.estatisticas_turma import EstatisticasTurmaService
from erros import RecursoNaoEncontrado
from services.entrada import inteiro
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
    return jsonify({"error": "Somente a Coordenação gerencia os alunos da turma."}), 403


@professor_blueprint.get("/turmas/<int:turma_id>/alunos/modelo-planilha")
@professor_required
@token_na_url_so_neste_download
def modelo_planilha_alunos(turma_id):
    return jsonify({"error": "Somente a Coordenação gerencia os alunos da turma."}), 403


@professor_blueprint.post("/turmas/<int:turma_id>/alunos/importar")
@professor_required
def importar_alunos(turma_id):
    return jsonify({"error": "Somente a Coordenação gerencia os alunos da turma."}), 403


@professor_blueprint.get("/dashboard")
@professor_required
def dashboard():
    return professor_controller.dashboard()


@professor_blueprint.get("/alunos/<int:aluno_id>/estatisticas")
@professor_required
def estatisticas_aluno(aluno_id):
    return professor_controller.estatisticas_aluno(aluno_id)


@professor_blueprint.put("/alunos/<int:aluno_id>")
@professor_required
def atualizar_aluno(aluno_id):
    return jsonify({"error": "Somente a Coordenação gerencia os alunos da turma."}), 403


@professor_blueprint.delete("/alunos/<int:aluno_id>")
@professor_required
def excluir_aluno(aluno_id):
    return jsonify({"error": "Somente a Coordenação gerencia os alunos da turma."}), 403


@professor_blueprint.get("/turmas/<int:turma_id>/boletim")
@professor_required
def boletim_turma(turma_id):
    return professor_controller.boletim_turma(turma_id)


@professor_blueprint.post("/turmas/<int:turma_id>/insights")
@professor_required
def insights_turma(turma_id):
    return professor_controller.insights_turma(turma_id)


# Sugestao de atividade por IA: so devolve texto para o Professor revisar. A
# atividade e criada depois, pelo POST /api/activities normal.
@professor_blueprint.post("/turmas/<int:turma_id>/atividades/gerar")
@professor_required
def gerar_atividade(turma_id):
    return professor_controller.gerar_atividade(turma_id)


# Feedback e plano de recuperacao por IA: so leitura. Nada e gravado e nenhum
# dado do aluno vai para o provedor.
@professor_blueprint.post("/alunos/<int:aluno_id>/feedback-ia")
@professor_required
def feedback_aluno(aluno_id):
    return professor_controller.feedback_aluno(aluno_id)


# Correcao assistida por IA: so devolve uma sugestao de avaliacao. A nota e
# lancada depois, pelo POST /api/atividades/<id>/notas normal.
@professor_blueprint.post("/atividades/<int:atividade_id>/correcao-assistida")
@professor_required
def corrigir_resposta(atividade_id):
    return professor_controller.corrigir_resposta(atividade_id)


@professor_blueprint.delete("/notas/<int:nota_id>")
@professor_required
def excluir_nota(nota_id):
    return professor_controller.excluir_nota(nota_id)


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
@token_na_url_so_neste_download
def modelo_planilha_notas(atividade_id):
    return professor_controller.modelo_planilha_notas(atividade_id)


@atividade_notas_blueprint.post("/<int:atividade_id>/notas/importar")
@professor_required
def importar_notas(atividade_id):
    return professor_controller.importar_notas(atividade_id)


def _estatisticas(turma_id, aluno_id=None):
    try:
        etapa = request.args.get("etapa_id")
        etapa = inteiro(etapa, "Etapa") if etapa is not None else None
        return jsonify(EstatisticasTurmaService().execute(usuario_atual_id(), coordenacao_atual(), turma_id, etapa, aluno_id))
    except RecursoNaoEncontrado as erro:
        return jsonify({"error": str(erro)}), 404
    except ValueError as erro:
        return jsonify({"error": str(erro)}), 400


@professor_blueprint.get("/turmas/<int:turma_id>/estatisticas")
@professor_required
def estatisticas_turma(turma_id):
    return _estatisticas(turma_id)


@professor_blueprint.get("/turmas/<int:turma_id>/alunos/<int:aluno_id>/estatisticas")
@professor_required
def estatisticas_aluno_turma(turma_id, aluno_id):
    return _estatisticas(turma_id, aluno_id)


@professor_blueprint.post("/ia/chat")
@professor_required
def chat_professor():
    from services.ia.chat_professor import ChatProfessorService
    from services.ia.client import AIError
    try:
        return jsonify(ChatProfessorService().execute(usuario_atual_id(), coordenacao_atual(), request.get_json(silent=True) or {}))
    except AIError:
        return jsonify({"error": "Não foi possível consultar a IA agora. Tente novamente em instantes."}), 503
    except RecursoNaoEncontrado as erro:
        return jsonify({"error": str(erro)}), 404
    except ValueError as erro:
        return jsonify({"error": str(erro)}), 400

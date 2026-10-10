"""Controller do Professor.

Tudo aqui e escopado pelo vinculo professor_turma: o professor so alcanca
as turmas que a Coordenacao vinculou a ele. O id do professor vem do token
(usuario_atual_id), nunca da URL.
"""

from flask import Response, jsonify, request

from auth.decorators import coordenacao_atual, usuario_atual_id
from models.turma_model import Turma
from services.academico.boletim import montar_boletim_turma
from services.aluno.cadastrar_aluno import CadastrarAlunoService
from services.aluno.gerenciar_aluno import AtualizarAlunoService, ExcluirAlunoService
from services.planilha.importar_alunos import ImportarAlunosService
from services.planilha.importar_notas import ImportarNotasService
from services.planilha.leitor import PlanilhaInvalida
from services.planilha.modelo import modelo_alunos, modelo_notas
from services.professor.dashboard import DashboardProfessorService
from services.professor.estatisticas_aluno import EstatisticasAlunoService
from services.professor.listar_turmas import (
    ListarAlunosDaTurmaService,
    ListarTurmasDoProfessorService,
)
from services.professor.notas import (
    ExcluirNotaService,
    LancarNotasService,
    ListarNotasService,
)
from services.ia.client import AIError
from services.rate_limit import limitar_ia
from services.ia.corrigir_resposta import CorrigirRespostaIaService
from services.ia.gerar_atividade import GerarAtividadeIaService
from services.ia.gerar_feedback import GerarFeedbackIaService
from services.ia.gerar_insights_turma import (
    DadosInsuficientesError,
    GerarInsightsTurmaService,
)

MENSAGEM_FEEDBACK_INDISPONIVEL = (
    "Nao foi possivel gerar o feedback agora. Tente novamente em instantes. "
    "O desempenho do aluno continua disponivel normalmente."
)
MENSAGEM_CORRECAO_INDISPONIVEL = (
    "Nao foi possivel analisar a resposta agora. Tente novamente em instantes "
    "ou lance a nota manualmente."
)
MENSAGEM_ATIVIDADE_INDISPONIVEL = (
    "Nao foi possivel gerar a atividade agora. Tente novamente em instantes "
    "ou crie a atividade manualmente."
)

XLSX_MIME = (
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
)


def _xlsx(buffer, nome_arquivo):
    return Response(
        buffer.read(),
        mimetype=XLSX_MIME,
        headers={
            "Content-Disposition": 'attachment; filename="%s"' % nome_arquivo
        },
    )


class ProfessorController:
    # -----------------------------------------------------------------
    # Turmas e alunos
    # -----------------------------------------------------------------
    def listar_turmas(self):
        return jsonify(
            ListarTurmasDoProfessorService().execute(usuario_atual_id())
        )

    def listar_alunos(self, turma_id):
        try:
            alunos = ListarAlunosDaTurmaService().execute(
                turma_id, usuario_atual_id()
            )
        except LookupError as erro:
            return jsonify({"error": str(erro)}), 404
        return jsonify(alunos)

    def cadastrar_aluno(self, turma_id):
        dados = request.get_json(silent=True) or {}
        try:
            aluno = CadastrarAlunoService().execute(
                turma_id,
                coordenacao_atual(),
                dados.get("nome"),
                dados.get("matricula"),
                dados.get("email"),
                professor_id=usuario_atual_id(),
            )
        except LookupError as erro:
            return jsonify({"error": str(erro)}), 404
        except ValueError as erro:
            return jsonify({"error": str(erro)}), 400
        return jsonify(aluno), 201

    def atualizar_aluno(self, aluno_id):
        dados = request.get_json(silent=True) or {}
        try:
            aluno = AtualizarAlunoService().execute(
                aluno_id,
                coordenacao_atual(),
                dados.get("nome"),
                dados.get("matricula"),
                dados.get("email"),
                professor_id=usuario_atual_id(),
            )
        except LookupError as erro:
            return jsonify({"error": str(erro)}), 404
        except ValueError as erro:
            return jsonify({"error": str(erro)}), 400
        return jsonify(aluno)

    def excluir_aluno(self, aluno_id):
        try:
            ExcluirAlunoService().execute(
                aluno_id, coordenacao_atual(), professor_id=usuario_atual_id()
            )
        except LookupError as erro:
            return jsonify({"error": str(erro)}), 404
        except ValueError as erro:
            return jsonify({"error": str(erro)}), 400
        return "", 204

    def modelo_planilha_alunos(self, turma_id):
        return _xlsx(modelo_alunos(), "modelo-alunos-turma-%d.xlsx" % turma_id)

    def importar_alunos(self, turma_id):
        arquivo = request.files.get("arquivo")
        if arquivo is None:
            return jsonify({"error": "Envie o arquivo no campo 'arquivo'"}), 400
        try:
            resultado = ImportarAlunosService().execute(
                turma_id,
                coordenacao_atual(),
                arquivo.filename,
                arquivo.read(),
                professor_id=usuario_atual_id(),
            )
        except LookupError as erro:
            return jsonify({"error": str(erro)}), 404
        except PlanilhaInvalida as erro:
            return jsonify({"error": str(erro)}), 400
        return jsonify(resultado), 201

    # -----------------------------------------------------------------
    # Dashboard e estatisticas
    # -----------------------------------------------------------------
    def dashboard(self):
        # Sem ?ano_letivo=, o contexto e o ano atual cadastrado pela escola.
        ano_letivo = request.args.get("ano_letivo", type=int)
        try:
            dados = DashboardProfessorService().execute(
                usuario_atual_id(), ano_letivo
            )
        except LookupError as erro:
            return jsonify({"error": str(erro)}), 404
        return jsonify(dados)

    def estatisticas_aluno(self, aluno_id):
        try:
            dados = EstatisticasAlunoService().execute(
                aluno_id, coordenacao_atual(), usuario_atual_id()
            )
        except LookupError as erro:
            return jsonify({"error": str(erro)}), 404
        return jsonify(dados)

    def boletim_turma(self, turma_id):
        turma = Turma.find_by_id_para_professor(turma_id, usuario_atual_id())
        if not turma:
            return jsonify({"error": "Turma nao encontrada"}), 404
        return jsonify(montar_boletim_turma(turma, coordenacao_atual()))

    def insights_turma(self, turma_id):
        limitar_ia(usuario_atual_id())
        try:
            dados = GerarInsightsTurmaService().execute(
                turma_id, usuario_atual_id(), coordenacao_atual()
            )
        except LookupError as erro:
            return jsonify({"error": str(erro)}), 404
        except DadosInsuficientesError as erro:
            return jsonify({"error": str(erro)}), 422
        except AIError as erro:
            return jsonify({"error": str(erro)}), 503
        return jsonify(dados)

    def gerar_atividade(self, turma_id):
        """Sugestao de atividade por IA. NAO grava nada: so devolve o texto."""
        limitar_ia(usuario_atual_id())
        try:
            dados = GerarAtividadeIaService().execute(
                turma_id, usuario_atual_id(), coordenacao_atual(),
                request.get_json(silent=True),
            )
        except LookupError as erro:
            return jsonify({"error": str(erro)}), 404
        except ValueError as erro:
            return jsonify({"error": str(erro)}), 400
        except AIError:
            return jsonify({"error": MENSAGEM_ATIVIDADE_INDISPONIVEL}), 503
        return jsonify(dados)

    def feedback_aluno(self, aluno_id):
        """Feedback e plano sugeridos por IA. So leitura: nada e gravado."""
        limitar_ia(usuario_atual_id())
        try:
            dados = GerarFeedbackIaService().execute(
                aluno_id, usuario_atual_id(), coordenacao_atual(),
                request.get_json(silent=True),
            )
        except LookupError as erro:
            return jsonify({"error": str(erro)}), 404
        except DadosInsuficientesError as erro:
            return jsonify({"error": str(erro)}), 422
        except ValueError as erro:
            return jsonify({"error": str(erro)}), 400
        except AIError:
            return jsonify({"error": MENSAGEM_FEEDBACK_INDISPONIVEL}), 503
        return jsonify(dados)

    def corrigir_resposta(self, atividade_id):
        """Sugestao de avaliacao por IA. NAO lanca nota: so devolve a sugestao."""
        limitar_ia(usuario_atual_id())
        try:
            dados = CorrigirRespostaIaService().execute(
                atividade_id, usuario_atual_id(), request.get_json(silent=True)
            )
        except LookupError as erro:
            return jsonify({"error": str(erro)}), 404
        except ValueError as erro:
            return jsonify({"error": str(erro)}), 400
        except AIError:
            return jsonify({"error": MENSAGEM_CORRECAO_INDISPONIVEL}), 503
        return jsonify(dados)

    # -----------------------------------------------------------------
    # Notas
    # -----------------------------------------------------------------
    def listar_notas(self, atividade_id):
        try:
            dados = ListarNotasService().execute(atividade_id, usuario_atual_id())
        except LookupError as erro:
            return jsonify({"error": str(erro)}), 404
        return jsonify(dados)

    def lancar_notas(self, atividade_id):
        dados = request.get_json(silent=True) or {}
        try:
            resultado = LancarNotasService().execute(
                atividade_id, usuario_atual_id(), dados
            )
        except LookupError as erro:
            return jsonify({"error": str(erro)}), 404
        except ValueError as erro:
            return jsonify({"error": str(erro)}), 400
        return jsonify(resultado), 201

    def excluir_nota(self, nota_id):
        try:
            ExcluirNotaService().execute(nota_id, usuario_atual_id())
        except LookupError as erro:
            return jsonify({"error": str(erro)}), 404
        except ValueError as erro:
            return jsonify({"error": str(erro)}), 400
        return "", 204

    def modelo_planilha_notas(self, atividade_id):
        """Modelo ja preenchido com os alunos da turma da atividade."""
        try:
            dados = ListarNotasService().execute(atividade_id, usuario_atual_id())
        except LookupError as erro:
            return jsonify({"error": str(erro)}), 404

        alunos = [
            {"matricula": n.get("matricula"), "nome": n.get("aluno")}
            for n in dados["notas"]
        ]
        return _xlsx(
            modelo_notas(alunos), "modelo-notas-atividade-%d.xlsx" % atividade_id
        )

    def importar_notas(self, atividade_id):
        arquivo = request.files.get("arquivo")
        if arquivo is None:
            return jsonify({"error": "Envie o arquivo no campo 'arquivo'"}), 400
        try:
            resultado = ImportarNotasService().execute(
                atividade_id, usuario_atual_id(), arquivo.filename, arquivo.read()
            )
        except LookupError as erro:
            return jsonify({"error": str(erro)}), 404
        except PlanilhaInvalida as erro:
            return jsonify({"error": str(erro)}), 400
        return jsonify(resultado), 201

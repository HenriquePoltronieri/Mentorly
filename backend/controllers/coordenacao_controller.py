"""Controller da Coordenacao: professores, vinculos e alunos das turmas.

Todas as rotas deste controller passam por @coordenacao_required, e o id
da escola vem de coordenacao_atual() (token). Nao ha nenhum endpoint aqui
que aceite a escola como parametro.
"""

from flask import Response, jsonify, request

from auth.decorators import coordenacao_atual
from services.entrada import EntradaInvalida
from models.turma_model import Turma
from services.academico.boletim import montar_boletim_turma
from services.aluno.cadastrar_aluno import CadastrarAlunoService
from services.aluno.gerenciar_aluno import AtualizarAlunoService, ExcluirAlunoService
from services.aluno.listar_alunos import ListarAlunosService
from services.aluno.transferir_aluno import HistoricoAlunoService, TransferirAlunoService
from services.coordenacao.cadastrar_professor import CadastrarProfessorService
from services.coordenacao.listar_professores import ListarProfessoresService
from services.coordenacao.gerenciar_professor import (
    DesativarProfessorService,
    EditarProfessorService,
    ReativarProfessorService,
    ReenviarConviteProfessorService,
)
from services.coordenacao.vincular_turmas import (
    DesvincularTurmaDoProfessorService,
    ListarTurmasDoProfessorService,
    VincularTurmasService,
)
from services.planilha.importar_alunos import ImportarAlunosService
from services.planilha.leitor import PlanilhaInvalida
from services.planilha.modelo import modelo_alunos


class CoordenacaoController:
    # -----------------------------------------------------------------
    # Professores
    # -----------------------------------------------------------------
    def listar_professores(self):
        return jsonify(ListarProfessoresService().execute(coordenacao_atual()))

    def cadastrar_professor(self):
        dados = request.get_json(silent=True) or {}
        try:
            professor = CadastrarProfessorService().execute(
                coordenacao_atual(),
                dados.get("nome"),
                dados.get("email"),
                dados.get("disciplina"),
            )
        except EntradaInvalida as erro:
            return jsonify({"error": str(erro)}), 400
        except ValueError as erro:
            return jsonify({"error": str(erro)}), 409
        return jsonify(professor), 201

    def editar_professor(self, professor_id):
        dados = request.get_json(silent=True) or {}
        try:
            professor = EditarProfessorService().execute(
                coordenacao_atual(), professor_id, dados.get("nome"),
                dados.get("email"), dados.get("disciplina"),
            )
        except LookupError as erro:
            return jsonify({"error": str(erro)}), 404
        except EntradaInvalida as erro:
            return jsonify({"error": str(erro)}), 400
        except ValueError as erro:
            return jsonify({"error": str(erro)}), 409
        return jsonify(professor)

    def desativar_professor(self, professor_id):
        try:
            professor = DesativarProfessorService().execute(
                coordenacao_atual(), professor_id
            )
        except LookupError as erro:
            return jsonify({"error": str(erro)}), 404
        return jsonify(professor)

    def reativar_professor(self, professor_id):
        try:
            professor = ReativarProfessorService().execute(
                coordenacao_atual(), professor_id
            )
        except LookupError as erro:
            return jsonify({"error": str(erro)}), 404
        return jsonify(professor)

    def reenviar_convite_professor(self, professor_id):
        try:
            professor = ReenviarConviteProfessorService().execute(
                coordenacao_atual(), professor_id
            )
        except LookupError as erro:
            return jsonify({"error": str(erro)}), 404
        except ValueError as erro:
            return jsonify({"error": str(erro)}), 400
        return jsonify(professor)

    # -----------------------------------------------------------------
    # Vinculo professor x turma
    # -----------------------------------------------------------------
    def listar_turmas_do_professor(self, professor_id):
        try:
            turmas = ListarTurmasDoProfessorService().execute(
                coordenacao_atual(), professor_id
            )
        except LookupError as erro:
            return jsonify({"error": str(erro)}), 404
        return jsonify(turmas)

    def vincular_turmas(self, professor_id):
        dados = request.get_json(silent=True) or {}
        try:
            resultado = VincularTurmasService().execute(
                coordenacao_atual(), professor_id, dados.get("turma_ids")
            )
        except LookupError as erro:
            return jsonify({"error": str(erro)}), 404
        except ValueError as erro:
            return jsonify({"error": str(erro)}), 400
        return jsonify(resultado), 201

    def desvincular_turma(self, professor_id, turma_id):
        try:
            DesvincularTurmaDoProfessorService().execute(
                coordenacao_atual(), professor_id, turma_id
            )
        except LookupError as erro:
            return jsonify({"error": str(erro)}), 404
        return "", 204

    # -----------------------------------------------------------------
    # Alunos das turmas
    # -----------------------------------------------------------------
    def listar_alunos(self, turma_id):
        try:
            alunos = ListarAlunosService().execute(turma_id, coordenacao_atual())
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
            )
        except LookupError as erro:
            return jsonify({"error": str(erro)}), 404
        except ValueError as erro:
            return jsonify({"error": str(erro)}), 400
        return jsonify(aluno)

    def excluir_aluno(self, aluno_id):
        try:
            ExcluirAlunoService().execute(aluno_id, coordenacao_atual())
        except LookupError as erro:
            return jsonify({"error": str(erro)}), 404
        except ValueError as erro:
            return jsonify({"error": str(erro)}), 400
        return "", 204

    def transferir_aluno(self, aluno_id):
        dados = request.get_json(silent=True) or {}
        try:
            aluno = TransferirAlunoService().execute(
                aluno_id, coordenacao_atual(),
                dados.get("turma_id", dados.get("turmaId")), dados.get("motivo"))
        except LookupError as erro:
            return jsonify({"error": str(erro)}), 404
        except ValueError as erro:
            return jsonify({"error": str(erro)}), 400
        return jsonify(aluno)

    def historico_aluno(self, aluno_id):
        try:
            historico = HistoricoAlunoService().execute(aluno_id, coordenacao_atual())
        except LookupError as erro:
            return jsonify({"error": str(erro)}), 404
        return jsonify(historico)

    def modelo_planilha_alunos(self, turma_id):
        return Response(
            modelo_alunos().read(),
            mimetype=(
                "application/vnd.openxmlformats-officedocument."
                "spreadsheetml.sheet"
            ),
            headers={
                "Content-Disposition":
                    'attachment; filename="modelo-alunos-turma-%d.xlsx"' % turma_id
            },
        )

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
            )
        except LookupError as erro:
            return jsonify({"error": str(erro)}), 404
        except PlanilhaInvalida as erro:
            return jsonify({"error": str(erro)}), 400
        return jsonify(resultado), 201

    # -----------------------------------------------------------------
    # Boletim academico (Marco 3)
    # -----------------------------------------------------------------
    def boletim_turma(self, turma_id):
        turma = Turma.find_by_id(turma_id, coordenacao_atual())
        if not turma:
            return jsonify({"error": "Turma nao encontrada"}), 404
        return jsonify(montar_boletim_turma(turma, coordenacao_atual()))

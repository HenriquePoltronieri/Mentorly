"""Controller do Professor.

Tudo aqui e escopado pelo vinculo professor_turma: o professor so alcanca
as turmas que a Coordenacao vinculou a ele. O id do professor vem do token
(usuario_atual_id), nunca da URL.
"""

from flask import Response, jsonify, request

from auth.decorators import coordenacao_atual, usuario_atual_id
from services.aluno.cadastrar_aluno import CadastrarAlunoService
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
from services.professor.notas import LancarNotasService, ListarNotasService

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
        ano_letivo = request.args.get("ano_letivo", type=int)
        return jsonify(
            DashboardProfessorService().execute(usuario_atual_id(), ano_letivo)
        )

    def estatisticas_aluno(self, aluno_id):
        try:
            dados = EstatisticasAlunoService().execute(
                aluno_id, coordenacao_atual(), usuario_atual_id()
            )
        except LookupError as erro:
            return jsonify({"error": str(erro)}), 404
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

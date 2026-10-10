"""Controller de turmas (/api/classes).

Regra de papel aplicada aqui:
  - Coordenacao cria, edita e exclui turma.
  - Professor so LE, e so as turmas que a Coordenacao vinculou a ele.

O id da escola sai sempre de coordenacao_atual() (o token), nunca do corpo
ou da query string da requisicao.
"""

from flask import jsonify, request

from auth.decorators import coordenacao_atual, eh_professor, usuario_atual_id
from models.professor_turma_model import ProfessorTurma
from models.turma_model import Turma
from repositories.consultas import relatorio_turmas_atividades
from services.config.anos_letivos import AnoEncerrado
from services.conflito import ConflitoDeIntegridade
from services.entrada import EntradaInvalida
from services.turmas import (
    atualizar_turma, buscar_turma, criar_turma, excluir_turma, listar_turmas,
)
from erros import RecursoNaoEncontrado


class ClassController:
    def list_classes(self):
        # O professor que bate em /api/classes recebe apenas as turmas dele.
        if eh_professor():
            linhas = ProfessorTurma.turmas_do_professor(usuario_atual_id())
            return jsonify([Turma.to_dict(linha) for linha in linhas])

        # ?ano_letivo=2026 filtra pelas turmas daquele ano.
        ano_letivo = request.args.get("ano_letivo", type=int)
        return jsonify(listar_turmas(coordenacao_atual(), ano_letivo))

    def relatorio_turmas_atividades(self):
        return jsonify(relatorio_turmas_atividades(coordenacao_atual()))

    def get_class(self, class_id):
        if eh_professor():
            linha = Turma.find_by_id_para_professor(class_id, usuario_atual_id())
            if not linha:
                return jsonify({"error": "Turma nao encontrada"}), 404
            return jsonify(Turma.to_dict(linha))

        turma = buscar_turma(class_id, coordenacao_atual())
        if turma is None:
            return jsonify({"error": "Turma nao encontrada"}), 404
        return jsonify(turma)

    def create_class(self):
        dados = request.get_json(silent=True) or {}
        # O frontend manda "name"/"description"; aceita tambem em portugues.
        nome = dados.get("name") or dados.get("nome")
        descricao = dados.get("description")
        if descricao is None:
            descricao = dados.get("descricao")

        if not nome:
            return jsonify({"error": "O nome da turma e obrigatorio"}), 400

        try:
            turma = criar_turma(
                coordenacao_atual(),
                nome,
                descricao,
                dados.get("disciplina"),
                dados.get("turno"),
                dados.get("ano_letivo") or dados.get("anoLetivo"),
            )
        except RecursoNaoEncontrado as erro:
            # Ano letivo que esta escola nao tem (inclusive o de outra escola).
            return jsonify({"error": str(erro)}), 404
        except EntradaInvalida as erro:
            return jsonify({"error": str(erro)}), 400
        except ValueError as erro:
            return jsonify({"error": str(erro)}), 409

        return jsonify(turma), 201

    def update_class(self, class_id):
        dados = request.get_json(silent=True) or {}
        nome = dados.get("name") or dados.get("nome")
        descricao = dados.get("description")
        if descricao is None:
            descricao = dados.get("descricao")

        try:
            turma = atualizar_turma(
                class_id,
                coordenacao_atual(),
                nome,
                descricao,
                dados.get("disciplina"),
                dados.get("turno"),
                dados.get("ano_letivo") or dados.get("anoLetivo"),
            )
        except RecursoNaoEncontrado as erro:
            return jsonify({"error": str(erro)}), 404
        except ValueError as erro:
            return jsonify({"error": str(erro)}), 400

        return jsonify(turma)

    def delete_class(self, class_id):
        try:
            excluir_turma(class_id, coordenacao_atual())
        except RecursoNaoEncontrado as erro:
            return jsonify({"error": str(erro)}), 404
        except AnoEncerrado as erro:
            return jsonify({"error": str(erro)}), 400
        except ConflitoDeIntegridade as erro:
            return jsonify({"error": str(erro)}), 409
        return "", 204

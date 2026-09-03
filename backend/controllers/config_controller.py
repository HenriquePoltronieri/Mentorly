"""Controller da configuracao do ano letivo (etapas e criterios).

Configurar o ano letivo e ato da Coordenacao: todas as rotas de escrita
usam @coordenacao_required. O que e salvo aqui vale como PADRAO DA ESCOLA
e e lido depois pelo dashboard do professor (nota minima) e pelas
atividades.
"""

from flask import jsonify, request

from auth.decorators import coordenacao_atual
from services.config.criterios import (
    AtualizarCriterioService,
    BuscarCriterioService,
    ExcluirCriterioService,
    ListarCriteriosService,
    SalvarCriterioService,
)
from services.config.etapas import (
    AtualizarEtapaService,
    BuscarEtapaService,
    DefinirNotasEtapaService,
    ExcluirEtapaService,
    ListarEtapasService,
    SalvarEtapaService,
)


class ConfigController:
    # -----------------------------------------------------------------
    # Etapas
    # -----------------------------------------------------------------
    def listar_etapas(self):
        ano_letivo = request.args.get("ano_letivo", type=int)
        return jsonify(
            ListarEtapasService().execute(coordenacao_atual(), ano_letivo)
        )

    def buscar_etapa(self, etapa_id):
        try:
            return jsonify(
                BuscarEtapaService().execute(etapa_id, coordenacao_atual())
            )
        except LookupError as erro:
            return jsonify({"error": str(erro)}), 404

    def salvar_etapa(self):
        dados = request.get_json(silent=True) or {}
        try:
            etapa = SalvarEtapaService().execute(
                coordenacao_atual(),
                dados.get("nome"),
                dados.get("ordem") or dados.get("numero"),
                dados.get("ano_letivo") or dados.get("anoLetivo"),
                dados.get("data_inicio") or dados.get("dataInicio"),
                dados.get("data_fim") or dados.get("dataFim"),
                dados.get("ativa", True),
            )
        except ValueError as erro:
            return jsonify({"error": str(erro)}), 400
        return jsonify(etapa), 201

    def atualizar_etapa(self, etapa_id):
        dados = request.get_json(silent=True) or {}
        try:
            etapa = AtualizarEtapaService().execute(
                etapa_id,
                coordenacao_atual(),
                dados.get("nome"),
                dados.get("ordem"),
                dados.get("data_inicio") or dados.get("dataInicio"),
                dados.get("data_fim") or dados.get("dataFim"),
                dados.get("ativa"),
            )
        except LookupError as erro:
            return jsonify({"error": str(erro)}), 404
        except ValueError as erro:
            return jsonify({"error": str(erro)}), 400
        return jsonify(etapa)

    def definir_notas(self, etapa_id):
        dados = request.get_json(silent=True) or {}
        try:
            etapa = DefinirNotasEtapaService().execute(
                etapa_id,
                coordenacao_atual(),
                dados.get("nota_minima", dados.get("notaMinima")),
                dados.get("nota_maxima", dados.get("notaMaxima")),
            )
        except LookupError as erro:
            return jsonify({"error": str(erro)}), 404
        except ValueError as erro:
            return jsonify({"error": str(erro)}), 400
        return jsonify(etapa)

    def excluir_etapa(self, etapa_id):
        try:
            ExcluirEtapaService().execute(etapa_id, coordenacao_atual())
        except LookupError as erro:
            return jsonify({"error": str(erro)}), 404
        return "", 204

    # -----------------------------------------------------------------
    # Criterios
    # -----------------------------------------------------------------
    def listar_criterios(self, etapa_id):
        try:
            return jsonify(
                ListarCriteriosService().execute(etapa_id, coordenacao_atual())
            )
        except LookupError as erro:
            return jsonify({"error": str(erro)}), 404

    def buscar_criterio(self, criterio_id):
        try:
            return jsonify(
                BuscarCriterioService().execute(criterio_id, coordenacao_atual())
            )
        except LookupError as erro:
            return jsonify({"error": str(erro)}), 404

    def salvar_criterio(self, etapa_id):
        dados = request.get_json(silent=True) or {}
        try:
            criterio = SalvarCriterioService().execute(
                etapa_id,
                coordenacao_atual(),
                dados.get("nome"),
                dados.get("peso"),
                dados.get("nota_maxima", dados.get("notaMaxima")),
            )
        except LookupError as erro:
            return jsonify({"error": str(erro)}), 404
        except ValueError as erro:
            return jsonify({"error": str(erro)}), 400
        return jsonify(criterio), 201

    def atualizar_criterio(self, criterio_id):
        dados = request.get_json(silent=True) or {}
        try:
            criterio = AtualizarCriterioService().execute(
                criterio_id,
                coordenacao_atual(),
                dados.get("nome"),
                dados.get("peso"),
                dados.get("nota_maxima", dados.get("notaMaxima")),
            )
        except LookupError as erro:
            return jsonify({"error": str(erro)}), 404
        except ValueError as erro:
            return jsonify({"error": str(erro)}), 400
        return jsonify(criterio)

    def excluir_criterio(self, criterio_id):
        try:
            ExcluirCriterioService().execute(criterio_id, coordenacao_atual())
        except LookupError as erro:
            return jsonify({"error": str(erro)}), 404
        return "", 204

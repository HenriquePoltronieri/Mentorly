from flask import jsonify

from auth.decorators import coordenacao_atual
from repositories.consultas import resumo_da_escola


class DashboardController:
    def resumo_sistema(self):
        return jsonify(resumo_da_escola(coordenacao_atual()))

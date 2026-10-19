from flask import jsonify

from auth.decorators import coordenacao_atual
from services.coordenacao.resumo_escola import ResumoEscolaService


class DashboardController:
    def resumo_sistema(self):
        # A Coordenação só recebe números administrativos, sem atividades/notas.
        return jsonify(ResumoEscolaService().execute(coordenacao_atual()))

from flask import jsonify

from auth.decorators import coordenacao_atual
from services.dashboard.get_system_summary import GetSystemSummaryService


class DashboardController:
    def resumo_sistema(self):
        return jsonify(GetSystemSummaryService().execute(coordenacao_atual()))

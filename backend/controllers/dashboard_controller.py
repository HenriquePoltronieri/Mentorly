from flask import jsonify

from services.dashboard.get_system_summary import GetSystemSummaryService


class DashboardController:
    def resumo_sistema(self):
        return jsonify(GetSystemSummaryService().execute())
from flask import jsonify

from services.dashboard_service import DashboardService


class DashboardController:
    def __init__(self):
        self.service = DashboardService()

    def resumo_sistema(self):
        return jsonify(self.service.resumo_sistema())
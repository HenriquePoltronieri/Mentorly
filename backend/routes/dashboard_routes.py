from flask import Blueprint

from controllers.dashboard_controller import DashboardController

dashboard_blueprint = Blueprint("dashboard", __name__, url_prefix="/api/dashboard")
dashboard_controller = DashboardController()


@dashboard_blueprint.get("/resumo")
def resumo_sistema():
    return dashboard_controller.resumo_sistema()
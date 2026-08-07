from repositories.report_repository import ReportRepository


class DashboardService:
    def __init__(self):
        self.repository = ReportRepository()

    def resumo_sistema(self):
        return self.repository.resumo_sistema()
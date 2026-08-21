from repositories.report_repository import ReportRepository


class GetSystemSummaryService:
    def __init__(self):
        self.repository = ReportRepository()

    def execute(self):
        return self.repository.resumo_sistema()
from repositories.turma_repository import TurmaRepository


class GetClassReportService:
    def __init__(self):
        self.repository = TurmaRepository()

    def execute(self):
        return self.repository.relatorio_turmas_atividades()
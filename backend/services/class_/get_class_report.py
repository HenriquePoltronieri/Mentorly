from repositories.class_repository import ClassRepository


class GetClassReportService:
    def __init__(self):
        self.repository = ClassRepository()

    def execute(self):
        return self.repository.relatorio_turmas_atividades()
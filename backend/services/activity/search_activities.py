from repositories.activity_repository import ActivityRepository


class SearchActivitiesService:
    def __init__(self):
        self.repository = ActivityRepository()

    def execute(self, termo=None, ordenar_por=None, direcao=None):
        return self.repository.buscar_atividades(termo, ordenar_por, direcao)
from repositories.activity_repository import ActivityRepository


class SearchActivitiesService:
    """Busca de atividades por termo (procedure sp_buscar_atividades).

    A procedure recebe coordenacao_id sempre, e professor_id quando quem
    busca e um professor - assim a busca nunca vaza atividade de outra
    escola nem de turma que nao e do professor.
    """

    def __init__(self):
        self._repositorio = ActivityRepository()

    def execute(self, coordenacao_id, professor_id=None, termo=None,
                ordenar_por=None, direcao=None):
        return self._repositorio.buscar_atividades(
            coordenacao_id, professor_id, termo, ordenar_por, direcao
        )

from repositories.report_repository import ReportRepository


class GetSystemSummaryService:
    """Resumo da ESCOLA de quem esta logado.

    Antes esta consulta somava o sistema inteiro (todas as coordenacoes).
    Agora recebe coordenacao_id e a procedure filtra por escola.
    """

    def __init__(self):
        self._repositorio = ReportRepository()

    def execute(self, coordenacao_id):
        return self._repositorio.resumo_da_escola(coordenacao_id)

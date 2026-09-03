from repositories.turma_repository import TurmaRepository


class GetClassReportService:
    """Relatorio de turmas com contagem de atividades (procedure).

    A procedure recebe a coordenacao_id, entao o relatorio de uma escola
    nunca soma atividades de outra.
    """

    def __init__(self):
        self._repositorio = TurmaRepository()

    def execute(self, coordenacao_id):
        return self._repositorio.relatorio_turmas_atividades(coordenacao_id)

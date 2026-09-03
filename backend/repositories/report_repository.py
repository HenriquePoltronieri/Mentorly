"""Consultas agregadas para o painel."""

from database.procedure import call_procedure
from models.utils import normalizar


class ReportRepository:
    def resumo_da_escola(self, coordenacao_id):
        """Totais da escola de quem esta logado, nao do sistema (procedure)."""
        linhas = call_procedure("sp_resumo_sistema", coordenacao_id)
        return normalizar(linhas[0]) if linhas else {}

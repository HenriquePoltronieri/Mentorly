from database.procedure import call_procedure


class ReportRepository:
    def resumo_sistema(self):
        """Resumo geral do sistema para o dashboard (procedure)."""
        rows = call_procedure("sp_resumo_sistema")
        return rows[0] if rows else {}
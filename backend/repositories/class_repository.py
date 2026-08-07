from database.procedure import call_procedure
from models.class_model import Class


class ClassRepository:
    def find_by_name(self, name):
        return Class.query.filter_by(name=name).first()

    def relatorio_turmas_atividades(self):
        """Relatório de turmas com contagem de atividades (procedure)."""
        return call_procedure("sp_relatorio_turmas_atividades")
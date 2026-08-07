from database.procedure import call_procedure
from models.activity_model import Activity


class ActivityRepository:
    def find_by_class_id(self, class_id):
        return Activity.query.filter_by(class_id=class_id).all()

    def buscar_atividades(self, termo=None, ordenar_por=None, direcao=None):
        """Busca de atividades por termo e ordenação (procedure)."""
        return call_procedure(
            "sp_buscar_atividades", termo, ordenar_por, direcao
        )
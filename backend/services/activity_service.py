from datetime import datetime

from models.activity_model import Activity
from models.class_model import Class
from repositories.activity_repository import ActivityRepository


class ActivityService:
    def __init__(self):
        self.repository = ActivityRepository()

    def list_activities(self, class_id=None):
        if class_id:
            return self.repository.find_by_class_id(class_id)
        return Activity.find_all()

    def get_activity(self, activity_id):
        return Activity.find_by_id(activity_id)

    def create_activity(self, title, class_id, description=None, due_date=None):
        if not title or not title.strip():
            raise ValueError("title is required")

        class_obj = Class.find_by_id(class_id)
        if class_obj is None:
            raise ValueError("Class not found")

        due_date = self._parse_due_date(due_date)
        return Activity.create(title.strip(), class_id, description, due_date)

    def update_activity(self, activity_id, title=None, description=None, class_id=None, due_date=None):
        activity = Activity.find_by_id(activity_id)
        if activity is None:
            raise ValueError("Activity not found")

        if class_id is not None:
            class_obj = Class.find_by_id(class_id)
            if class_obj is None:
                raise ValueError("Class not found")

        due_date = self._parse_due_date(due_date)
        return activity.update(title, description, class_id, due_date)

    def delete_activity(self, activity_id):
        activity = Activity.find_by_id(activity_id)
        if activity is None:
            raise ValueError("Activity not found")

        activity.delete()

    def buscar_atividades(self, termo=None, ordenar_por=None, direcao=None):
        """Busca de atividades com filtro e ordenação (procedure)."""
        return self.repository.buscar_atividades(termo, ordenar_por, direcao)

    def _parse_due_date(self, due_date):
        if isinstance(due_date, str) and due_date.strip():
            return datetime.fromisoformat(due_date)
        if isinstance(due_date, str):
            return None
        return due_date
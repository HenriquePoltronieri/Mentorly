from datetime import datetime

from models.activity_model import Activity
from models.class_model import Class


class CreateActivityService:
    def execute(self, title, class_id, description=None, due_date=None):
        if not title or not title.strip():
            raise ValueError("title is required")

        class_obj = Class.find_by_id(class_id)
        if class_obj is None:
            raise ValueError("Class not found")

        due_date = self._parse_due_date(due_date)
        return Activity.create(title.strip(), class_id, description, due_date)

    def _parse_due_date(self, due_date):
        if isinstance(due_date, str) and due_date.strip():
            return datetime.fromisoformat(due_date)
        if isinstance(due_date, str):
            return None
        return due_date
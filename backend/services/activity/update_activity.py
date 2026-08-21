from datetime import datetime

from models.activity_model import Activity
from models.class_model import Class


class UpdateActivityService:
    def execute(self, activity_id, title=None, description=None, class_id=None, due_date=None):
        activity = Activity.find_by_id(activity_id)
        if activity is None:
            raise ValueError("Activity not found")

        if class_id is not None:
            class_obj = Class.find_by_id(class_id)
            if class_obj is None:
                raise ValueError("Class not found")

        due_date = self._parse_due_date(due_date)
        return activity.update(title, description, class_id, due_date)

    def _parse_due_date(self, due_date):
        if isinstance(due_date, str) and due_date.strip():
            return datetime.fromisoformat(due_date)
        if isinstance(due_date, str):
            return None
        return due_date
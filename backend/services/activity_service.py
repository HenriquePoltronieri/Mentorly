from repositories.activity_repository import ActivityRepository
from repositories.class_repository import ClassRepository


class ActivityService:
    def __init__(self):
        self.repository = ActivityRepository()
        self.class_repository = ClassRepository()

    def list_activities(self, class_id=None):
        if class_id:
            return self.repository.find_by_class_id(class_id)
        return self.repository.find_all()

    def get_activity(self, activity_id):
        return self.repository.find_by_id(activity_id)

    def create_activity(self, title, class_id, description=None, due_date=None):
        if not title or not title.strip():
            raise ValueError("title is required")

        turma = self.class_repository.find_by_id(class_id)
        if turma is None:
            raise ValueError("Class not found")

        return self.repository.create(title.strip(), class_id, description, due_date)

    def update_activity(self, activity_id, title=None, description=None, class_id=None, due_date=None):
        activity = self.repository.find_by_id(activity_id)
        if activity is None:
            raise ValueError("Activity not found")

        if class_id is not None:
            turma = self.class_repository.find_by_id(class_id)
            if turma is None:
                raise ValueError("Class not found")

        return self.repository.update(activity_id, title, description, class_id, due_date)

    def delete_activity(self, activity_id):
        activity = self.repository.find_by_id(activity_id)
        if activity is None:
            raise ValueError("Activity not found")

        self.repository.delete(activity_id)

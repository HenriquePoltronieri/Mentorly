from repositories.activity_repository import ActivityRepository
from repositories.class_repository import ClassRepository


class UpdateActivityService:
    def __init__(self):
        self.repository = ActivityRepository()
        self.class_repository = ClassRepository()

    def execute(self, activity_id, title=None, description=None, class_id=None, due_date=None):
        activity = self.repository.find_by_id(activity_id)
        if activity is None:
            raise ValueError("Activity not found")

        if class_id is not None:
            turma = self.class_repository.find_by_id(class_id)
            if turma is None:
                raise ValueError("Class not found")

        return self.repository.update(activity_id, title, description, class_id, due_date)
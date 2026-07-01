from repositories.activity_repository import ActivityRepository
from repositories.class_repository import ClassRepository


class CreateActivityService:
    def __init__(self):
        self.repository = ActivityRepository()
        self.class_repository = ClassRepository()

    def execute(self, title, class_id, description=None, due_date=None):
        if not title or not title.strip():
            raise ValueError("title is required")

        turma = self.class_repository.find_by_id(class_id)
        if turma is None:
            raise ValueError("Class not found")

        return self.repository.create(title.strip(), class_id, description, due_date)
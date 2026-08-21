from models.class_model import Class
from repositories.turma_repository import TurmaRepository


class UpdateClassService:
    def __init__(self):
        self.repository = TurmaRepository()

    def execute(self, class_id, name=None, description=None):
        class_obj = Class.find_by_id(class_id)
        if class_obj is None:
            raise ValueError("Class not found")

        if name is not None:
            if not name.strip():
                raise ValueError("Name cannot be empty")
            if name != class_obj.name:
                if self.repository.find_by_name(name) is not None:
                    raise ValueError("A class with this name already exists")

        return class_obj.update(name, description)
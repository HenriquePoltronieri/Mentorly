from models.class_model import Class
from repositories.turma_repository import TurmaRepository


class CreateClassService:
    def __init__(self):
        self.repository = TurmaRepository()

    def execute(self, name, description=None):
        if not name or not name.strip():
            raise ValueError("name is required")

        if self.repository.find_by_name(name) is not None:
            raise ValueError("A class with this name already exists")

        return Class.create(name.strip(), description)
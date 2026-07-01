from repositories.class_repository import ClassRepository


class CreateClassService:
    def __init__(self):
        self.repository = ClassRepository()

    def execute(self, name, description=None):
        if not name or not name.strip():
            raise ValueError("name is required")

        if self.repository.find_by_name(name) is not None:
            raise ValueError("A class with this name already exists")

        return self.repository.create(name.strip(), description)
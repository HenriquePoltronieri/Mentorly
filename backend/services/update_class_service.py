from repositories.class_repository import ClassRepository


class UpdateClassService:
    def __init__(self):
        self.repository = ClassRepository()

    def execute(self, class_id, name=None, description=None):
        turma = self.repository.find_by_id(class_id)
        if turma is None:
            raise ValueError("Class not found")

        if name and name != turma.name:
            if self.repository.find_by_name(name) is not None:
                raise ValueError("A class with this name already exists")

        return self.repository.update(class_id, name, description)
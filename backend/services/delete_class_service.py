from repositories.class_repository import ClassRepository


class DeleteClassService:
    def __init__(self):
        self.repository = ClassRepository()

    def execute(self, class_id):
        turma = self.repository.find_by_id(class_id)
        if turma is None:
            raise ValueError("Class not found")

        self.repository.delete(class_id)
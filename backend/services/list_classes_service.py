from repositories.class_repository import ClassRepository


class ListClassesService:
    def __init__(self):
        self.repository = ClassRepository()

    def execute(self):
        return self.repository.find_all()
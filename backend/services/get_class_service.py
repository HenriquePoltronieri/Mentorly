from repositories.class_repository import ClassRepository


class GetClassService:
    def __init__(self):
        self.repository = ClassRepository()

    def execute(self, class_id):
        return self.repository.find_by_id(class_id)
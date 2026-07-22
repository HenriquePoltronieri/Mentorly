from repositories.class_repository import ClassRepository


class ClassService:
    def __init__(self):
        self.repository = ClassRepository()

    def list_classes(self):
        return self.repository.find_all()

    def get_class(self, class_id):
        return self.repository.find_by_id(class_id)

    def create_class(self, name, description=None):
        if not name or not name.strip():
            raise ValueError("name is required")

        if self.repository.find_by_name(name) is not None:
            raise ValueError("A class with this name already exists")

        return self.repository.create(name.strip(), description)

    def update_class(self, class_id, name=None, description=None):
        turma = self.repository.find_by_id(class_id)
        if turma is None:
            raise ValueError("Class not found")

        if name is not None:
            if not name.strip():
                raise ValueError("Name cannot be empty")
            if name != turma.name:
                if self.repository.find_by_name(name) is not None:
                    raise ValueError("A class with this name already exists")

        return self.repository.update(class_id, name, description)

    def delete_class(self, class_id):
        turma = self.repository.find_by_id(class_id)
        if turma is None:
            raise ValueError("Class not found")

        self.repository.delete(class_id)

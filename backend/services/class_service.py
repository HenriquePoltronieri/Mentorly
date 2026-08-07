from models.class_model import Class
from repositories.class_repository import ClassRepository


class ClassService:
    def __init__(self):
        self.repository = ClassRepository()

    def list_classes(self):
        return Class.find_all()

    def get_class(self, class_id):
        return Class.find_by_id(class_id)

    def create_class(self, name, description=None):
        if not name or not name.strip():
            raise ValueError("name is required")

        if self.repository.find_by_name(name) is not None:
            raise ValueError("A class with this name already exists")

        return Class.create(name.strip(), description)

    def update_class(self, class_id, name=None, description=None):
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

    def delete_class(self, class_id):
        class_obj = Class.find_by_id(class_id)
        if class_obj is None:
            raise ValueError("Class not found")

        class_obj.delete()

    def relatorio_turmas_atividades(self):
        """Relatório de turmas com contagem de atividades (procedure)."""
        return self.repository.relatorio_turmas_atividades()
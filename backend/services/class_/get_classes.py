from models.class_model import Class


class GetClassesService:
    def execute(self):
        return Class.find_all()
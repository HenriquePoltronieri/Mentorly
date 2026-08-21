from models.class_model import Class


class GetClassService:
    def execute(self, class_id):
        return Class.find_by_id(class_id)
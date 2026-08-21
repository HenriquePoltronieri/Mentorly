from models.class_model import Class


class DeleteClassService:
    def execute(self, class_id):
        class_obj = Class.find_by_id(class_id)
        if class_obj is None:
            raise ValueError("Class not found")

        class_obj.delete()
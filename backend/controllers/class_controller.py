from flask import jsonify, request

from services.class_service import ClassService


class ClassController:
    def __init__(self):
        self.service = ClassService()

    def list_classes(self):
        classes = self.service.list_classes()
        return jsonify([class_obj.to_dict() for class_obj in classes])

    def relatorio_turmas_atividades(self):
        relatorio = self.service.relatorio_turmas_atividades()
        return jsonify(relatorio)

    def get_class(self, class_id):
        class_obj = self.service.get_class(class_id)
        if class_obj is None:
            return jsonify({"error": "Class not found"}), 404
        return jsonify(class_obj.to_dict())

    def create_class(self):
        data = request.get_json(silent=True) or {}
        name = data.get("name")
        description = data.get("description")

        if not name:
            return jsonify({"error": "name is required"}), 400

        try:
            class_obj = self.service.create_class(name, description)
        except ValueError as error:
            return jsonify({"error": str(error)}), 409

        return jsonify(class_obj.to_dict()), 201

    def update_class(self, class_id):
        data = request.get_json(silent=True) or {}
        name = data.get("name")
        description = data.get("description")

        if not name and description is None:
            return jsonify({"error": "At least one field must be provided"}), 400

        try:
            class_obj = self.service.update_class(class_id, name, description)
        except ValueError as error:
            return jsonify({"error": str(error)}), 400

        return jsonify(class_obj.to_dict())

    def delete_class(self, class_id):
        try:
            self.service.delete_class(class_id)
        except ValueError as error:
            return jsonify({"error": str(error)}), 404

        return "", 204
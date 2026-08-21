from flask import jsonify, request

from services.class_.create_class import CreateClassService
from services.class_.delete_class import DeleteClassService
from services.class_.get_class import GetClassService
from services.class_.get_class_report import GetClassReportService
from services.class_.get_classes import GetClassesService
from services.class_.update_class import UpdateClassService


class ClassController:
    def list_classes(self):
        classes = GetClassesService().execute()
        return jsonify([class_obj.to_dict() for class_obj in classes])

    def relatorio_turmas_atividades(self):
        relatorio = GetClassReportService().execute()
        return jsonify(relatorio)

    def get_class(self, class_id):
        class_obj = GetClassService().execute(class_id)
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
            class_obj = CreateClassService().execute(name, description)
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
            class_obj = UpdateClassService().execute(class_id, name, description)
        except ValueError as error:
            return jsonify({"error": str(error)}), 400

        return jsonify(class_obj.to_dict())

    def delete_class(self, class_id):
        try:
            DeleteClassService().execute(class_id)
        except ValueError as error:
            return jsonify({"error": str(error)}), 404

        return "", 204
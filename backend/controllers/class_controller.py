from flask import Blueprint, jsonify, request

from services.create_class_service import CreateClassService
from services.list_classes_service import ListClassesService
from services.get_class_service import GetClassService
from services.update_class_service import UpdateClassService
from services.delete_class_service import DeleteClassService

class_blueprint = Blueprint("classes", __name__, url_prefix="/classes")

list_classes_service = ListClassesService()
get_class_service = GetClassService()
create_class_service = CreateClassService()
update_class_service = UpdateClassService()
delete_class_service = DeleteClassService()


@class_blueprint.get("")
def list_classes():
    classes = list_classes_service.execute()
    return jsonify([c.to_dict() for c in classes])


@class_blueprint.get("/<int:class_id>")
def get_class(class_id):
    turma = get_class_service.execute(class_id)
    if turma is None:
        return jsonify({"error": "Class not found"}), 404
    return jsonify(turma.to_dict())


@class_blueprint.post("")
def create_class():
    data = request.get_json(silent=True) or {}
    name = data.get("name")
    description = data.get("description")

    if not name:
        return jsonify({"error": "name is required"}), 400

    try:
        turma = create_class_service.execute(name, description)
    except ValueError as error:
        return jsonify({"error": str(error)}), 409

    return jsonify(turma.to_dict()), 201


@class_blueprint.put("/<int:class_id>")
def update_class(class_id):
    data = request.get_json(silent=True) or {}
    name = data.get("name")
    description = data.get("description")

    if not name and description is None:
        return jsonify({"error": "At least one field must be provided"}), 400

    try:
        turma = update_class_service.execute(class_id, name, description)
    except ValueError as error:
        return jsonify({"error": str(error)}), 400

    return jsonify(turma.to_dict())


@class_blueprint.delete("/<int:class_id>")
def delete_class(class_id):
    try:
        delete_class_service.execute(class_id)
    except ValueError as error:
        return jsonify({"error": str(error)}), 404

    return "", 204
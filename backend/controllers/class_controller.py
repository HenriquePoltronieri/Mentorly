from flask import Blueprint, jsonify, request

from services.class_service import ClassService

class_blueprint = Blueprint("classes", __name__, url_prefix="/classes")
class_service = ClassService()


@class_blueprint.get("")
def list_classes():
    classes = class_service.list_classes()
    return jsonify([turma.to_dict() for turma in classes])


@class_blueprint.get("/<int:class_id>")
def get_class(class_id):
    turma = class_service.get_class(class_id)
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
        turma = class_service.create_class(name, description)
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
        turma = class_service.update_class(class_id, name, description)
    except ValueError as error:
        return jsonify({"error": str(error)}), 400

    return jsonify(turma.to_dict())


@class_blueprint.delete("/<int:class_id>")
def delete_class(class_id):
    try:
        class_service.delete_class(class_id)
    except ValueError as error:
        return jsonify({"error": str(error)}), 404

    return "", 204
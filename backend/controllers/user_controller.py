from flask import Blueprint, jsonify, request

from services.user_service import UserService

user_blueprint = Blueprint("users", __name__, url_prefix="/users")
user_service = UserService()


@user_blueprint.get("")
def list_users():
    users = user_service.list_users()
    return jsonify([user.to_dict() for user in users])


@user_blueprint.get("/<int:user_id>")
def get_user(user_id):
    user = user_service.get_user(user_id)
    if user is None:
        return jsonify({"error": "User not found"}), 404
    return jsonify(user.to_dict())


@user_blueprint.post("")
def create_user():
    data = request.get_json(silent=True) or {}
    name = data.get("name")
    email = data.get("email")
    password = data.get("password")
    role = data.get("role", "mentee")

    if not name or not email or not password:
        return jsonify({"error": "name, email and password are required"}), 400

    try:
        user = user_service.create_user(name, email, password, role)
    except ValueError as error:
        return jsonify({"error": str(error)}), 409

    return jsonify(user.to_dict()), 201


@user_blueprint.put("/<int:user_id>")
def update_user(user_id):
    data = request.get_json(silent=True) or {}
    name = data.get("name")
    email = data.get("email")
    password = data.get("password")
    role = data.get("role")

    if not any([name, email, password, role]):
        return jsonify({"error": "At least one field must be provided"}), 400

    try:
        user = user_service.update_user(user_id, name, email, password, role)
    except ValueError as error:
        return jsonify({"error": str(error)}), 400

    return jsonify(user.to_dict())


@user_blueprint.delete("/<int:user_id>")
def delete_user(user_id):
    try:
        user_service.delete_user(user_id)
    except ValueError as error:
        return jsonify({"error": str(error)}), 404

    return "", 204
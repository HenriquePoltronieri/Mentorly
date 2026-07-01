from flask import Blueprint, jsonify, request

from services.create_user_service import CreateUserService
from services.list_users_service import ListUsersService
from services.get_user_service import GetUserService
from services.update_user_service import UpdateUserService
from services.delete_user_service import DeleteUserService

user_blueprint = Blueprint("users", __name__, url_prefix="/users")

list_users_service = ListUsersService()
get_user_service = GetUserService()
create_user_service = CreateUserService()
update_user_service = UpdateUserService()
delete_user_service = DeleteUserService()


@user_blueprint.get("")
def list_users():
    users = list_users_service.execute()
    return jsonify([user.to_dict() for user in users])


@user_blueprint.get("/<int:user_id>")
def get_user(user_id):
    user = get_user_service.execute(user_id)
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
        user = create_user_service.execute(name, email, password, role)
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
        user = update_user_service.execute(user_id, name, email, password, role)
    except ValueError as error:
        return jsonify({"error": str(error)}), 404

    return jsonify(user.to_dict())


@user_blueprint.delete("/<int:user_id>")
def delete_user(user_id):
    try:
        delete_user_service.execute(user_id)
    except ValueError as error:
        return jsonify({"error": str(error)}), 404

    return "", 204
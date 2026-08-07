from flask import Blueprint

from controllers.user_controller import UserController

user_blueprint = Blueprint("users", __name__, url_prefix="/api/users")
user_controller = UserController()


@user_blueprint.get("")
def list_users():
    return user_controller.list_users()


@user_blueprint.get("/role/<string:role>")
def list_users_by_role(role):
    return user_controller.list_users_by_role(role)


@user_blueprint.get("/<int:user_id>")
def get_user(user_id):
    return user_controller.get_user(user_id)


@user_blueprint.post("")
def create_user():
    return user_controller.create_user()


@user_blueprint.put("/<int:user_id>")
def update_user(user_id):
    return user_controller.update_user(user_id)


@user_blueprint.delete("/<int:user_id>")
def delete_user(user_id):
    return user_controller.delete_user(user_id)
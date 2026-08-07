from flask import jsonify, request

from services.user_service import UserService


class UserController:
    def __init__(self):
        self.service = UserService()

    def list_users(self):
        users = self.service.list_users()
        return jsonify([user.to_dict() for user in users])

    def list_users_by_role(self, role):
        users = self.service.list_users_by_role(role)
        return jsonify(users)

    def get_user(self, user_id):
        user = self.service.get_user(user_id)
        if user is None:
            return jsonify({"error": "User not found"}), 404
        return jsonify(user.to_dict())

    def create_user(self):
        data = request.get_json(silent=True) or {}
        name = data.get("name")
        email = data.get("email")
        password = data.get("password")
        role = data.get("role", "mentee")

        if not name or not email or not password:
            return jsonify({"error": "name, email and password are required"}), 400

        try:
            user = self.service.create_user(name, email, password, role)
        except ValueError as error:
            return jsonify({"error": str(error)}), 409

        return jsonify(user.to_dict()), 201

    def update_user(self, user_id):
        data = request.get_json(silent=True) or {}
        name = data.get("name")
        email = data.get("email")
        password = data.get("password")
        role = data.get("role")

        if not any([name, email, password, role]):
            return jsonify({"error": "At least one field must be provided"}), 400

        try:
            user = self.service.update_user(user_id, name, email, password, role)
        except ValueError as error:
            return jsonify({"error": str(error)}), 400

        return jsonify(user.to_dict())

    def delete_user(self, user_id):
        try:
            self.service.delete_user(user_id)
        except ValueError as error:
            return jsonify({"error": str(error)}), 404

        return "", 204
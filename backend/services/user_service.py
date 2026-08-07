from werkzeug.security import generate_password_hash

from models.user_model import User
from repositories.user_repository import UserRepository


class UserService:
    def __init__(self):
        self.repository = UserRepository()

    def list_users(self):
        return User.find_all()

    def get_user(self, user_id):
        return User.find_by_id(user_id)

    def create_user(self, name, email, password, role="mentee"):
        if self.repository.find_by_email(email) is not None:
            raise ValueError("Email already registered")

        password_hash = generate_password_hash(password)
        return User.create(name, email, password_hash, role)

    def update_user(self, user_id, name=None, email=None, password=None, role=None):
        user = User.find_by_id(user_id)
        if user is None:
            raise ValueError("User not found")

        if email is not None:
            if not email.strip():
                raise ValueError("Email cannot be empty")
            if email != user.email:
                if self.repository.find_by_email(email) is not None:
                    raise ValueError("Email already registered")

        if name is not None and not name.strip():
            raise ValueError("Name cannot be empty")

        password_hash = None
        if password:
            password_hash = generate_password_hash(password)

        return user.update(name, email, password_hash, role)

    def delete_user(self, user_id):
        user = User.find_by_id(user_id)
        if user is None:
            raise ValueError("User not found")

        user.delete()

    def list_users_by_role(self, role):
        """Usuários filtrados por papel (procedure)."""
        return self.repository.usuarios_por_role(role)

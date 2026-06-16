from werkzeug.security import generate_password_hash

from repositories.user_repository import UserRepository


class UserService:
    def __init__(self):
        self.user_repository = UserRepository()

    def list_users(self):
        return self.user_repository.find_all()

    def get_user(self, user_id):
        return self.user_repository.find_by_id(user_id)

    def register_user(self, name, email, password, role="mentee"):
        if self.user_repository.find_by_email(email) is not None:
            raise ValueError("Email already registered")

        password_hash = generate_password_hash(password)
        return self.user_repository.create(name, email, password_hash, role)

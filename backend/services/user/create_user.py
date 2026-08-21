from werkzeug.security import generate_password_hash

from models.user_model import User
from repositories.user_repository import UserRepository


class CreateUserService:
    def __init__(self):
        self.repository = UserRepository()

    def execute(self, name, email, password, role="mentee"):
        if self.repository.find_by_email(email) is not None:
            raise ValueError("Email already registered")

        password_hash = generate_password_hash(password)
        return User.create(name, email, password_hash, role)
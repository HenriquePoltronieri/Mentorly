from werkzeug.security import generate_password_hash

from repositories.user_repository import UserRepository


class UpdateUserService:
    def __init__(self):
        self.repository = UserRepository()

    def execute(self, user_id, name=None, email=None, password=None, role=None):
        user = self.repository.find_by_id(user_id)
        if user is None:
            raise ValueError("User not found")

        if email and email != user.email:
            if self.repository.find_by_email(email) is not None:
                raise ValueError("Email already registered")

        password_hash = None
        if password:
            password_hash = generate_password_hash(password)

        return self.repository.update(user_id, name, email, password_hash, role)
from werkzeug.security import generate_password_hash

from repositories.user_repository import UserRepository


class UserService:
    def __init__(self):
        self.repository = UserRepository()

    def list_users(self):
        return self.repository.find_all()

    def get_user(self, user_id):
        return self.repository.find_by_id(user_id)

    def create_user(self, name, email, password, role="mentee"):
        if self.repository.find_by_email(email) is not None:
            raise ValueError("Email already registered")

        password_hash = generate_password_hash(password)
        return self.repository.create(name, email, password_hash, role)

    def update_user(self, user_id, name=None, email=None, password=None, role=None):
        user = self.repository.find_by_id(user_id)
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

        return self.repository.update(user_id, name, email, password_hash, role)

    def delete_user(self, user_id):
        user = self.repository.find_by_id(user_id)
        if user is None:
            raise ValueError("User not found")

        self.repository.delete(user_id)

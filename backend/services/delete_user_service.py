from repositories.user_repository import UserRepository


class DeleteUserService:
    def __init__(self):
        self.repository = UserRepository()

    def execute(self, user_id):
        user = self.repository.find_by_id(user_id)
        if user is None:
            raise ValueError("User not found")

        self.repository.delete(user_id)
from repositories.user_repository import UserRepository


class GetUserService:
    def __init__(self):
        self.repository = UserRepository()

    def execute(self, user_id):
        return self.repository.find_by_id(user_id)
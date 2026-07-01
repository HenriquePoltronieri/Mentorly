from repositories.user_repository import UserRepository


class ListUsersService:
    def __init__(self):
        self.repository = UserRepository()

    def execute(self):
        return self.repository.find_all()
from models.user_model import User


class GetUsersService:
    def execute(self):
        return User.find_all()
from models.user_model import User


class GetUserService:
    def execute(self, user_id):
        return User.find_by_id(user_id)
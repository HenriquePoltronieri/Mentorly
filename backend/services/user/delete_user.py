from models.user_model import User


class DeleteUserService:
    def execute(self, user_id):
        user = User.find_by_id(user_id)
        if user is None:
            raise ValueError("User not found")

        user.delete()
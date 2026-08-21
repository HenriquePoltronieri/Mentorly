from repositories.user_repository import UserRepository


class GetUsersByRoleService:
    def __init__(self):
        self.repository = UserRepository()

    def execute(self, role):
        return self.repository.usuarios_por_role(role)
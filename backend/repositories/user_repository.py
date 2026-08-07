from database.procedure import call_procedure
from models.user_model import User


class UserRepository:
    def find_by_email(self, email):
        return User.query.filter_by(email=email).first()

    def usuarios_por_role(self, role):
        """Usuários filtrados por papel, ordenados por nome (procedure)."""
        return call_procedure("sp_usuarios_por_role", role)
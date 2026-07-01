from database import db
from models.user import User


class UserRepository:
    def find_all(self):
        return User.query.all()

    def find_by_id(self, user_id):
        return User.query.get(user_id)

    def find_by_email(self, email):
        return User.query.filter_by(email=email).first()

    def create(self, name, email, password_hash, role):
        user = User(
            name=name,
            email=email,
            password_hash=password_hash,
            role=role,
        )
        db.session.add(user)
        db.session.commit()
        return user

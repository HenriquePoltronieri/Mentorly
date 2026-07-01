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

    def update(self, user_id, name=None, email=None, password_hash=None, role=None):
        user = self.find_by_id(user_id)
        if user is None:
            return None
        if name is not None:
            user.name = name
        if email is not None:
            user.email = email
        if password_hash is not None:
            user.password_hash = password_hash
        if role is not None:
            user.role = role
        db.session.commit()
        return user

    def delete(self, user_id):
        user = self.find_by_id(user_id)
        if user is None:
            return False
        db.session.delete(user)
        db.session.commit()
        return True

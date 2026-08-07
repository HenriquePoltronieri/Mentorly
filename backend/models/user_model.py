from datetime import datetime

from database import db


class User(db.Model):
    __tablename__ = "users"

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    name = db.Column(db.String(120), nullable=False)
    email = db.Column(db.String(120), nullable=False, unique=True)
    password_hash = db.Column(db.String(255), nullable=False)
    role = db.Column(db.String(20), nullable=False, default="mentee")
    created_at = db.Column(
        db.DateTime, nullable=False, default=datetime.utcnow
    )
    updated_at = db.Column(
        db.DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow
    )

    @classmethod
    def find_all(cls):
        return cls.query.all()

    @classmethod
    def find_by_id(cls, user_id):
        return cls.query.get(user_id)

    @classmethod
    def create(cls, name, email, password_hash, role):
        user = cls(
            name=name,
            email=email,
            password_hash=password_hash,
            role=role,
        )
        db.session.add(user)
        db.session.commit()
        return user

    def update(self, name=None, email=None, password_hash=None, role=None):
        if name is not None:
            self.name = name
        if email is not None:
            self.email = email
        if password_hash is not None:
            self.password_hash = password_hash
        if role is not None:
            self.role = role
        db.session.commit()
        return self

    def delete(self):
        db.session.delete(self)
        db.session.commit()

    def to_dict(self):
        return {
            "id": self.id,
            "name": self.name,
            "email": self.email,
            "role": self.role,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }
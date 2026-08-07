from datetime import datetime

from database import db


class Class(db.Model):
    __tablename__ = "classes"

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    name = db.Column(db.String(120), nullable=False)
    description = db.Column(db.Text, nullable=True)
    created_at = db.Column(
        db.DateTime, nullable=False, default=datetime.utcnow
    )
    updated_at = db.Column(
        db.DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow
    )

    activities = db.relationship(
        "Activity", backref="class_obj", lazy=True, cascade="all, delete-orphan"
    )

    @classmethod
    def find_all(cls):
        return cls.query.all()

    @classmethod
    def find_by_id(cls, class_id):
        return cls.query.get(class_id)

    @classmethod
    def create(cls, name, description=None):
        class_obj = cls(name=name, description=description)
        db.session.add(class_obj)
        db.session.commit()
        return class_obj

    def update(self, name=None, description=None):
        if name is not None:
            self.name = name
        if description is not None:
            self.description = description
        db.session.commit()
        return self

    def delete(self):
        db.session.delete(self)
        db.session.commit()

    def to_dict(self):
        return {
            "id": self.id,
            "name": self.name,
            "description": self.description,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }
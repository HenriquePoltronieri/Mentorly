from datetime import datetime

from database import db


class Activity(db.Model):
    __tablename__ = "activities"

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    title = db.Column(db.String(200), nullable=False)
    description = db.Column(db.Text, nullable=True)
    class_id = db.Column(db.Integer, db.ForeignKey("classes.id"), nullable=False)
    due_date = db.Column(db.DateTime, nullable=True)
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
    def find_by_id(cls, activity_id):
        return cls.query.get(activity_id)

    @classmethod
    def create(cls, title, class_id, description=None, due_date=None):
        activity = cls(
            title=title,
            description=description,
            class_id=class_id,
            due_date=due_date,
        )
        db.session.add(activity)
        db.session.commit()
        return activity

    def update(self, title=None, description=None, class_id=None, due_date=None):
        if title is not None:
            self.title = title
        if description is not None:
            self.description = description
        if class_id is not None:
            self.class_id = class_id
        if due_date is not None:
            self.due_date = due_date
        db.session.commit()
        return self

    def delete(self):
        db.session.delete(self)
        db.session.commit()

    def to_dict(self):
        return {
            "id": self.id,
            "title": self.title,
            "description": self.description,
            "class_id": self.class_id,
            "due_date": self.due_date.isoformat() if self.due_date else None,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }
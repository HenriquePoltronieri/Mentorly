from datetime import datetime

from database import db
from models.activity import Activity


class ActivityRepository:
    def find_all(self):
        return Activity.query.all()

    def find_by_id(self, activity_id):
        return Activity.query.get(activity_id)

    def find_by_class_id(self, class_id):
        return Activity.query.filter_by(class_id=class_id).all()

    def create(self, title, class_id, description=None, due_date=None):
        if isinstance(due_date, str) and due_date.strip():
            due_date = datetime.fromisoformat(due_date)
        elif isinstance(due_date, str):
            due_date = None

        activity = Activity(
            title=title,
            description=description,
            class_id=class_id,
            due_date=due_date,
        )
        db.session.add(activity)
        db.session.commit()
        return activity

    def update(self, activity_id, title=None, description=None, class_id=None, due_date=None):
        activity = self.find_by_id(activity_id)
        if activity is None:
            return None
        if title is not None:
            activity.title = title
        if description is not None:
            activity.description = description
        if class_id is not None:
            activity.class_id = class_id
        if due_date is not None:
            if isinstance(due_date, str) and due_date.strip():
                due_date = datetime.fromisoformat(due_date)
            elif isinstance(due_date, str):
                due_date = None
            activity.due_date = due_date
        db.session.commit()
        return activity

    def delete(self, activity_id):
        activity = self.find_by_id(activity_id)
        if activity is None:
            return False
        db.session.delete(activity)
        db.session.commit()
        return True
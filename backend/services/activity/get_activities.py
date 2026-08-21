from models.activity_model import Activity
from repositories.activity_repository import ActivityRepository


class GetActivitiesService:
    def __init__(self):
        self.repository = ActivityRepository()

    def execute(self, class_id=None):
        if class_id:
            return self.repository.find_by_class_id(class_id)
        return Activity.find_all()
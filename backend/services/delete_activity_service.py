from repositories.activity_repository import ActivityRepository


class DeleteActivityService:
    def __init__(self):
        self.repository = ActivityRepository()

    def execute(self, activity_id):
        activity = self.repository.find_by_id(activity_id)
        if activity is None:
            raise ValueError("Activity not found")

        self.repository.delete(activity_id)
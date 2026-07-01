from repositories.activity_repository import ActivityRepository


class GetActivityService:
    def __init__(self):
        self.repository = ActivityRepository()

    def execute(self, activity_id):
        return self.repository.find_by_id(activity_id)
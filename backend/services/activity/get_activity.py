from models.activity_model import Activity


class GetActivityService:
    def execute(self, activity_id):
        return Activity.find_by_id(activity_id)
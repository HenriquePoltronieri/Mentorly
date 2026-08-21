from models.activity_model import Activity


class DeleteActivityService:
    def execute(self, activity_id):
        activity = Activity.find_by_id(activity_id)
        if activity is None:
            raise ValueError("Activity not found")

        activity.delete()
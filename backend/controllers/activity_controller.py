from flask import Blueprint, jsonify, request

from services.create_activity_service import CreateActivityService
from services.list_activities_service import ListActivitiesService
from services.get_activity_service import GetActivityService
from services.update_activity_service import UpdateActivityService
from services.delete_activity_service import DeleteActivityService

activity_blueprint = Blueprint("activities", __name__, url_prefix="/activities")

list_activities_service = ListActivitiesService()
get_activity_service = GetActivityService()
create_activity_service = CreateActivityService()
update_activity_service = UpdateActivityService()
delete_activity_service = DeleteActivityService()


@activity_blueprint.get("")
def list_activities():
    class_id = request.args.get("class_id", type=int)
    activities = list_activities_service.execute(class_id)
    return jsonify([a.to_dict() for a in activities])


@activity_blueprint.get("/<int:activity_id>")
def get_activity(activity_id):
    activity = get_activity_service.execute(activity_id)
    if activity is None:
        return jsonify({"error": "Activity not found"}), 404
    return jsonify(activity.to_dict())


@activity_blueprint.post("")
def create_activity():
    data = request.get_json(silent=True) or {}
    title = data.get("title")
    class_id = data.get("class_id")
    description = data.get("description")
    due_date = data.get("due_date")

    if not title or not class_id:
        return jsonify({"error": "title and class_id are required"}), 400

    try:
        activity = create_activity_service.execute(title, class_id, description, due_date)
    except ValueError as error:
        return jsonify({"error": str(error)}), 409

    return jsonify(activity.to_dict()), 201


@activity_blueprint.put("/<int:activity_id>")
def update_activity(activity_id):
    data = request.get_json(silent=True) or {}
    title = data.get("title")
    description = data.get("description")
    class_id = data.get("class_id")
    due_date = data.get("due_date")

    if not any([title, description is not None, class_id, due_date is not None]):
        return jsonify({"error": "At least one field must be provided"}), 400

    try:
        activity = update_activity_service.execute(activity_id, title, description, class_id, due_date)
    except ValueError as error:
        return jsonify({"error": str(error)}), 404

    return jsonify(activity.to_dict())


@activity_blueprint.delete("/<int:activity_id>")
def delete_activity(activity_id):
    try:
        delete_activity_service.execute(activity_id)
    except ValueError as error:
        return jsonify({"error": str(error)}), 404

    return "", 204
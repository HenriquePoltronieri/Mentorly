from flask import Blueprint, jsonify, request

from services.activity_service import ActivityService

activity_blueprint = Blueprint("activities", __name__, url_prefix="/activities")
activity_service = ActivityService()


@activity_blueprint.get("")
def list_activities():
    class_id = request.args.get("class_id", type=int)
    activities = activity_service.list_activities(class_id)
    return jsonify([a.to_dict() for a in activities])


@activity_blueprint.get("/<int:activity_id>")
def get_activity(activity_id):
    activity = activity_service.get_activity(activity_id)
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
        activity = activity_service.create_activity(title, class_id, description, due_date)
    except ValueError as error:
        return jsonify({"error": str(error)}), 400

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
        activity = activity_service.update_activity(activity_id, title, description, class_id, due_date)
    except ValueError as error:
        return jsonify({"error": str(error)}), 400

    return jsonify(activity.to_dict())


@activity_blueprint.delete("/<int:activity_id>")
def delete_activity(activity_id):
    try:
        activity_service.delete_activity(activity_id)
    except ValueError as error:
        return jsonify({"error": str(error)}), 404

    return "", 204
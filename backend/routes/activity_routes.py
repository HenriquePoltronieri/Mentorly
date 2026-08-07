from flask import Blueprint

from controllers.activity_controller import ActivityController

activity_blueprint = Blueprint("activities", __name__, url_prefix="/api/activities")
activity_controller = ActivityController()


@activity_blueprint.get("")
def list_activities():
    return activity_controller.list_activities()


@activity_blueprint.get("/buscar")
def buscar_atividades():
    return activity_controller.buscar_atividades()


@activity_blueprint.get("/<int:activity_id>")
def get_activity(activity_id):
    return activity_controller.get_activity(activity_id)


@activity_blueprint.post("")
def create_activity():
    return activity_controller.create_activity()


@activity_blueprint.put("/<int:activity_id>")
def update_activity(activity_id):
    return activity_controller.update_activity(activity_id)


@activity_blueprint.delete("/<int:activity_id>")
def delete_activity(activity_id):
    return activity_controller.delete_activity(activity_id)
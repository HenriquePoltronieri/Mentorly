from flask import Blueprint

from auth.decorators import auth_required, professor_required
from controllers.activity_controller import ActivityController

activity_blueprint = Blueprint("activities", __name__, url_prefix="/api/activities")
activity_controller = ActivityController()


# Leitura: os dois papeis. A Coordenacao precisa disso para o relatorio e a
# busca; o recorte de cada um e resolvido no controller.
@activity_blueprint.get("")
@auth_required
def list_activities():
    return activity_controller.list_activities()


@activity_blueprint.get("/buscar")
@auth_required
def buscar_atividades():
    return activity_controller.buscar_atividades()


@activity_blueprint.get("/<int:activity_id>")
@auth_required
def get_activity(activity_id):
    return activity_controller.get_activity(activity_id)


# Escrita: EXCLUSIVA do Professor. Token de Coordenacao recebe 403.
# E esta a correcao, no backend, do bug de a Coordenacao criar atividades.
@activity_blueprint.post("")
@professor_required
def create_activity():
    return activity_controller.create_activity()


@activity_blueprint.put("/<int:activity_id>")
@professor_required
def update_activity(activity_id):
    return activity_controller.update_activity(activity_id)


@activity_blueprint.delete("/<int:activity_id>")
@professor_required
def delete_activity(activity_id):
    return activity_controller.delete_activity(activity_id)

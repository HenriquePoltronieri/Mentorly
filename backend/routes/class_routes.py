from flask import Blueprint

from auth.decorators import auth_required, coordenacao_required
from controllers.class_controller import ClassController

class_blueprint = Blueprint("classes", __name__, url_prefix="/api/classes")
class_controller = ClassController()


# Leitura: os dois papeis podem, mas cada um enxerga um recorte diferente
# (a Coordenacao ve a escola; o Professor ve so as turmas vinculadas a ele).
@class_blueprint.get("")
@auth_required
def list_classes():
    return class_controller.list_classes()


@class_blueprint.get("/relatorio/atividades")
@coordenacao_required
def relatorio_turmas_atividades():
    return class_controller.relatorio_turmas_atividades()


@class_blueprint.get("/<int:class_id>")
@auth_required
def get_class(class_id):
    return class_controller.get_class(class_id)


# Escrita de turma e exclusiva da Coordenacao.
@class_blueprint.post("")
@coordenacao_required
def create_class():
    return class_controller.create_class()


@class_blueprint.put("/<int:class_id>")
@coordenacao_required
def update_class(class_id):
    return class_controller.update_class(class_id)


@class_blueprint.delete("/<int:class_id>")
@coordenacao_required
def delete_class(class_id):
    return class_controller.delete_class(class_id)

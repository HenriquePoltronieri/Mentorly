from flask import Blueprint

from controllers.class_controller import ClassController

class_blueprint = Blueprint("classes", __name__, url_prefix="/api/classes")
class_controller = ClassController()


@class_blueprint.get("")
def list_classes():
    return class_controller.list_classes()


@class_blueprint.get("/relatorio/atividades")
def relatorio_turmas_atividades():
    return class_controller.relatorio_turmas_atividades()


@class_blueprint.get("/<int:class_id>")
def get_class(class_id):
    return class_controller.get_class(class_id)


@class_blueprint.post("")
def create_class():
    return class_controller.create_class()


@class_blueprint.put("/<int:class_id>")
def update_class(class_id):
    return class_controller.update_class(class_id)


@class_blueprint.delete("/<int:class_id>")
def delete_class(class_id):
    return class_controller.delete_class(class_id)
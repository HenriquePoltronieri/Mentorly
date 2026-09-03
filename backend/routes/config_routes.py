from flask import Blueprint

from auth.decorators import auth_required, coordenacao_required
from controllers.config_controller import ConfigController

config_blueprint = Blueprint("config", __name__, url_prefix="/api/config")
config_controller = ConfigController()


# ---------------------------------------------------------------------
# Etapas
# ---------------------------------------------------------------------

# Leitura liberada para os dois papeis: o professor precisa das etapas e da
# nota minima da escola para lancar nota e ver alunos em risco.
@config_blueprint.get("/etapas")
@auth_required
def listar_etapas():
    return config_controller.listar_etapas()


@config_blueprint.get("/etapas/<int:etapa_id>")
@auth_required
def buscar_etapa(etapa_id):
    return config_controller.buscar_etapa(etapa_id)


# Escrita: so a Coordenacao configura o ano letivo.
@config_blueprint.post("/etapas")
@coordenacao_required
def salvar_etapa():
    return config_controller.salvar_etapa()


@config_blueprint.put("/etapas/<int:etapa_id>")
@coordenacao_required
def atualizar_etapa(etapa_id):
    return config_controller.atualizar_etapa(etapa_id)


@config_blueprint.post("/etapas/<int:etapa_id>/notas")
@coordenacao_required
def definir_notas(etapa_id):
    return config_controller.definir_notas(etapa_id)


@config_blueprint.delete("/etapas/<int:etapa_id>")
@coordenacao_required
def excluir_etapa(etapa_id):
    return config_controller.excluir_etapa(etapa_id)


# ---------------------------------------------------------------------
# Criterios
# ---------------------------------------------------------------------

@config_blueprint.get("/criterios/etapa/<int:etapa_id>")
@auth_required
def listar_criterios(etapa_id):
    return config_controller.listar_criterios(etapa_id)


@config_blueprint.get("/criterios/<int:criterio_id>")
@auth_required
def buscar_criterio(criterio_id):
    return config_controller.buscar_criterio(criterio_id)


@config_blueprint.post("/criterios/etapa/<int:etapa_id>")
@coordenacao_required
def salvar_criterio(etapa_id):
    return config_controller.salvar_criterio(etapa_id)


@config_blueprint.put("/criterios/<int:criterio_id>")
@coordenacao_required
def atualizar_criterio(criterio_id):
    return config_controller.atualizar_criterio(criterio_id)


@config_blueprint.delete("/criterios/<int:criterio_id>")
@coordenacao_required
def excluir_criterio(criterio_id):
    return config_controller.excluir_criterio(criterio_id)

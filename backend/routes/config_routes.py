from flask import Blueprint

from auth.decorators import auth_required, coordenacao_required
from controllers.config_controller import ConfigController

config_blueprint = Blueprint("config", __name__, url_prefix="/api/config")
config_controller = ConfigController()


# ---------------------------------------------------------------------
# Anos letivos (Marco 6)
# ---------------------------------------------------------------------

# Administrar o ano letivo e ato da Coordenacao, inclusive a leitura da lista:
# o Professor nao tem rota aqui, so consome o contexto (o ano das turmas dele e
# o ano atual da escola, no dashboard).
@config_blueprint.get("/anos-letivos")
@coordenacao_required
def listar_anos_letivos():
    return config_controller.listar_anos_letivos()


@config_blueprint.post("/anos-letivos")
@coordenacao_required
def criar_ano_letivo():
    return config_controller.criar_ano_letivo()


@config_blueprint.put("/anos-letivos/<int:ano_letivo_id>")
@coordenacao_required
def atualizar_ano_letivo(ano_letivo_id):
    return config_controller.atualizar_ano_letivo(ano_letivo_id)


@config_blueprint.delete("/anos-letivos/<int:ano_letivo_id>")
@coordenacao_required
def excluir_ano_letivo(ano_letivo_id):
    return config_controller.excluir_ano_letivo(ano_letivo_id)


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


# Fechamento: so a Coordenacao fecha/reabre a etapa da propria escola.
@config_blueprint.post("/etapas/<int:etapa_id>/fechar")
@coordenacao_required
def fechar_etapa(etapa_id):
    return config_controller.fechar_etapa(etapa_id)


@config_blueprint.post("/etapas/<int:etapa_id>/reabrir")
@coordenacao_required
def reabrir_etapa(etapa_id):
    return config_controller.reabrir_etapa(etapa_id)


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

"""Controller de atividades (/api/activities).

Regra de negocio central: criar, editar e excluir atividade e EXCLUSIVO do
Professor. As rotas de escrita usam @professor_required, entao um token de
Coordenacao recebe 403 - a validacao esta no backend, nao so escondendo o
botao no app.

A Coordenacao continua podendo LER (relatorio e busca), sempre filtrada
pela escola dela.
"""

from flask import jsonify, request

from auth.decorators import coordenacao_atual, eh_professor, usuario_atual_id
from services.activity.create_activity import CreateActivityService
from services.activity.delete_activity import DeleteActivityService
from services.activity.get_activities import GetActivitiesService
from services.activity.get_activity import GetActivityService
from services.activity.search_activities import SearchActivitiesService
from services.activity.update_activity import UpdateActivityService


def _professor_id_ou_none():
    """Professor -> o id dele (recorte pelas turmas). Coordenacao -> None."""
    return usuario_atual_id() if eh_professor() else None


class ActivityController:
    def list_activities(self):
        turma_id = request.args.get("class_id", type=int)
        if turma_id is None:
            turma_id = request.args.get("turma_id", type=int)

        return jsonify(
            GetActivitiesService().execute(
                coordenacao_atual(), _professor_id_ou_none(), turma_id
            )
        )

    def buscar_atividades(self):
        return jsonify(
            SearchActivitiesService().execute(
                coordenacao_atual(),
                _professor_id_ou_none(),
                request.args.get("termo"),
                request.args.get("ordenar_por"),
                request.args.get("direcao"),
            )
        )

    def get_activity(self, activity_id):
        atividade = GetActivityService().execute(
            activity_id, coordenacao_atual(), _professor_id_ou_none()
        )
        if atividade is None:
            return jsonify({"error": "Atividade nao encontrada"}), 404
        return jsonify(atividade)

    def create_activity(self):
        dados = request.get_json(silent=True) or {}
        titulo = dados.get("title") or dados.get("titulo")
        turma_id = dados.get("class_id") or dados.get("turma_id")

        if not titulo or not turma_id:
            return jsonify(
                {"error": "Informe o titulo e a turma da atividade"}
            ), 400

        try:
            atividade = CreateActivityService().execute(
                usuario_atual_id(),
                int(turma_id),
                titulo,
                dados.get("description") or dados.get("descricao"),
                dados.get("due_date") or dados.get("data_entrega"),
                dados.get("etapa_id"),
                dados.get("criterio_id"),
                dados.get("nota_maxima"),
            )
        except LookupError as erro:
            return jsonify({"error": str(erro)}), 404
        except (ValueError, TypeError) as erro:
            return jsonify({"error": str(erro)}), 400

        return jsonify(atividade), 201

    def update_activity(self, activity_id):
        dados = request.get_json(silent=True) or {}
        turma_id = dados.get("class_id") or dados.get("turma_id")

        try:
            atividade = UpdateActivityService().execute(
                activity_id,
                usuario_atual_id(),
                dados.get("title") or dados.get("titulo"),
                dados.get("description") or dados.get("descricao"),
                int(turma_id) if turma_id else None,
                dados.get("due_date") or dados.get("data_entrega"),
                dados.get("etapa_id"),
                dados.get("criterio_id"),
                dados.get("nota_maxima"),
            )
        except LookupError as erro:
            return jsonify({"error": str(erro)}), 404
        except (ValueError, TypeError) as erro:
            return jsonify({"error": str(erro)}), 400

        return jsonify(atividade)

    def delete_activity(self, activity_id):
        try:
            DeleteActivityService().execute(activity_id, usuario_atual_id())
        except LookupError as erro:
            return jsonify({"error": str(erro)}), 404
        return "", 204

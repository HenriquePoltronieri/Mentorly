from flask import jsonify, request

from services.activity_service import ActivityService


class ActivityController:
    def __init__(self):
        self.service = ActivityService()

    def list_activities(self):
        class_id = request.args.get("class_id", type=int)
        activities = self.service.list_activities(class_id)
        return jsonify([activity.to_dict() for activity in activities])

    def buscar_atividades(self):
        termo = request.args.get("termo")
        ordenar_por = request.args.get("ordenar_por")
        direcao = request.args.get("direcao")
        atividades = self.service.buscar_atividades(termo, ordenar_por, direcao)
        return jsonify(atividades)

    def get_activity(self, activity_id):
        activity = self.service.get_activity(activity_id)
        if activity is None:
            return jsonify({"error": "Activity not found"}), 404
        return jsonify(activity.to_dict())

    def create_activity(self):
        data = request.get_json(silent=True) or {}
        title = data.get("title")
        class_id = data.get("class_id")
        description = data.get("description")
        due_date = data.get("due_date")

        if not title or not class_id:
            return jsonify({"error": "title and class_id are required"}), 400

        try:
            activity = self.service.create_activity(title, class_id, description, due_date)
        except ValueError as error:
            return jsonify({"error": str(error)}), 400

        return jsonify(activity.to_dict()), 201

    def update_activity(self, activity_id):
        data = request.get_json(silent=True) or {}
        title = data.get("title")
        description = data.get("description")
        class_id = data.get("class_id")
        due_date = data.get("due_date")

        if not any([title, description is not None, class_id, due_date is not None]):
            return jsonify({"error": "At least one field must be provided"}), 400

        try:
            activity = self.service.update_activity(activity_id, title, description, class_id, due_date)
        except ValueError as error:
            return jsonify({"error": str(error)}), 400

        return jsonify(activity.to_dict())

    def delete_activity(self, activity_id):
        try:
            self.service.delete_activity(activity_id)
        except ValueError as error:
            return jsonify({"error": str(error)}), 404

        return "", 204

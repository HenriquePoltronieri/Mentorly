from flask import Flask, jsonify

from database.connection import init_database, install_procedures, install_schema
from routes.activity_routes import activity_blueprint
from routes.auth_routes import auth_blueprint
from routes.class_routes import class_blueprint
from routes.config_routes import config_blueprint
from routes.coordenacao_routes import coordenacao_blueprint
from routes.dashboard_routes import dashboard_blueprint
from routes.professor_routes import (
    atividade_notas_blueprint,
    professor_blueprint,
)


def create_app():
    app = Flask(__name__)

    # Limite de upload das planilhas. Sem isso, um arquivo enorme fica
    # inteiro na memoria antes de o service conseguir recusar.
    app.config["MAX_CONTENT_LENGTH"] = 5 * 1024 * 1024

    app.register_blueprint(auth_blueprint)
    app.register_blueprint(coordenacao_blueprint)
    app.register_blueprint(professor_blueprint)
    app.register_blueprint(atividade_notas_blueprint)
    app.register_blueprint(config_blueprint)
    app.register_blueprint(class_blueprint)
    app.register_blueprint(activity_blueprint)
    app.register_blueprint(dashboard_blueprint)

    # Libera o acesso do Flutter Web: o app roda em outra porta, entao o
    # navegador trata como outra origem e bloqueia a chamada sem estes
    # cabecalhos. No emulador Android isso nao e necessario, mas nao atrapalha.
    @app.after_request
    def liberar_cors(response):
        response.headers["Access-Control-Allow-Origin"] = "*"
        response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
        response.headers["Access-Control-Allow-Methods"] = (
            "GET, POST, PUT, DELETE, OPTIONS"
        )
        response.headers["Access-Control-Expose-Headers"] = "Content-Disposition"
        return response

    @app.errorhandler(413)
    def arquivo_grande(_erro):
        return jsonify({"error": "Arquivo muito grande (limite de 5 MB)"}), 413

    @app.get("/")
    def health_check():
        return {"status": "ok", "service": "Mentorly API"}

    return app


if __name__ == "__main__":
    init_database()
    install_schema()
    install_procedures()
    app = create_app()
    app.run(debug=True)

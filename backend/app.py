from flask import Flask

from config import SQLALCHEMY_DATABASE_URI
from database import db
from database.connection import init_database, install_procedures
from routes.activity_routes import activity_blueprint
from routes.class_routes import class_blueprint
from routes.dashboard_routes import dashboard_blueprint
from routes.user_routes import user_blueprint


def create_app():
    app = Flask(__name__)
    app.config["SQLALCHEMY_DATABASE_URI"] = SQLALCHEMY_DATABASE_URI
    app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

    db.init_app(app)
    app.register_blueprint(user_blueprint)
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
        response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
        return response

    @app.get("/")
    def health_check():
        return {"status": "ok", "service": "Mentorly API"}

    return app


if __name__ == "__main__":
    init_database()
    install_procedures()
    app = create_app()
    with app.app_context():
        db.create_all()
    app.run(debug=True)

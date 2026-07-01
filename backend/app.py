from flask import Flask

from config import SQLALCHEMY_DATABASE_URI
from controllers.user_controller import user_blueprint
from controllers.class_controller import class_blueprint
from controllers.activity_controller import activity_blueprint
from database import db
from database.connection import init_database


def create_app():
    app = Flask(__name__)
    app.config["SQLALCHEMY_DATABASE_URI"] = SQLALCHEMY_DATABASE_URI
    app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

    db.init_app(app)
    app.register_blueprint(user_blueprint)
    app.register_blueprint(class_blueprint)
    app.register_blueprint(activity_blueprint)

    @app.get("/")
    def health_check():
        return {"status": "ok", "service": "Mentorly API"}

    return app


if __name__ == "__main__":
    init_database()
    app = create_app()
    with app.app_context():
        db.create_all()
    app.run(debug=True)

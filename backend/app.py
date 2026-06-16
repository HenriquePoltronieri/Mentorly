from flask import Flask

from controllers.user_controller import user_blueprint
from database.connection import init_database


def create_app():
    app = Flask(__name__)
    app.register_blueprint(user_blueprint)

    @app.get("/")
    def health_check():
        return {"status": "ok", "service": "Mentorly API"}

    return app


if __name__ == "__main__":
    init_database()
    app = create_app()
    app.run(debug=True)

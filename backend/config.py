import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
CREATE_DATABASE_SCRIPT = os.path.join(BASE_DIR, "database", "create_database.sql")

DB_CONFIG = {
    "host": os.environ.get("DB_HOST", "localhost"),
    "port": int(os.environ.get("DB_PORT", 3306)),
    "user": os.environ.get("DB_USER", "root"),
    "password": os.environ.get("DB_PASSWORD", ""),
    "database": os.environ.get("DB_NAME", "mentorly"),
}

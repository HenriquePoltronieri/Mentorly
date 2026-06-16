import pymysql
import pymysql.cursors

from config import CREATE_DATABASE_SCRIPT, DB_CONFIG


def get_connection():
    return pymysql.connect(cursorclass=pymysql.cursors.DictCursor, **DB_CONFIG)


def init_database():
    connection = pymysql.connect(
        host=DB_CONFIG["host"],
        port=DB_CONFIG["port"],
        user=DB_CONFIG["user"],
        password=DB_CONFIG["password"],
    )
    try:
        with open(CREATE_DATABASE_SCRIPT, "r", encoding="utf-8") as script_file:
            statements = [s.strip() for s in script_file.read().split(";") if s.strip()]
        with connection.cursor() as cursor:
            for statement in statements:
                cursor.execute(statement)
        connection.commit()
    finally:
        connection.close()

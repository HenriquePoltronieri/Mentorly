from database.connection import get_connection
from models.user import User


class UserRepository:
    def find_all(self):
        connection = get_connection()
        try:
            with connection.cursor() as cursor:
                cursor.execute("SELECT * FROM users")
                rows = cursor.fetchall()
        finally:
            connection.close()
        return [User.from_row(row) for row in rows]

    def find_by_id(self, user_id):
        connection = get_connection()
        try:
            with connection.cursor() as cursor:
                cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))
                row = cursor.fetchone()
        finally:
            connection.close()
        return User.from_row(row)

    def find_by_email(self, email):
        connection = get_connection()
        try:
            with connection.cursor() as cursor:
                cursor.execute("SELECT * FROM users WHERE email = %s", (email,))
                row = cursor.fetchone()
        finally:
            connection.close()
        return User.from_row(row)

    def create(self, name, email, password_hash, role):
        connection = get_connection()
        try:
            with connection.cursor() as cursor:
                cursor.execute(
                    "INSERT INTO users (name, email, password_hash, role) VALUES (%s, %s, %s, %s)",
                    (name, email, password_hash, role),
                )
                user_id = cursor.lastrowid
            connection.commit()
        finally:
            connection.close()
        return self.find_by_id(user_id)

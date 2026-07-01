class User:
    def __init__(self, id, name, email, password_hash, role="mentee", created_at=None):
        self.id = id
        self.name = name
        self.email = email
        self.password_hash = password_hash
        self.role = role
        self.created_at = created_at

    @staticmethod
    def from_row(row):
        if row is None:
            return None
        return User(
            id=row["id"],
            name=row["name"],
            email=row["email"],
            password_hash=row["password_hash"],
            role=row["role"],
            created_at=row["created_at"],
        )

    def to_dict(self):
        return {
            "id": self.id,
            "name": self.name,
            "email": self.email,
            "role": self.role,
            "created_at": self.created_at,
        }
class student:
    def __init__(self, id, name, ):
        pass

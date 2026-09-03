"""Model da Coordenacao (a escola). SQL direto, sem ORM."""

from database.connection import execute, insert, query_all, query_one
from models.utils import iso


class Coordenacao:
    TABELA = "coordenacao"

    # -----------------------------------------------------------------
    # Leitura
    # -----------------------------------------------------------------
    @staticmethod
    def find_all():
        return query_all(
            "SELECT id, nome, email, telefone, created_at, updated_at "
            "FROM coordenacao ORDER BY nome ASC"
        )

    @staticmethod
    def find_by_id(coordenacao_id):
        return query_one(
            "SELECT id, nome, email, telefone, created_at, updated_at "
            "FROM coordenacao WHERE id = %s",
            (coordenacao_id,),
        )

    @staticmethod
    def find_by_email(email):
        """Traz o senha_hash junto: e a unica consulta que precisa dele."""
        return query_one(
            "SELECT id, nome, email, senha_hash, telefone, created_at, updated_at "
            "FROM coordenacao WHERE email = %s",
            (email,),
        )

    # -----------------------------------------------------------------
    # Escrita
    # -----------------------------------------------------------------
    @staticmethod
    def create(nome, email, senha_hash, telefone=None):
        return insert(
            "INSERT INTO coordenacao (nome, email, senha_hash, telefone) "
            "VALUES (%s, %s, %s, %s)",
            (nome, email, senha_hash, telefone),
        )

    @staticmethod
    def update(coordenacao_id, nome=None, telefone=None, senha_hash=None):
        campos = []
        valores = []
        if nome is not None:
            campos.append("nome = %s")
            valores.append(nome)
        if telefone is not None:
            campos.append("telefone = %s")
            valores.append(telefone)
        if senha_hash is not None:
            campos.append("senha_hash = %s")
            valores.append(senha_hash)
        if not campos:
            return 0
        valores.append(coordenacao_id)
        return execute(
            "UPDATE coordenacao SET %s WHERE id = %%s" % ", ".join(campos),
            tuple(valores),
        )

    @staticmethod
    def delete(coordenacao_id):
        return execute("DELETE FROM coordenacao WHERE id = %s", (coordenacao_id,))

    # -----------------------------------------------------------------
    # Serializacao
    # -----------------------------------------------------------------
    @staticmethod
    def to_dict(linha):
        """Formato que o UserModel do Flutter espera: id, nome, email, tipo."""
        if not linha:
            return None
        return {
            "id": linha["id"],
            "nome": linha["nome"],
            "email": linha["email"],
            "telefone": linha.get("telefone"),
            "tipo": "coordenacao",
            "created_at": iso(linha.get("created_at")),
            "updated_at": iso(linha.get("updated_at")),
        }

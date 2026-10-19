"""Model do Professor.

Todo metodo de leitura em lote recebe coordenacao_id: nao existe consulta
que devolva professores de todas as escolas.
"""

import hashlib
from database.connection import execute, insert, query_all, query_one
from database.orm import db
from models.utils import booleano, iso


def hash_convite(token):
    return hashlib.sha256(token.encode("utf-8")).hexdigest() if token else None


class Professor(db.Model):
    __tablename__ = "professor"
    id = db.Column(db.Integer, primary_key=True)
    coordenacao_id = db.Column(db.Integer, db.ForeignKey("coordenacao.id"), nullable=False)
    nome = db.Column(db.String(150), nullable=False)
    email = db.Column(db.String(150), nullable=False, unique=True)
    disciplina = db.Column(db.String(100))
    senha_hash = db.Column(db.String(255))
    habilitado = db.Column(db.Boolean, nullable=False)
    convite_token = db.Column(db.String(64))
    convite_expira_em = db.Column(db.DateTime)
    created_at = db.Column(db.DateTime)
    updated_at = db.Column(db.DateTime)
    TABELA = "professor"

    # -----------------------------------------------------------------
    # Leitura
    # -----------------------------------------------------------------
    @staticmethod
    def find_all_by_coordenacao(coordenacao_id):
        return query_all(
            "SELECT id, coordenacao_id, nome, email, disciplina, senha_hash, "
            "       habilitado, created_at, updated_at "
            "FROM professor WHERE coordenacao_id = %s ORDER BY nome ASC",
            (coordenacao_id,),
        )

    @staticmethod
    def find_by_id(professor_id, coordenacao_id=None):
        """Com coordenacao_id, so encontra se o professor for daquela escola."""
        if coordenacao_id is None:
            return query_one(
                "SELECT id, coordenacao_id, nome, email, disciplina, senha_hash, "
                "       habilitado, created_at, updated_at "
                "FROM professor WHERE id = %s",
                (professor_id,),
            )
        return query_one(
            "SELECT id, coordenacao_id, nome, email, disciplina, senha_hash, "
            "       habilitado, created_at, updated_at "
            "FROM professor WHERE id = %s AND coordenacao_id = %s",
            (professor_id, coordenacao_id),
        )

    @staticmethod
    def find_by_email(email):
        """Traz senha_hash e dados do convite: usado so pelo login/ativacao."""
        return query_one(
            "SELECT id, coordenacao_id, nome, email, disciplina, senha_hash, habilitado, "
            "       convite_token, convite_expira_em, created_at, updated_at "
            "FROM professor WHERE email = %s",
            (email,),
        )

    @staticmethod
    def find_by_convite(token):
        return query_one(
            "SELECT id, coordenacao_id, nome, email, disciplina, senha_hash, habilitado, "
            "       convite_token, convite_expira_em "
            "FROM professor WHERE convite_token = %s",
            (hash_convite(token),),
        )

    # -----------------------------------------------------------------
    # Escrita
    # -----------------------------------------------------------------
    @staticmethod
    def create(coordenacao_id, nome, email, disciplina=None,
               convite_token=None, convite_expira_em=None):
        return insert(
            "INSERT INTO professor "
            "(coordenacao_id, nome, email, disciplina, convite_token, convite_expira_em) "
            "VALUES (%s, %s, %s, %s, %s, %s)",
            (coordenacao_id, nome, email, disciplina,
             hash_convite(convite_token), convite_expira_em),
        )

    @staticmethod
    def definir_senha(professor_id, senha_hash, convite_token=None):
        """Ativa o professor e queima o convite."""
        return execute(
            "UPDATE professor SET senha_hash = %s, convite_token = NULL, "
            "convite_expira_em = NULL WHERE id = %s AND senha_hash IS NULL "
            "AND habilitado=1 AND convite_token=%s AND convite_expira_em >= NOW()",
            (senha_hash, professor_id, hash_convite(convite_token)),
        )

    @staticmethod
    def atualizar_convite(professor_id, convite_token, convite_expira_em):
        return execute(
            "UPDATE professor SET convite_token = %s, convite_expira_em = %s "
            "WHERE id = %s",
            (hash_convite(convite_token), convite_expira_em, professor_id),
        )

    @staticmethod
    def update(professor_id, coordenacao_id, nome=None, email=None, disciplina=None):
        campos = []
        valores = []
        if nome is not None:
            campos.append("nome = %s")
            valores.append(nome)
        if email is not None:
            campos.append("email = %s")
            valores.append(email)
        if disciplina is not None:
            campos.append("disciplina = %s")
            valores.append(disciplina)
        if not campos:
            return 0
        valores.extend([professor_id, coordenacao_id])
        return execute(
            "UPDATE professor SET %s WHERE id = %%s AND coordenacao_id = %%s"
            % ", ".join(campos),
            tuple(valores),
        )

    @staticmethod
    def definir_habilitado(professor_id, coordenacao_id, habilitado):
        return execute(
            "UPDATE professor SET habilitado = %s "
            "WHERE id = %s AND coordenacao_id = %s",
            (1 if habilitado else 0, professor_id, coordenacao_id),
        )

    @staticmethod
    def delete(professor_id, coordenacao_id):
        return execute(
            "DELETE FROM professor WHERE id = %s AND coordenacao_id = %s",
            (professor_id, coordenacao_id),
        )

    # -----------------------------------------------------------------
    # Serializacao
    # -----------------------------------------------------------------
    @staticmethod
    def to_dict(linha):
        if not linha:
            return None
        habilitado = booleano(linha.get("habilitado", True))
        senha_configurada = bool(linha.get("senha_hash") or linha.get("ativo"))
        status = (
            "desativado" if not habilitado
            else "ativo" if senha_configurada
            else "convite_pendente"
        )
        return {
            "id": linha["id"],
            "nome": linha["nome"],
            "email": linha["email"],
            "disciplina": linha.get("disciplina"),
            "tipo": "professor",
            # Legado: ativo continua significando que a senha foi criada.
            "ativo": senha_configurada,
            "habilitado": habilitado,
            "senhaConfigurada": senha_configurada,
            "status": status,
            "totalTurmas": linha.get("total_turmas"),
            "created_at": iso(linha.get("created_at")),
            "updated_at": iso(linha.get("updated_at")),
        }

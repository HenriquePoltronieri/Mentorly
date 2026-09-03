"""Model do Professor. SQL direto, sem ORM.

Todo metodo de leitura em lote recebe coordenacao_id: nao existe consulta
que devolva professores de todas as escolas.
"""

from database.connection import execute, insert, query_all, query_one
from models.utils import booleano, iso


class Professor:
    TABELA = "professor"

    # -----------------------------------------------------------------
    # Leitura
    # -----------------------------------------------------------------
    @staticmethod
    def find_all_by_coordenacao(coordenacao_id):
        return query_all(
            "SELECT id, coordenacao_id, nome, email, disciplina, "
            "       (senha_hash IS NOT NULL) AS ativo, created_at, updated_at "
            "FROM professor WHERE coordenacao_id = %s ORDER BY nome ASC",
            (coordenacao_id,),
        )

    @staticmethod
    def find_by_id(professor_id, coordenacao_id=None):
        """Com coordenacao_id, so encontra se o professor for daquela escola."""
        if coordenacao_id is None:
            return query_one(
                "SELECT id, coordenacao_id, nome, email, disciplina, "
                "       (senha_hash IS NOT NULL) AS ativo, created_at, updated_at "
                "FROM professor WHERE id = %s",
                (professor_id,),
            )
        return query_one(
            "SELECT id, coordenacao_id, nome, email, disciplina, "
            "       (senha_hash IS NOT NULL) AS ativo, created_at, updated_at "
            "FROM professor WHERE id = %s AND coordenacao_id = %s",
            (professor_id, coordenacao_id),
        )

    @staticmethod
    def find_by_email(email):
        """Traz senha_hash e dados do convite: usado so pelo login/ativacao."""
        return query_one(
            "SELECT id, coordenacao_id, nome, email, disciplina, senha_hash, "
            "       convite_token, convite_expira_em, created_at, updated_at "
            "FROM professor WHERE email = %s",
            (email,),
        )

    @staticmethod
    def find_by_convite(token):
        return query_one(
            "SELECT id, coordenacao_id, nome, email, disciplina, senha_hash, "
            "       convite_token, convite_expira_em "
            "FROM professor WHERE convite_token = %s",
            (token,),
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
             convite_token, convite_expira_em),
        )

    @staticmethod
    def definir_senha(professor_id, senha_hash):
        """Ativa o professor e queima o convite."""
        return execute(
            "UPDATE professor SET senha_hash = %s, convite_token = NULL, "
            "convite_expira_em = NULL WHERE id = %s",
            (senha_hash, professor_id),
        )

    @staticmethod
    def atualizar_convite(professor_id, convite_token, convite_expira_em):
        return execute(
            "UPDATE professor SET convite_token = %s, convite_expira_em = %s "
            "WHERE id = %s",
            (convite_token, convite_expira_em, professor_id),
        )

    @staticmethod
    def update(professor_id, coordenacao_id, nome=None, disciplina=None):
        campos = []
        valores = []
        if nome is not None:
            campos.append("nome = %s")
            valores.append(nome)
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
        return {
            "id": linha["id"],
            "nome": linha["nome"],
            "email": linha["email"],
            "disciplina": linha.get("disciplina"),
            "tipo": "professor",
            # ativo = ja criou senha pelo convite
            "ativo": booleano(linha.get("ativo")),
            "totalTurmas": linha.get("total_turmas"),
            "created_at": iso(linha.get("created_at")),
            "updated_at": iso(linha.get("updated_at")),
        }

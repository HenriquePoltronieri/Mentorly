"""Model do Aluno. SQL direto, sem ORM.

O aluno chega na escola pela turma. Por isso nenhuma consulta aqui recebe
coordenacao_id diretamente: quem valida a posse da turma e o service, antes
de chamar estes metodos.
"""

from database.connection import execute, insert, query_all, query_one, transacao
from models.utils import iso

_COLUNAS = "id, turma_id, nome, matricula, email, created_at, updated_at"


class Aluno:
    TABELA = "aluno"

    # -----------------------------------------------------------------
    # Leitura
    # -----------------------------------------------------------------
    @staticmethod
    def find_all_by_turma(turma_id):
        return query_all(
            "SELECT %s FROM aluno WHERE turma_id = %%s ORDER BY nome ASC"
            % _COLUNAS,
            (turma_id,),
        )

    @staticmethod
    def find_by_id(aluno_id):
        return query_one(
            "SELECT %s FROM aluno WHERE id = %%s" % _COLUNAS, (aluno_id,)
        )

    @staticmethod
    def find_com_turma(aluno_id):
        """Traz a coordenacao_id junto, para o service checar a posse."""
        return query_one(
            "SELECT al.id, al.turma_id, al.nome, al.matricula, al.email, "
            "       t.nome AS turma_nome, t.coordenacao_id "
            "FROM aluno al INNER JOIN turma t ON t.id = al.turma_id "
            "WHERE al.id = %s",
            (aluno_id,),
        )

    @staticmethod
    def find_by_matricula(turma_id, matricula):
        return query_one(
            "SELECT %s FROM aluno WHERE turma_id = %%s AND matricula = %%s"
            % _COLUNAS,
            (turma_id, matricula),
        )

    # -----------------------------------------------------------------
    # Escrita
    # -----------------------------------------------------------------
    @staticmethod
    def create(turma_id, nome, matricula=None, email=None):
        return insert(
            "INSERT INTO aluno (turma_id, nome, matricula, email) "
            "VALUES (%s, %s, %s, %s)",
            (turma_id, nome, matricula, email),
        )

    @staticmethod
    def create_em_lote(turma_id, alunos):
        """Insere varios alunos em uma transacao so.

        E o caminho da importacao por planilha: ou entra a planilha inteira,
        ou nao entra nada. Devolve os ids gerados.
        """
        ids = []
        with transacao() as cursor:
            for aluno in alunos:
                cursor.execute(
                    "INSERT INTO aluno (turma_id, nome, matricula, email) "
                    "VALUES (%s, %s, %s, %s)",
                    (turma_id, aluno["nome"], aluno.get("matricula"),
                     aluno.get("email")),
                )
                ids.append(cursor.lastrowid)
        return ids

    @staticmethod
    def update(aluno_id, nome=None, matricula=None, email=None):
        campos = []
        valores = []
        for coluna, valor in (
            ("nome", nome), ("matricula", matricula), ("email", email)
        ):
            if valor is not None:
                campos.append("%s = %%s" % coluna)
                valores.append(valor)
        if not campos:
            return 0
        valores.append(aluno_id)
        return execute(
            "UPDATE aluno SET %s WHERE id = %%s" % ", ".join(campos),
            tuple(valores),
        )

    @staticmethod
    def delete(aluno_id):
        return execute("DELETE FROM aluno WHERE id = %s", (aluno_id,))

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
            "matricula": linha.get("matricula"),
            "email": linha.get("email"),
            "turmaId": linha.get("turma_id"),
            "turma": linha.get("turma_nome"),
            "created_at": iso(linha.get("created_at")),
            "updated_at": iso(linha.get("updated_at")),
        }

"""Model da Atividade. SQL direto, sem ORM.

Atividade e conteudo pedagogico: so o Professor cria, e sempre dentro de
uma turma vinculada a ele. professor_id nunca vem do corpo da requisicao,
sai do token (ver auth/decorators.py).

A tabela e `atividade`, mas a API continua em /api/activities com as chaves
title/description/class_id/due_date, que as telas ja consomem.
"""

from database.connection import execute, insert, query_all, query_one
from models.utils import iso, numero

_COLUNAS = (
    "id, turma_id, professor_id, etapa_id, criterio_id, titulo, descricao, "
    "data_entrega, nota_maxima, created_at, updated_at"
)


class Atividade:
    TABELA = "atividade"

    # -----------------------------------------------------------------
    # Leitura
    # -----------------------------------------------------------------
    @staticmethod
    def find_all_by_coordenacao(coordenacao_id, turma_id=None):
        """Visao da Coordenacao: atividades da escola inteira (so leitura)."""
        sql = (
            "SELECT a.id, a.turma_id, a.professor_id, a.etapa_id, a.criterio_id, "
            "       a.titulo, a.descricao, a.data_entrega, a.nota_maxima, "
            "       a.created_at, a.updated_at, t.nome AS turma_nome "
            "FROM atividade a INNER JOIN turma t ON t.id = a.turma_id "
            "WHERE t.coordenacao_id = %s"
        )
        params = [coordenacao_id]
        if turma_id is not None:
            sql += " AND a.turma_id = %s"
            params.append(turma_id)
        sql += " ORDER BY a.data_entrega IS NULL, a.data_entrega ASC, a.id ASC"
        return query_all(sql, tuple(params))

    @staticmethod
    def find_all_by_professor(professor_id, turma_id=None):
        """Visao do Professor: so as turmas que a Coordenacao vinculou a ele."""
        sql = (
            "SELECT a.id, a.turma_id, a.professor_id, a.etapa_id, a.criterio_id, "
            "       a.titulo, a.descricao, a.data_entrega, a.nota_maxima, "
            "       a.created_at, a.updated_at, t.nome AS turma_nome "
            "FROM atividade a "
            "INNER JOIN turma t ON t.id = a.turma_id "
            "INNER JOIN professor_turma pt ON pt.turma_id = t.id "
            "WHERE pt.professor_id = %s"
        )
        params = [professor_id]
        if turma_id is not None:
            sql += " AND a.turma_id = %s"
            params.append(turma_id)
        sql += " ORDER BY a.data_entrega IS NULL, a.data_entrega ASC, a.id ASC"
        return query_all(sql, tuple(params))

    @staticmethod
    def find_by_id(atividade_id):
        """Traz coordenacao_id e turma para o service checar quem pode ver."""
        return query_one(
            "SELECT a.id, a.turma_id, a.professor_id, a.etapa_id, a.criterio_id, "
            "       a.titulo, a.descricao, a.data_entrega, a.nota_maxima, "
            "       a.created_at, a.updated_at, "
            "       t.nome AS turma_nome, t.coordenacao_id "
            "FROM atividade a INNER JOIN turma t ON t.id = a.turma_id "
            "WHERE a.id = %s",
            (atividade_id,),
        )

    # -----------------------------------------------------------------
    # Escrita
    # -----------------------------------------------------------------
    @staticmethod
    def create(turma_id, professor_id, titulo, descricao=None, data_entrega=None,
               etapa_id=None, criterio_id=None, nota_maxima=None):
        return insert(
            "INSERT INTO atividade "
            "(turma_id, professor_id, titulo, descricao, data_entrega, "
            " etapa_id, criterio_id, nota_maxima) "
            "VALUES (%s, %s, %s, %s, %s, %s, %s, %s)",
            (turma_id, professor_id, titulo, descricao, data_entrega,
             etapa_id, criterio_id, nota_maxima),
        )

    @staticmethod
    def update(atividade_id, titulo=None, descricao=None, turma_id=None,
               data_entrega=None, etapa_id=None, criterio_id=None,
               nota_maxima=None):
        campos = []
        valores = []
        for coluna, valor in (
            ("titulo", titulo),
            ("descricao", descricao),
            ("turma_id", turma_id),
            ("data_entrega", data_entrega),
            ("etapa_id", etapa_id),
            ("criterio_id", criterio_id),
            ("nota_maxima", nota_maxima),
        ):
            if valor is not None:
                campos.append("%s = %%s" % coluna)
                valores.append(valor)
        if not campos:
            return 0
        valores.append(atividade_id)
        return execute(
            "UPDATE atividade SET %s WHERE id = %%s" % ", ".join(campos),
            tuple(valores),
        )

    @staticmethod
    def delete(atividade_id):
        return execute("DELETE FROM atividade WHERE id = %s", (atividade_id,))

    # -----------------------------------------------------------------
    # Serializacao
    # -----------------------------------------------------------------
    @staticmethod
    def to_dict(linha):
        """Chaves em ingles porque AtividadeModel.fromJson ja le title,
        description, class_id e due_date."""
        if not linha:
            return None
        return {
            "id": linha["id"],
            "title": linha["titulo"],
            "titulo": linha["titulo"],
            "description": linha.get("descricao"),
            "descricao": linha.get("descricao"),
            "class_id": linha["turma_id"],
            "turmaId": linha["turma_id"],
            "class_name": linha.get("turma_nome"),
            "professor_id": linha.get("professor_id"),
            "etapa_id": linha.get("etapa_id"),
            "criterio_id": linha.get("criterio_id"),
            "nota_maxima": numero(linha.get("nota_maxima")),
            "due_date": iso(linha.get("data_entrega")),
            "created_at": iso(linha.get("created_at")),
            "updated_at": iso(linha.get("updated_at")),
        }

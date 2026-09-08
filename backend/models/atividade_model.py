"""Model da Atividade. SQL direto, sem ORM.

Atividade e conteudo pedagogico: so o Professor cria, e sempre dentro de
uma turma vinculada a ele. professor_id nunca vem do corpo da requisicao,
sai do token (ver auth/decorators.py).

A tabela e `atividade`, mas a API continua em /api/activities com as chaves
title/description/class_id/due_date, que as telas ja consomem.
"""

from database.connection import execute, insert, query_all, query_one
from models.utils import iso, numero

# SELECT unico das tres consultas. Os LEFT JOIN trazem o nome da etapa e do
# criterio para a lista do app mostrar "1o Bimestre - Prova - Vale 20 pontos"
# sem uma chamada por atividade. Sao LEFT porque atividade legada (criada
# antes do Marco 1) nao tem etapa nem criterio.
_SELECT = (
    "SELECT a.id, a.coordenacao_id, a.turma_id, a.professor_id, a.etapa_id, "
    "       a.criterio_id, a.titulo, a.descricao, a.data_entrega, "
    "       a.nota_maxima, a.created_at, a.updated_at, "
    "       t.nome AS turma_nome, "
    "       e.nome AS etapa_nome, e.ordem AS etapa_ordem, "
    "       c.nome AS criterio_nome, c.peso AS criterio_peso "
    "FROM atividade a "
    "INNER JOIN turma t ON t.id = a.turma_id "
    "LEFT JOIN etapa e ON e.id = a.etapa_id "
    "LEFT JOIN criterio c ON c.id = a.criterio_id "
)

_ORDEM = " ORDER BY a.data_entrega IS NULL, a.data_entrega ASC, a.id ASC"


class Atividade:
    TABELA = "atividade"

    # -----------------------------------------------------------------
    # Leitura
    # -----------------------------------------------------------------
    @staticmethod
    def find_all_by_coordenacao(coordenacao_id, turma_id=None):
        """Visao da Coordenacao: atividades da escola inteira (so leitura)."""
        sql = _SELECT + "WHERE a.coordenacao_id = %s"
        params = [coordenacao_id]
        if turma_id is not None:
            sql += " AND a.turma_id = %s"
            params.append(turma_id)
        return query_all(sql + _ORDEM, tuple(params))

    @staticmethod
    def find_all_by_professor(professor_id, turma_id=None):
        """Visao do Professor: so as turmas que a Coordenacao vinculou a ele."""
        sql = (
            _SELECT
            + "INNER JOIN professor_turma pt ON pt.turma_id = t.id "
              "WHERE pt.professor_id = %s"
        )
        params = [professor_id]
        if turma_id is not None:
            sql += " AND a.turma_id = %s"
            params.append(turma_id)
        return query_all(sql + _ORDEM, tuple(params))

    @staticmethod
    def find_by_id(atividade_id):
        """Traz coordenacao_id e turma para o service checar quem pode ver."""
        return query_one(_SELECT + "WHERE a.id = %s", (atividade_id,))

    @staticmethod
    def find_por_criterio(turma_id, etapa_id, criterio_id):
        """Atividades de uma turma que pertencem a esta etapa+criterio.

        Base do calculo academico (Marco 2): so entram aqui atividades com
        etapa_id e criterio_id preenchidos, entao uma atividade legada (do
        Marco 1, criada antes da regra) nunca aparece - a query so casa
        quando os dois valores nao sao nulos e batem exatamente. E assim
        que a atividade incompleta fica fora do calculo sem precisar de
        filtro extra.
        """
        return query_all(
            "SELECT id, nota_maxima FROM atividade "
            "WHERE turma_id = %s AND etapa_id = %s AND criterio_id = %s "
            "ORDER BY id ASC",
            (turma_id, etapa_id, criterio_id),
        )

    # -----------------------------------------------------------------
    # Escrita
    # -----------------------------------------------------------------
    @staticmethod
    def create(coordenacao_id, turma_id, professor_id, titulo, descricao=None,
               data_entrega=None, etapa_id=None, criterio_id=None,
               nota_maxima=None):
        """coordenacao_id vem do token, nunca do corpo da requisicao.

        Se ele nao bater com a escola da turma, da etapa ou do criterio, o
        INSERT e recusado pelas FKs compostas do schema - o service ja
        validou antes, isto e a segunda linha de defesa.
        """
        return insert(
            "INSERT INTO atividade "
            "(coordenacao_id, turma_id, professor_id, titulo, descricao, "
            " data_entrega, etapa_id, criterio_id, nota_maxima) "
            "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)",
            (coordenacao_id, turma_id, professor_id, titulo, descricao,
             data_entrega, etapa_id, criterio_id, nota_maxima),
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
            "coordenacao_id": linha.get("coordenacao_id"),
            "professor_id": linha.get("professor_id"),
            "etapa_id": linha.get("etapa_id"),
            "etapa_nome": linha.get("etapa_nome"),
            "etapaNome": linha.get("etapa_nome"),
            "etapa_ordem": linha.get("etapa_ordem"),
            "criterio_id": linha.get("criterio_id"),
            "criterio_nome": linha.get("criterio_nome"),
            "criterioNome": linha.get("criterio_nome"),
            "criterio_peso": numero(linha.get("criterio_peso")),
            "nota_maxima": numero(linha.get("nota_maxima")),
            "notaMaxima": numero(linha.get("nota_maxima")),
            "due_date": iso(linha.get("data_entrega")),
            "created_at": iso(linha.get("created_at")),
            "updated_at": iso(linha.get("updated_at")),
        }

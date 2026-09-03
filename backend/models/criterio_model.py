"""Model do Criterio de avaliacao (Provas, Trabalhos, Comportamento...).

Assim como a etapa, e configuracao padrao da escola. O upsert por
(etapa_id, nome) evita que repetir o fluxo de configuracao duplique os
criterios ja escolhidos.
"""

from database.connection import execute, insert, query_all, query_one
from models.utils import iso, numero

_COLUNAS = (
    "id, coordenacao_id, etapa_id, nome, peso, nota_maxima, "
    "created_at, updated_at"
)


class Criterio:
    TABELA = "criterio"

    # -----------------------------------------------------------------
    # Leitura
    # -----------------------------------------------------------------
    @staticmethod
    def find_all_by_etapa(etapa_id, coordenacao_id):
        return query_all(
            "SELECT %s FROM criterio "
            "WHERE etapa_id = %%s AND coordenacao_id = %%s ORDER BY nome ASC"
            % _COLUNAS,
            (etapa_id, coordenacao_id),
        )

    @staticmethod
    def find_all_by_coordenacao(coordenacao_id, ano_letivo=None):
        sql = (
            "SELECT c.id, c.coordenacao_id, c.etapa_id, c.nome, c.peso, "
            "       c.nota_maxima, c.created_at, c.updated_at, "
            "       e.nome AS etapa_nome, e.ordem AS etapa_ordem "
            "FROM criterio c INNER JOIN etapa e ON e.id = c.etapa_id "
            "WHERE c.coordenacao_id = %s"
        )
        params = [coordenacao_id]
        if ano_letivo is not None:
            sql += " AND e.ano_letivo = %s"
            params.append(ano_letivo)
        sql += " ORDER BY e.ordem ASC, c.nome ASC"
        return query_all(sql, tuple(params))

    @staticmethod
    def find_by_id(criterio_id, coordenacao_id):
        return query_one(
            "SELECT %s FROM criterio WHERE id = %%s AND coordenacao_id = %%s"
            % _COLUNAS,
            (criterio_id, coordenacao_id),
        )

    @staticmethod
    def find_by_nome(etapa_id, nome):
        return query_one(
            "SELECT %s FROM criterio WHERE etapa_id = %%s AND nome = %%s"
            % _COLUNAS,
            (etapa_id, nome),
        )

    # -----------------------------------------------------------------
    # Escrita
    # -----------------------------------------------------------------
    @staticmethod
    def upsert(coordenacao_id, etapa_id, nome, peso=0, nota_maxima=10):
        """Cria o criterio, ou atualiza o que ja existe com aquele nome."""
        existente = Criterio.find_by_nome(etapa_id, nome)
        if existente:
            execute(
                "UPDATE criterio SET peso = %s, nota_maxima = %s WHERE id = %s",
                (peso, nota_maxima, existente["id"]),
            )
            return existente["id"]
        return insert(
            "INSERT INTO criterio "
            "(coordenacao_id, etapa_id, nome, peso, nota_maxima) "
            "VALUES (%s, %s, %s, %s, %s)",
            (coordenacao_id, etapa_id, nome, peso, nota_maxima),
        )

    @staticmethod
    def update(criterio_id, coordenacao_id, nome=None, peso=None,
               nota_maxima=None):
        campos = []
        valores = []
        for coluna, valor in (
            ("nome", nome), ("peso", peso), ("nota_maxima", nota_maxima)
        ):
            if valor is not None:
                campos.append("%s = %%s" % coluna)
                valores.append(valor)
        if not campos:
            return 0
        valores.extend([criterio_id, coordenacao_id])
        return execute(
            "UPDATE criterio SET %s WHERE id = %%s AND coordenacao_id = %%s"
            % ", ".join(campos),
            tuple(valores),
        )

    @staticmethod
    def delete(criterio_id, coordenacao_id):
        return execute(
            "DELETE FROM criterio WHERE id = %s AND coordenacao_id = %s",
            (criterio_id, coordenacao_id),
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
            "peso": numero(linha.get("peso")),
            "nota_maxima": numero(linha.get("nota_maxima")),
            "notaMaxima": numero(linha.get("nota_maxima")),
            "etapa_id": linha.get("etapa_id"),
            "etapaId": linha.get("etapa_id"),
            "etapa_nome": linha.get("etapa_nome"),
            "created_at": iso(linha.get("created_at")),
            "updated_at": iso(linha.get("updated_at")),
        }

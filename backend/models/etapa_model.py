"""Model da Etapa do ano letivo.

A etapa e configuracao PADRAO DA ESCOLA, nao de uma turma nem de um
professor. Por isso o upsert por (coordenacao_id, ano_letivo, ordem):
reconfigurar o ano letivo atualiza as etapas existentes em vez de criar
duplicatas a cada passagem pelo fluxo.
"""

from database.connection import execute, insert, query_all, query_one
from models.utils import booleano, iso, numero

_COLUNAS = (
    "id, coordenacao_id, nome, ordem, ano_letivo, data_inicio, data_fim, "
    "nota_minima, nota_maxima, ativa, created_at, updated_at"
)


class Etapa:
    TABELA = "etapa"

    # -----------------------------------------------------------------
    # Leitura
    # -----------------------------------------------------------------
    @staticmethod
    def find_all_by_coordenacao(coordenacao_id, ano_letivo=None):
        sql = "SELECT %s FROM etapa WHERE coordenacao_id = %%s" % _COLUNAS
        params = [coordenacao_id]
        if ano_letivo is not None:
            sql += " AND ano_letivo = %s"
            params.append(ano_letivo)
        sql += " ORDER BY ano_letivo DESC, ordem ASC"
        return query_all(sql, tuple(params))

    @staticmethod
    def find_by_id(etapa_id, coordenacao_id):
        return query_one(
            "SELECT %s FROM etapa WHERE id = %%s AND coordenacao_id = %%s"
            % _COLUNAS,
            (etapa_id, coordenacao_id),
        )

    @staticmethod
    def find_by_ordem(coordenacao_id, ano_letivo, ordem):
        return query_one(
            "SELECT %s FROM etapa "
            "WHERE coordenacao_id = %%s AND ano_letivo = %%s AND ordem = %%s"
            % _COLUNAS,
            (coordenacao_id, ano_letivo, ordem),
        )

    @staticmethod
    def nota_minima_da_escola(coordenacao_id, ano_letivo):
        """Menor nota minima configurada no ano. Usada para 'alunos em risco'."""
        linha = query_one(
            "SELECT MIN(nota_minima) AS minima FROM etapa "
            "WHERE coordenacao_id = %s AND ano_letivo = %s "
            "AND nota_minima IS NOT NULL",
            (coordenacao_id, ano_letivo),
        )
        return numero(linha["minima"]) if linha else None

    # -----------------------------------------------------------------
    # Escrita
    # -----------------------------------------------------------------
    @staticmethod
    def upsert(coordenacao_id, nome, ordem, ano_letivo, data_inicio=None,
               data_fim=None, ativa=True):
        """Cria a etapa, ou atualiza a que ja existe naquela ordem/ano.

        E o que faz a configuracao ser 'padrao da escola': passar pelo fluxo
        de novo reaproveita a etapa em vez de duplicar. As notas minima e
        maxima nao entram aqui de proposito, para nao serem zeradas por uma
        reconfiguracao - quem grava elas e definir_notas.
        """
        existente = Etapa.find_by_ordem(coordenacao_id, ano_letivo, ordem)
        if existente:
            execute(
                "UPDATE etapa SET nome = %s, data_inicio = %s, data_fim = %s, "
                "ativa = %s WHERE id = %s",
                (nome, data_inicio, data_fim, 1 if ativa else 0, existente["id"]),
            )
            return existente["id"]
        return insert(
            "INSERT INTO etapa "
            "(coordenacao_id, nome, ordem, ano_letivo, data_inicio, data_fim, ativa) "
            "VALUES (%s, %s, %s, %s, %s, %s, %s)",
            (coordenacao_id, nome, ordem, ano_letivo, data_inicio, data_fim,
             1 if ativa else 0),
        )

    @staticmethod
    def definir_notas(etapa_id, coordenacao_id, nota_minima, nota_maxima):
        return execute(
            "UPDATE etapa SET nota_minima = %s, nota_maxima = %s "
            "WHERE id = %s AND coordenacao_id = %s",
            (nota_minima, nota_maxima, etapa_id, coordenacao_id),
        )

    @staticmethod
    def update(etapa_id, coordenacao_id, nome=None, ordem=None, data_inicio=None,
               data_fim=None, ativa=None):
        campos = []
        valores = []
        for coluna, valor in (
            ("nome", nome),
            ("ordem", ordem),
            ("data_inicio", data_inicio),
            ("data_fim", data_fim),
        ):
            if valor is not None:
                campos.append("%s = %%s" % coluna)
                valores.append(valor)
        if ativa is not None:
            campos.append("ativa = %s")
            valores.append(1 if ativa else 0)
        if not campos:
            return 0
        valores.extend([etapa_id, coordenacao_id])
        return execute(
            "UPDATE etapa SET %s WHERE id = %%s AND coordenacao_id = %%s"
            % ", ".join(campos),
            tuple(valores),
        )

    @staticmethod
    def delete(etapa_id, coordenacao_id):
        return execute(
            "DELETE FROM etapa WHERE id = %s AND coordenacao_id = %s",
            (etapa_id, coordenacao_id),
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
            "ordem": linha["ordem"],
            "numero": linha["ordem"],
            "ano_letivo": linha.get("ano_letivo"),
            "anoLetivo": linha.get("ano_letivo"),
            "data_inicio": iso(linha.get("data_inicio")),
            "data_fim": iso(linha.get("data_fim")),
            "nota_minima": numero(linha.get("nota_minima")),
            "notaMinima": numero(linha.get("nota_minima")),
            "nota_maxima": numero(linha.get("nota_maxima")),
            "notaMaxima": numero(linha.get("nota_maxima")),
            "ativa": booleano(linha.get("ativa")),
            "created_at": iso(linha.get("created_at")),
            "updated_at": iso(linha.get("updated_at")),
        }

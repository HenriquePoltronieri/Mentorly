"""Model do Ano Letivo (Marco 6). SQL direto, sem ORM.

Cada escola tem os seus anos, e e este cadastro que diz quais existem e
qual e o atual. Turma e etapa guardam o numero do ano como FK composta
(coordenacao_id, ano_letivo) para ca, entao o banco nao deixa uma delas
apontar para um ano que a escola nao tem.

Nenhum metodo existe sem coordenacao_id: uma escola nunca ve nem altera o
ano de outra.
"""

import pymysql

from database.connection import execute, insert, query_all, query_one, transacao
from models.utils import iso

STATUS_VALIDOS = ("planejamento", "atual", "encerrado")

# atual_unico (coluna gerada do schema) fica de fora de proposito.
_COLUNAS = "id, coordenacao_id, ano, status, created_at, updated_at"


class AnoLetivo:
    TABELA = "ano_letivo"

    # -----------------------------------------------------------------
    # Leitura
    # -----------------------------------------------------------------
    @staticmethod
    def find_all_by_coordenacao(coordenacao_id):
        """Anos da escola, do mais novo para o mais antigo, com quantas turmas
        e etapas cada um ja tem (a tela usa isso para saber o que excluir)."""
        return query_all(
            "SELECT a.id, a.coordenacao_id, a.ano, a.status, "
            "       a.created_at, a.updated_at, "
            "       (SELECT COUNT(*) FROM turma t "
            "         WHERE t.coordenacao_id = a.coordenacao_id "
            "           AND t.ano_letivo = a.ano) AS total_turmas, "
            "       (SELECT COUNT(*) FROM etapa e "
            "         WHERE e.coordenacao_id = a.coordenacao_id "
            "           AND e.ano_letivo = a.ano) AS total_etapas "
            "FROM ano_letivo a WHERE a.coordenacao_id = %s "
            "ORDER BY a.ano DESC",
            (coordenacao_id,),
        )

    @staticmethod
    def find_by_id(ano_letivo_id, coordenacao_id):
        """Ano de outra escola vira None (404), como nos demais models."""
        return query_one(
            "SELECT %s FROM ano_letivo WHERE id = %%s AND coordenacao_id = %%s"
            % _COLUNAS,
            (ano_letivo_id, coordenacao_id),
        )

    @staticmethod
    def find_by_ano(coordenacao_id, ano):
        return query_one(
            "SELECT %s FROM ano_letivo WHERE coordenacao_id = %%s AND ano = %%s"
            % _COLUNAS,
            (coordenacao_id, ano),
        )

    @staticmethod
    def atual(coordenacao_id):
        """O ano atual da escola, ou None se nenhum estiver marcado."""
        return query_one(
            "SELECT %s FROM ano_letivo "
            "WHERE coordenacao_id = %%s AND status = 'atual'" % _COLUNAS,
            (coordenacao_id,),
        )

    @staticmethod
    def contar_dados(coordenacao_id, ano):
        """Quantas turmas e etapas dependem deste ano."""
        linha = query_one(
            "SELECT "
            "  (SELECT COUNT(*) FROM turma WHERE coordenacao_id = %s "
            "     AND ano_letivo = %s) AS turmas, "
            "  (SELECT COUNT(*) FROM etapa WHERE coordenacao_id = %s "
            "     AND ano_letivo = %s) AS etapas",
            (coordenacao_id, ano, coordenacao_id, ano),
        )
        return linha["turmas"], linha["etapas"]

    # -----------------------------------------------------------------
    # Escrita
    # -----------------------------------------------------------------
    @staticmethod
    def create(coordenacao_id, ano, status="planejamento"):
        try:
            return insert(
                "INSERT INTO ano_letivo (coordenacao_id, ano, status) "
                "VALUES (%s, %s, %s)",
                (coordenacao_id, ano, status),
            )
        except pymysql.err.IntegrityError:
            # Corrida entre duas requisicoes: o service ja checa antes, mas o
            # banco (unique do ano e unique do atual) e quem tem a ultima palavra.
            raise ValueError(
                "Nao foi possivel cadastrar: o ano ja existe ou ja ha um "
                "ano atual nesta escola"
            )

    @staticmethod
    def definir_status(ano_letivo_id, coordenacao_id, status):
        try:
            return execute(
                "UPDATE ano_letivo SET status = %s "
                "WHERE id = %s AND coordenacao_id = %s",
                (status, ano_letivo_id, coordenacao_id),
            )
        except pymysql.err.IntegrityError:
            raise ValueError("Ja existe um ano letivo atual nesta escola")

    @staticmethod
    def trocar_atual(coordenacao_id, ano_atual_id, novo_atual_id):
        """Encerra o atual e marca o novo, na mesma transacao.

        A ordem dentro dela importa: o indice unico do atual e conferido a
        cada comando, entao o antigo tem que sair do 'atual' antes de o novo
        entrar. Se o segundo falhar, o primeiro volta: a escola nunca fica
        sem ano atual por causa de uma troca que nao terminou.
        """
        with transacao() as cursor:
            cursor.execute(
                "UPDATE ano_letivo SET status = 'encerrado' "
                "WHERE id = %s AND coordenacao_id = %s",
                (ano_atual_id, coordenacao_id),
            )
            cursor.execute(
                "UPDATE ano_letivo SET status = 'atual' "
                "WHERE id = %s AND coordenacao_id = %s",
                (novo_atual_id, coordenacao_id),
            )

    @staticmethod
    def delete(ano_letivo_id, coordenacao_id):
        return execute(
            "DELETE FROM ano_letivo WHERE id = %s AND coordenacao_id = %s",
            (ano_letivo_id, coordenacao_id),
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
            "ano": linha["ano"],
            "status": linha["status"],
            "totalTurmas": linha.get("total_turmas"),
            "totalEtapas": linha.get("total_etapas"),
            "created_at": iso(linha.get("created_at")),
            "updated_at": iso(linha.get("updated_at")),
        }

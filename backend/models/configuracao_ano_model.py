"""Persistência atômica do assistente; preserva IDs e dados vinculados."""
from database.connection import transacao
from erros import RecursoNaoEncontrado


class ConfiguracaoAno:
    @staticmethod
    def salvar(coordenacao_id, ano, etapas, criterios):
        with transacao() as cursor:
            cursor.execute("SELECT status FROM ano_letivo WHERE coordenacao_id=%s AND ano=%s FOR UPDATE",
                           (coordenacao_id, ano))
            registro = cursor.fetchone()
            if not registro:
                raise RecursoNaoEncontrado("Ano letivo não encontrado nesta escola.")
            if registro["status"] == "encerrado":
                raise ValueError("O ano está encerrado e não permite alterações.")
            cursor.execute("SELECT id, ordem, fechada FROM etapa WHERE coordenacao_id=%s AND ano_letivo=%s FOR UPDATE",
                           (coordenacao_id, ano))
            existentes = cursor.fetchall()
            if any(e["fechada"] for e in existentes):
                raise ValueError("Há etapas fechadas. Peça ao professor para reabri-las antes de configurar.")
            por_ordem = {e["ordem"]: e for e in existentes}
            for ordem, etapa in enumerate(etapas, 1):
                anterior = por_ordem.get(ordem)
                if anterior:
                    etapa_id = anterior["id"]
                    cursor.execute("UPDATE etapa SET nome=%s, nota_minima=%s, nota_maxima=%s WHERE id=%s",
                                   (etapa["nome"], etapa["nota_minima"], etapa["nota_maxima"], etapa_id))
                else:
                    cursor.execute("INSERT INTO etapa (coordenacao_id, ano_letivo, ordem, nome, nota_minima, nota_maxima) "
                                   "VALUES (%s,%s,%s,%s,%s,%s)",
                                   (coordenacao_id, ano, ordem, etapa["nome"], etapa["nota_minima"], etapa["nota_maxima"]))
                    etapa_id = cursor.lastrowid
                # Colação do banco decide se o nome já existe (case/acento).
                ids = []
                for criterio in criterios:
                    cursor.execute("INSERT INTO criterio (coordenacao_id, etapa_id, nome, peso, nota_maxima) "
                                   "VALUES (%s,%s,%s,%s,10) ON DUPLICATE KEY UPDATE id=LAST_INSERT_ID(id), peso=VALUES(peso)",
                                   (coordenacao_id, etapa_id, criterio["nome"], criterio["peso"]))
                    ids.append(cursor.lastrowid)
                marcadores = ",".join(["%s"] * len(ids))
                cursor.execute("DELETE FROM criterio WHERE etapa_id=%s AND coordenacao_id=%s AND id NOT IN (" + marcadores + ")",
                               (etapa_id, coordenacao_id, *ids))
            # FKs impedem apagar etapa/critério usados: o rollback mantém tudo.
            cursor.execute("DELETE FROM etapa WHERE coordenacao_id=%s AND ano_letivo=%s AND ordem>%s",
                           (coordenacao_id, ano, len(etapas)))

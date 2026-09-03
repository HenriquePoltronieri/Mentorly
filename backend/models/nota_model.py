"""Model da Nota (uma por atividade + aluno). So o Professor lanca.

O lancamento usa INSERT ... ON DUPLICATE KEY UPDATE apoiado no indice
uk_nota_atividade_aluno: relancar a nota de um aluno corrige a existente
em vez de estourar erro de duplicata.
"""

from database.connection import execute, query_all, query_one, transacao
from models.utils import iso, numero


class Nota:
    TABELA = "nota"

    # -----------------------------------------------------------------
    # Leitura
    # -----------------------------------------------------------------
    @staticmethod
    def find_by_atividade(atividade_id):
        """Todos os alunos da turma da atividade, com a nota se ja existir.

        LEFT JOIN a partir de aluno para a tela de lancamento mostrar
        tambem quem ainda nao tem nota.
        """
        return query_all(
            "SELECT al.id AS aluno_id, al.nome AS aluno_nome, al.matricula, "
            "       n.id AS nota_id, n.valor, n.observacao, n.updated_at "
            "FROM atividade a "
            "INNER JOIN aluno al ON al.turma_id = a.turma_id "
            "LEFT JOIN nota n ON n.aluno_id = al.id AND n.atividade_id = a.id "
            "WHERE a.id = %s "
            "ORDER BY al.nome ASC",
            (atividade_id,),
        )

    @staticmethod
    def find_by_aluno(aluno_id):
        """Historico do aluno, por atividade e etapa. Base das estatisticas."""
        return query_all(
            "SELECT n.id, n.valor, n.observacao, n.updated_at, "
            "       a.id AS atividade_id, a.titulo AS atividade, "
            "       a.data_entrega, a.nota_maxima, "
            "       e.id AS etapa_id, e.nome AS etapa_nome, e.ordem AS etapa_ordem, "
            "       e.nota_minima "
            "FROM nota n "
            "INNER JOIN atividade a ON a.id = n.atividade_id "
            "LEFT JOIN etapa e ON e.id = a.etapa_id "
            "WHERE n.aluno_id = %s "
            "ORDER BY e.ordem ASC, a.data_entrega ASC, a.id ASC",
            (aluno_id,),
        )

    @staticmethod
    def media_do_aluno(aluno_id):
        linha = query_one(
            "SELECT ROUND(AVG(valor), 2) AS media, COUNT(*) AS total "
            "FROM nota WHERE aluno_id = %s",
            (aluno_id,),
        )
        if not linha:
            return {"media": None, "total": 0}
        return {"media": numero(linha["media"]), "total": linha["total"]}

    @staticmethod
    def media_por_atividade(turma_id):
        """Media da turma em cada atividade, da pior para a melhor."""
        return query_all(
            "SELECT a.id AS atividade_id, a.titulo AS atividade, "
            "       ROUND(AVG(n.valor), 2) AS media, COUNT(n.id) AS total_notas "
            "FROM atividade a LEFT JOIN nota n ON n.atividade_id = a.id "
            "WHERE a.turma_id = %s "
            "GROUP BY a.id, a.titulo "
            "HAVING COUNT(n.id) > 0 "
            "ORDER BY media ASC",
            (turma_id,),
        )

    # -----------------------------------------------------------------
    # Escrita
    # -----------------------------------------------------------------
    @staticmethod
    def lancar(atividade_id, aluno_id, valor, observacao=None):
        return execute(
            "INSERT INTO nota (atividade_id, aluno_id, valor, observacao) "
            "VALUES (%s, %s, %s, %s) "
            "ON DUPLICATE KEY UPDATE valor = VALUES(valor), "
            "observacao = VALUES(observacao)",
            (atividade_id, aluno_id, valor, observacao),
        )

    @staticmethod
    def lancar_em_lote(atividade_id, notas):
        """Lanca varias notas em uma transacao so.

        notas: lista de dicts com aluno_id, valor e observacao opcional.
        """
        with transacao() as cursor:
            for nota in notas:
                cursor.execute(
                    "INSERT INTO nota (atividade_id, aluno_id, valor, observacao) "
                    "VALUES (%s, %s, %s, %s) "
                    "ON DUPLICATE KEY UPDATE valor = VALUES(valor), "
                    "observacao = VALUES(observacao)",
                    (atividade_id, nota["aluno_id"], nota["valor"],
                     nota.get("observacao")),
                )
        return len(notas)

    @staticmethod
    def delete(nota_id):
        return execute("DELETE FROM nota WHERE id = %s", (nota_id,))

    # -----------------------------------------------------------------
    # Serializacao
    # -----------------------------------------------------------------
    @staticmethod
    def to_dict(linha):
        if not linha:
            return None
        return {
            "id": linha.get("id") or linha.get("nota_id"),
            "alunoId": linha.get("aluno_id"),
            "aluno": linha.get("aluno_nome"),
            "matricula": linha.get("matricula"),
            "atividadeId": linha.get("atividade_id"),
            "atividade": linha.get("atividade"),
            "valor": numero(linha.get("valor")),
            "nota": numero(linha.get("valor")),
            "notaMaxima": numero(linha.get("nota_maxima")),
            "observacao": linha.get("observacao"),
            "etapaId": linha.get("etapa_id"),
            "etapa": linha.get("etapa_nome"),
            "dataEntrega": iso(linha.get("data_entrega")),
            "updated_at": iso(linha.get("updated_at")),
        }

"""Historico de matriculas por turma, com SQL direto."""

from database.connection import query_all, transacao
from models.utils import iso
from erros import RecursoNaoEncontrado


class AlunoTurmaHistorico:
    @staticmethod
    def find_by_aluno(aluno_id):
        return query_all(
            "SELECT h.id, h.aluno_id, h.turma_id, h.ano_letivo, h.data_inicio, "
            "       h.data_fim, h.motivo, t.nome AS turma_nome "
            "FROM aluno_turma_historico h "
            "INNER JOIN turma t ON t.id = h.turma_id "
            "WHERE h.aluno_id = %s "
            "ORDER BY h.data_inicio DESC, h.id DESC",
            (aluno_id,),
        )

    @staticmethod
    def transferir(aluno_id, coordenacao_id, turma_destino_id, motivo=None):
        """Fecha o vinculo atual, abre outro e sincroniza aluno.turma_id."""
        with transacao() as cursor:
            cursor.execute(
                "SELECT al.id, al.turma_id, t.coordenacao_id, al.created_at "
                "FROM aluno al INNER JOIN turma t ON t.id = al.turma_id "
                "WHERE al.id = %s FOR UPDATE", (aluno_id,))
            aluno = cursor.fetchone()
            if not aluno or aluno["coordenacao_id"] != coordenacao_id:
                raise RecursoNaoEncontrado("Aluno nao encontrado")

            cursor.execute(
                "SELECT t.id, t.coordenacao_id, t.ano_letivo, a.status "
                "FROM turma t INNER JOIN ano_letivo a "
                " ON a.coordenacao_id = t.coordenacao_id AND a.ano = t.ano_letivo "
                "WHERE t.id = %s FOR UPDATE", (turma_destino_id,))
            destino = cursor.fetchone()
            if not destino or destino["coordenacao_id"] != coordenacao_id:
                raise RecursoNaoEncontrado("Turma de destino nao encontrada")
            if destino["status"] == "encerrado":
                raise ValueError("Nao e possivel transferir para turma de ano letivo encerrado")
            if aluno["turma_id"] == turma_destino_id:
                raise ValueError("O aluno ja pertence a esta turma")

            cursor.execute(
                "SELECT id, turma_id FROM aluno_turma_historico "
                "WHERE aluno_id = %s AND data_fim IS NULL FOR UPDATE", (aluno_id,))
            atual = cursor.fetchone()
            if atual and atual["turma_id"] != aluno["turma_id"]:
                raise ValueError("Historico da turma atual do aluno esta inconsistente")
            if not atual:
                cursor.execute(
                    "INSERT INTO aluno_turma_historico "
                    "(aluno_id, coordenacao_id, turma_id, ano_letivo, data_inicio) "
                    "SELECT al.id, t.coordenacao_id, al.turma_id, t.ano_letivo, "
                    "COALESCE(DATE(al.created_at), CURDATE()) "
                    "FROM aluno al INNER JOIN turma t ON t.id = al.turma_id "
                    "WHERE al.id = %s", (aluno_id,))

            cursor.execute(
                "UPDATE aluno_turma_historico SET data_fim = CURDATE() "
                "WHERE aluno_id = %s AND data_fim IS NULL", (aluno_id,))
            cursor.execute(
                "INSERT INTO aluno_turma_historico "
                "(aluno_id, coordenacao_id, turma_id, ano_letivo, data_inicio, motivo) "
                "VALUES (%s, %s, %s, %s, CURDATE(), %s)",
                (aluno_id, coordenacao_id, turma_destino_id,
                 destino["ano_letivo"], motivo))
            cursor.execute("UPDATE aluno SET turma_id = %s WHERE id = %s",
                           (turma_destino_id, aluno_id))

    @staticmethod
    def to_dict(linha):
        return {
            "id": linha["id"], "turmaId": linha["turma_id"],
            "turma": linha["turma_nome"], "anoLetivo": linha["ano_letivo"],
            "dataInicio": iso(linha["data_inicio"]),
            "dataFim": iso(linha.get("data_fim")), "motivo": linha.get("motivo"),
            "atual": linha.get("data_fim") is None,
        }

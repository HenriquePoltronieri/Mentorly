"""Model do vinculo Professor x Turma, criado pela Coordenacao.

O INSERT sempre grava a coordenacao_id junto. As FKs compostas do schema
fazem o MySQL recusar qualquer combinacao que cruze escolas, entao mesmo
um bug no service nao consegue misturar dados de coordenacoes diferentes.
"""

from database.connection import execute, query_all, query_one, transacao


class ProfessorTurma:
    TABELA = "professor_turma"

    @staticmethod
    def turmas_do_professor(professor_id):
        return query_all(
            "SELECT t.id, t.coordenacao_id, t.nome, t.descricao, t.disciplina, "
            "       t.turno, t.ano_letivo, t.created_at, t.updated_at, "
            "       (SELECT COUNT(*) FROM aluno al WHERE al.turma_id = t.id) "
            "           AS total_alunos "
            "FROM turma t "
            "INNER JOIN professor_turma pt ON pt.turma_id = t.id "
            "WHERE pt.professor_id = %s "
            "ORDER BY t.nome ASC",
            (professor_id,),
        )

    @staticmethod
    def professores_da_turma(turma_id, coordenacao_id):
        return query_all(
            "SELECT p.id, p.nome, p.email, p.disciplina "
            "FROM professor p "
            "INNER JOIN professor_turma pt ON pt.professor_id = p.id "
            "WHERE pt.turma_id = %s AND pt.coordenacao_id = %s "
            "ORDER BY p.nome ASC",
            (turma_id, coordenacao_id),
        )

    @staticmethod
    def professor_leciona_na_turma(professor_id, turma_id):
        """Guarda usada por todo endpoint do professor que recebe turma_id."""
        return query_one(
            "SELECT id FROM professor_turma "
            "WHERE professor_id = %s AND turma_id = %s",
            (professor_id, turma_id),
        ) is not None

    @staticmethod
    def definir_turmas(coordenacao_id, professor_id, turma_ids):
        """Substitui o conjunto de turmas do professor em uma transacao so.

        Fazer DELETE + INSERT fora de transacao deixaria o professor sem
        nenhuma turma se o INSERT falhasse no meio.
        """
        with transacao() as cursor:
            cursor.execute(
                "DELETE FROM professor_turma "
                "WHERE professor_id = %s AND coordenacao_id = %s",
                (professor_id, coordenacao_id),
            )
            for turma_id in turma_ids:
                cursor.execute(
                    "INSERT INTO professor_turma "
                    "(coordenacao_id, professor_id, turma_id) VALUES (%s, %s, %s)",
                    (coordenacao_id, professor_id, turma_id),
                )
        return len(turma_ids)

    @staticmethod
    def desvincular(coordenacao_id, professor_id, turma_id):
        return execute(
            "DELETE FROM professor_turma "
            "WHERE coordenacao_id = %s AND professor_id = %s AND turma_id = %s",
            (coordenacao_id, professor_id, turma_id),
        )

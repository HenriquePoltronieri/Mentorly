"""Consultas de relatorio e busca, com resultados prontos para JSON."""

from database.procedure import call_procedure
from database.connection import query_all, query_one
from models.utils import normalizar, normalizar_lista


def buscar_atividades(coordenacao_id, professor_id=None, termo=None,
                     ordenar_por=None, direcao=None):
    # Professor recebe apenas atividades de suas turmas; coordenacao, da escola.
    return normalizar_lista(call_procedure(
        "sp_buscar_atividades",
        coordenacao_id, professor_id, termo, ordenar_por, direcao,
    ))


def professores_por_coordenacao(coordenacao_id):
    return normalizar_lista(
        call_procedure("sp_professores_por_coordenacao", coordenacao_id)
    )


def resumo_da_escola(coordenacao_id):
    # Apenas dados administrativos; nenhuma atividade ou nota é retornada.
    return query_one(
        "SELECT (SELECT COUNT(*) FROM professor WHERE coordenacao_id=%s) AS total_professores, "
        "(SELECT COUNT(*) FROM turma WHERE coordenacao_id=%s) AS total_turmas, "
        "(SELECT COUNT(*) FROM aluno a JOIN turma t ON t.id=a.turma_id WHERE t.coordenacao_id=%s) AS total_alunos, "
        "(SELECT COUNT(*) FROM professor WHERE coordenacao_id=%s AND senha_hash IS NULL AND habilitado=1) AS convites_pendentes",
        (coordenacao_id,) * 4,
    )


def relatorio_turmas_atividades(coordenacao_id, professor_id):
    if professor_id is None:
        return query_all(
            "SELECT t.id, t.nome AS turma, COUNT(a.id) AS total_atividades "
            "FROM turma t LEFT JOIN atividade a ON a.turma_id=t.id "
            "WHERE t.coordenacao_id=%s GROUP BY t.id, t.nome ORDER BY t.nome",
            (coordenacao_id,),
        )
    return query_all(
        "SELECT t.id, t.nome AS turma, COUNT(a.id) AS total_atividades "
        "FROM turma t INNER JOIN professor_turma pt ON pt.turma_id=t.id "
        "LEFT JOIN atividade a ON a.turma_id=t.id "
        "WHERE pt.professor_id=%s AND t.coordenacao_id=%s "
        "GROUP BY t.id, t.nome ORDER BY t.nome",
        (professor_id, coordenacao_id),
    )


def turmas_do_professor(professor_id):
    return normalizar_lista(
        call_procedure("sp_turmas_do_professor", professor_id)
    )

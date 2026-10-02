"""Consultas de relatorio e busca, com resultados prontos para JSON."""

from database.procedure import call_procedure
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
    linhas = call_procedure("sp_resumo_sistema", coordenacao_id)
    return normalizar(linhas[0]) if linhas else {}


def relatorio_turmas_atividades(coordenacao_id):
    return normalizar_lista(
        call_procedure("sp_relatorio_turmas_atividades", coordenacao_id)
    )


def turmas_do_professor(professor_id):
    return normalizar_lista(
        call_procedure("sp_turmas_do_professor", professor_id)
    )

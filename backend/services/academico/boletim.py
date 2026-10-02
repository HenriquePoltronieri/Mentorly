"""Boletim da turma: desempenho de cada aluno, etapa por etapa.

Reaproveita o motor central (calculo.py) uma vez por aluno - nao recalcula
nada por conta propria, so agrega o resultado de cada um. Professor e
Coordenacao chegam aqui por controllers diferentes, mas os dois usam esta
mesma funcao; quem valida se o usuario pode ver a turma e o controller
(turma_acessivel / Turma.find_by_id_para_professor), nao esta funcao.
"""

from models.aluno_model import Aluno
from services.academico.calculo import calcular_consolidado_geral, calcular_todas_etapas


def montar_boletim_turma(turma, coordenacao_id):
    """turma: dict com id e ano_letivo (toda turma tem ano, desde o Marco 6).

    O boletim usa as etapas do ano da PROPRIA turma: turma de 2025 nunca
    recebe etapa de 2026, nem o contrario.
    """
    ano_letivo = turma["ano_letivo"]

    boletim = []
    for linha in Aluno.find_all_by_turma(turma["id"]):
        etapas = calcular_todas_etapas(
            linha["id"], turma["id"], coordenacao_id, ano_letivo
        )
        boletim.append({
            "aluno_id": linha["id"],
            "aluno": linha["nome"],
            "matricula": linha.get("matricula"),
            "etapas": etapas,
            "consolidado": calcular_consolidado_geral(etapas),
        })
    return {
        "turma_id": turma["id"],
        "ano_letivo": ano_letivo,
        "alunos": boletim,
    }

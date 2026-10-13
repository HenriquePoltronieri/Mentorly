"""Dados de uma turma em lote, usados pelo mesmo motor acadêmico."""
from database.connection import query_all
from models.etapa_model import Etapa
from models.criterio_model import Criterio


def carregar_dados_turma(turma_id, coordenacao_id, ano):
    dados = {"etapas": Etapa.find_all_by_coordenacao(coordenacao_id, ano),
             "criterios": {}, "atividades": {}, "notas": {}}
    for criterio in Criterio.find_all_by_coordenacao(coordenacao_id, ano):
        dados["criterios"].setdefault(criterio["etapa_id"], []).append(criterio)
    for atividade in query_all(
        "SELECT id, etapa_id, criterio_id, nota_maxima FROM atividade WHERE turma_id=%s AND coordenacao_id=%s",
        (turma_id, coordenacao_id),
    ):
        dados["atividades"].setdefault((atividade["etapa_id"], atividade["criterio_id"]), []).append(atividade)
    for nota in query_all(
        "SELECT n.aluno_id, n.atividade_id, n.valor FROM nota n JOIN atividade a ON a.id=n.atividade_id "
        "JOIN aluno al ON al.id=n.aluno_id WHERE a.turma_id=%s AND a.coordenacao_id=%s AND al.turma_id=%s",
        (turma_id, coordenacao_id, turma_id),
    ):
        dados["notas"].setdefault(nota["aluno_id"], {})[nota["atividade_id"]] = nota["valor"]
    return dados

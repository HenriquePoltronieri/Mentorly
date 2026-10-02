from models.nota_model import Nota
from services.academico.calculo import (
    calcular_consolidado_geral,
    calcular_todas_etapas,
    etapa_atual,
)
from services.aluno.acesso_turma import aluno_acessivel


class EstatisticasAlunoService:
    """Desempenho de um aluno: uma etapa por vez, calculado pela regra
    central (services/academico/calculo.py) - nunca um valor inventado.

    So responde se o aluno estiver em uma turma vinculada ao professor
    logado - caso contrario levanta LookupError (404).
    """

    def execute(self, aluno_id, coordenacao_id, professor_id):
        aluno = aluno_acessivel(aluno_id, coordenacao_id, professor_id)
        # Ano da turma do aluno: o desempenho e sempre de UM ano letivo.
        ano_letivo = aluno["ano_letivo"]

        etapas = calcular_todas_etapas(
            aluno_id, aluno["turma_id"], coordenacao_id, ano_letivo
        )
        consolidado = calcular_consolidado_geral(etapas)
        atual, regra_etapa_atual = etapa_atual(coordenacao_id, ano_letivo)

        # Media bruta (nao pondera por criterio, nao converte de escala):
        # mantida por compatibilidade com quem so quer um numero rapido.
        # O dado que importa de verdade agora e "etapas", calculado pela
        # regra ponderada.
        # A turma atual delimita o contexto: notas de turma anterior ficam
        # preservadas, mas nao entram no desempenho da turma nova.
        notas = Nota.find_by_aluno(aluno_id, aluno["turma_id"])
        resumo = Nota.media_do_aluno(aluno_id, aluno["turma_id"])

        return {
            "id": aluno["id"],
            "nome": aluno["nome"],
            "matricula": aluno.get("matricula"),
            "turma": aluno.get("turma_nome"),
            "turmaId": aluno.get("turma_id"),
            "anoLetivo": ano_letivo,
            "media": resumo["media"],
            "totalNotas": resumo["total"],
            "etapas": etapas,
            "consolidado": consolidado,
            "etapaAtualId": atual["id"] if atual else None,
            "regraEtapaAtual": regra_etapa_atual,
            # Lista plana, para o grafico que ja existe no app.
            "notas": [Nota.to_dict(linha) for linha in notas],
        }

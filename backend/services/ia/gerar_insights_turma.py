"""Caso de uso de insights da etapa atual de uma turma do Professor."""

from collections import defaultdict

from models.aluno_model import Aluno
from models.turma_model import Turma
from services.academico.calculo import calcular_desempenho_etapa, etapa_atual
from services.ia.client import AIClient


MAX_DETALHES_ALUNOS = 50


class DadosInsuficientesError(ValueError):
    pass


def _texto_seguro(valor, limite=80):
    """Remove controles/delimitadores de strings que vao para o prompt."""
    limpo = " ".join(str(valor or "").replace("<", " ").replace(">", " ").split())
    return limpo[:limite]


def _primeiro_nome(nome):
    partes = _texto_seguro(nome).split()
    return partes[0] if partes else "Aluno"


def _media(valores):
    return round(sum(valores) / len(valores), 2) if valores else None


class GerarInsightsTurmaService:
    def __init__(self, client=None):
        self.client = client or AIClient()

    def execute(self, turma_id, professor_id, coordenacao_id):
        turma = Turma.find_by_id_para_professor(turma_id, professor_id)
        if not turma or turma.get("coordenacao_id") != coordenacao_id:
            raise LookupError("Turma nao encontrada")

        etapa, regra_etapa = etapa_atual(coordenacao_id, turma["ano_letivo"])
        if not etapa:
            raise DadosInsuficientesError(
                "A turma ainda nao possui uma etapa atual configurada."
            )

        alunos = Aluno.find_all_by_turma(turma_id)
        if not alunos:
            raise DadosInsuficientesError(
                "A turma ainda nao possui alunos para analisar."
            )

        calculados = []
        por_criterio = defaultdict(list)
        for aluno in alunos:
            resultado = calcular_desempenho_etapa(aluno["id"], turma_id, etapa)
            criterios = []
            for criterio in resultado["criterios"]:
                percentual = criterio.get("desempenho_percentual")
                if percentual is not None:
                    por_criterio[criterio["criterio"]].append(percentual)
                criterios.append({
                    "nome": _texto_seguro(criterio["criterio"]),
                    "peso": criterio.get("peso"),
                    "desempenhoPercentual": percentual,
                    "completo": criterio.get("completo", False),
                    "atividadesAvaliadas": criterio.get("atividades_avaliadas", 0),
                    "totalAtividades": criterio.get("total_atividades", 0),
                })
            calculados.append({
                "nome": _primeiro_nome(aluno["nome"]),
                "percentual": resultado.get("percentual"),
                "notaCalculada": resultado.get("nota_calculada"),
                "situacao": resultado.get("situacao"),
                "completo": resultado.get("completo", False),
                "atividadesAvaliadas": resultado.get("atividades_avaliadas", 0),
                "atividadesSemNota": resultado.get("atividades_sem_nota", 0),
                "criterios": criterios,
            })

        if not any(
            criterio["desempenhoPercentual"] is not None
            for aluno in calculados for criterio in aluno["criterios"]
        ):
            raise DadosInsuficientesError(
                "Ainda nao ha notas suficientes na etapa atual para gerar insights."
            )

        prioridade = {"abaixo_do_minimo": 0, "em_andamento": 1, "adequado": 2}
        detalhes = sorted(
            calculados,
            key=lambda item: (
                prioridade.get(item["situacao"], 3),
                item["percentual"] if item["percentual"] is not None else 101,
                item["nome"].casefold(),
            ),
        )[:MAX_DETALHES_ALUNOS]
        percentuais = [
            item["percentual"] for item in calculados
            if item["percentual"] is not None
        ]
        agregados_criterios = [
            {"nome": _texto_seguro(nome), "desempenhoMedioPercentual": _media(valores)}
            for nome, valores in sorted(por_criterio.items())
        ]
        payload = {
            "turma": {
                "nome": _texto_seguro(turma["nome"]),
                "anoLetivo": turma["ano_letivo"],
                "etapa": _texto_seguro(etapa["nome"]),
                "regraEtapaAtual": regra_etapa,
                "notaMinima": etapa.get("nota_minima"),
                "notaMaxima": etapa.get("nota_maxima"),
            },
            "resumoNumerico": {
                "totalAlunos": len(calculados),
                "alunosComResultado": len(percentuais),
                "percentualMedio": _media(percentuais),
                "abaixoDoMinimo": sum(
                    1 for item in calculados
                    if item["situacao"] == "abaixo_do_minimo"
                ),
                "adequados": sum(
                    1 for item in calculados if item["situacao"] == "adequado"
                ),
                "emAndamento": sum(
                    1 for item in calculados
                    if item["situacao"] == "em_andamento"
                ),
                "criterios": agregados_criterios,
            },
            "alunos": detalhes,
            "detalhesIndividuaisLimitados": len(calculados) > MAX_DETALHES_ALUNOS,
        }
        insights = self.client.gerar(payload)
        return {
            "contexto": {
                "turma": turma["nome"],
                "anoLetivo": turma["ano_letivo"],
                "etapa": etapa["nome"],
            },
            "geradoPorIA": True,
            "modelo": self.client.model,
            "insights": insights,
        }

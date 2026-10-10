"""Caso de uso de insights da etapa atual de uma turma do Professor.

Privacidade (M-09): o provedor externo NUNCA recebe nome, primeiro nome,
sobrenome, matricula, e-mail ou id de aluno. Cada aluno do payload e uma
referencia neutra ("Aluno 1", "Aluno 2"...), atribuida pelo proprio Mentorly na
ordem da priorizacao. O mapa referencia -> nome fica so neste processo: depois
que a resposta volta, o Mentorly troca as referencias pelo nome de exibicao
(primeiro nome) antes de entregar o texto ao Professor. A IA nao participa do
mapeamento e nunca ve o mapa.
"""

import re
from collections import defaultdict

from models.aluno_model import Aluno
from models.turma_model import Turma
from services.academico.calculo import calcular_desempenho_etapa, etapa_atual
from services.ia.client import MENSAGEM_INDISPONIVEL, AIClient, AIResponseError
from erros import RecursoNaoEncontrado


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


def _nomes_de_exibicao(nomes_completos):
    """Nome mostrado ao Professor no lugar de cada referencia (so uso local).

    Primeiro nome; se dois alunos do conjunto tem o mesmo primeiro nome, ganham
    a inicial do ultimo sobrenome ("Ana S.") para a observacao nao ficar
    ambigua. Se ainda assim colidir, usa o nome completo.
    """
    primeiros = [_primeiro_nome(nome) for nome in nomes_completos]
    resultado = []
    for nome, primeiro in zip(nomes_completos, primeiros):
        if primeiros.count(primeiro) == 1:
            resultado.append(primeiro)
            continue
        partes = _texto_seguro(nome).split()
        resultado.append(
            "%s %s." % (primeiro, partes[-1][0].upper()) if len(partes) > 1
            else primeiro
        )
    return [
        exibicao if resultado.count(exibicao) == 1
        else (_texto_seguro(nome) or exibicao)
        for nome, exibicao in zip(nomes_completos, resultado)
    ]


# "Aluno 7", "aluno 10": o numero e lido inteiro (\d+), entao "Aluno 10" nunca
# vira "Aluno 1" + "0"; \b impede casar dentro de outra palavra.
_REFERENCIA = re.compile(r"\bAluno\s+(\d+)\b", re.IGNORECASE)
_PLURAL = re.compile(r"\bAlunos\s+\d+\b", re.IGNORECASE)


def _trocar_referencias(texto, mapa):
    # Confere o texto ORIGINAL da IA (o nome real de um aluno pode, por acaso,
    # parecer uma referencia): referencia nao atribuida pelo Mentorly, ou plural
    # ("Alunos 1 e 2"), nao e exibida; a resposta e tratada como invalida.
    for achado in _REFERENCIA.finditer(texto):
        if int(achado.group(1)) not in mapa:
            raise AIResponseError(MENSAGEM_INDISPONIVEL)
    if _PLURAL.search(texto):
        raise AIResponseError(MENSAGEM_INDISPONIVEL)
    return _REFERENCIA.sub(lambda achado: mapa[int(achado.group(1))], texto)


def remapear_insights(insights, mapa):
    """Troca as referencias da resposta pelos nomes de exibicao (substituicao exata)."""
    def t(texto):
        return _trocar_referencias(texto, mapa)

    return {
        "resumo": t(insights["resumo"]),
        "pontosPositivos": [t(item) for item in insights["pontosPositivos"]],
        "pontosAtencao": [
            {chave: t(valor) for chave, valor in ponto.items()}
            for ponto in insights["pontosAtencao"]
        ],
        "sugestoesGerais": [t(item) for item in insights["sugestoesGerais"]],
    }


def _media(valores):
    return round(sum(valores) / len(valores), 2) if valores else None


class GerarInsightsTurmaService:
    def __init__(self, client=None):
        self.client = client or AIClient()

    def execute(self, turma_id, professor_id, coordenacao_id):
        turma = Turma.find_by_id_para_professor(turma_id, professor_id)
        if not turma or turma.get("coordenacao_id") != coordenacao_id:
            raise RecursoNaoEncontrado("Turma nao encontrada")

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
                # Chaves com "_" sao locais: nunca vao para o provedor.
                "_nome_completo": aluno["nome"],
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
                _primeiro_nome(item["_nome_completo"]).casefold(),
            ),
        )[:MAX_DETALHES_ALUNOS]
        # Pseudonimos na ordem da priorizacao; o mapa fica so aqui.
        exibicao = _nomes_de_exibicao([item["_nome_completo"] for item in detalhes])
        mapa_nomes = {}
        alunos_payload = []
        for numero, (item, nome) in enumerate(zip(detalhes, exibicao), start=1):
            mapa_nomes[numero] = nome
            alunos_payload.append({
                "referencia": "Aluno %d" % numero,
                **{k: v for k, v in item.items() if not k.startswith("_")},
            })
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
            "alunos": alunos_payload,
            "detalhesIndividuaisLimitados": len(calculados) > MAX_DETALHES_ALUNOS,
        }
        insights = remapear_insights(self.client.gerar(payload), mapa_nomes)
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

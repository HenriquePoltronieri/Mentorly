"""Alertas no fim da etapa, usando os pesos e as atividades cadastradas.

Projeções não substituem o boletim: novas atividades/recuperações podem mudar
o resultado. Sem nota mantém todos os pontos possíveis, nunca vira zero.
"""
from datetime import date
from services.academico.calculo import resumo_pesos, TOLERANCIA_NOTA


def _data(valor):
    return date.fromisoformat(str(valor)[:10]) if valor else None


def acompanhar_etapa(etapa, criterios, atividades, hoje):
    inicio, fim = _data(etapa.get("data_inicio")), _data(etapa.get("data_fim"))
    progresso = None
    if inicio and fim and fim > inicio:
        progresso = max(0, min(1, (hoje - inicio).days / (fim - inicio).days))
    final = bool(etapa.get("fechada")) or (progresso is not None and progresso >= .8)
    # Sem início, só há referência segura nos 14 dias anteriores ao término.
    if fim and not inicio:
        final = (fim - hoje).days <= 14 or final
    avaliadas = [a for a in atividades if a["nota"] is not None and a["nota_maxima"]]
    base = {"etapa_id": etapa["id"], "etapa": etapa["nome"],
            "fase": "final" if final else "em_andamento", "progresso": round(progresso * 100, 1) if progresso is not None else None,
            "fechada": bool(etapa.get("fechada")),
            "pontos_obtidos": round(sum(a["nota"] for a in avaliadas), 2) if avaliadas else None,
            "pontos_avaliados": round(sum(a["nota_maxima"] for a in avaliadas), 2) if avaliadas else None,
            "nota_minima": float(etapa["nota_minima"]) if etapa.get("nota_minima") is not None else None,
            "nota_maxima": float(etapa["nota_maxima"]) if etapa.get("nota_maxima") is not None else None,
            "pontos_ponderados": None, "pontos_restantes": None, "pontos_faltantes": None,
            "cobertura_avaliada": None, "risco": "Sem dados", "motivos": []}
    _, valido = resumo_pesos(criterios)
    if not valido or base["nota_minima"] is None or not base["nota_maxima"] or any(
        a.get("criterio_id") not in {c["id"] for c in criterios} or not a["nota_maxima"] for a in atividades
    ):
        base["motivos"] = ["Confira a configuração dos critérios e da escala da etapa antes de avaliar o risco."]
        return base
    obtidos = restantes = cobertura = 0
    for criterio in criterios:
        peso = float(criterio.get("peso") or 0) / 100
        if peso <= 0:
            continue
        lista = [a for a in atividades if a.get("criterio_id") == criterio["id"]]
        total = sum(a["nota_maxima"] for a in lista)
        parcela = peso * base["nota_maxima"]
        if total <= 0:
            restantes += parcela
            continue
        notas = [a for a in lista if a["nota"] is not None]
        avaliado = sum(a["nota_maxima"] for a in notas)
        obtidos += sum(a["nota"] for a in notas) / total * parcela
        restantes += (total - avaliado) / total * parcela
        cobertura += avaliado / total * peso
    base.update(pontos_ponderados=round(obtidos, 2), pontos_restantes=round(restantes, 2),
                pontos_faltantes=round(max(0, base["nota_minima"] - obtidos), 2),
                cobertura_avaliada=round(cobertura * 100, 1))
    if cobertura <= 0:
        return base
    if not final:
        base["risco"] = "Em andamento"
        base["motivos"] = ["Etapa em andamento: acompanhe as dificuldades sem antecipar risco de nota."]
    elif obtidos >= base["nota_minima"] - TOLERANCIA_NOTA:
        base["risco"] = "Baixo"
    elif obtidos + restantes < base["nota_minima"] - TOLERANCIA_NOTA:
        base["risco"] = "Alto"
        base["motivos"] = ["Etapa no período final: os pontos possíveis nas atividades cadastradas não alcançam o mínimo. Avalie reforço e recuperação."]
    elif cobertura >= .8 and obtidos / cobertura < base["nota_minima"] - TOLERANCIA_NOTA:
        base["risco"] = "Médio"
        base["motivos"] = ["Etapa no período final: desempenho abaixo do mínimo nas avaliações lançadas, com pontos ainda disponíveis para recuperação."]
    else:
        base["risco"] = "Em andamento"
        base["motivos"] = ["Ainda há avaliações ou lançamentos pendentes; confira os dados antes de emitir um alerta de nota."]
    return base

"""Calculo central usado pelo dashboard e pelo detalhe do aluno.

Desempenho = pontos obtidos / pontos possiveis nas atividades avaliadas.
A contribuicao considera o peso percentual de cada criterio; a soma das
contribuicoes, dividida por 100, multiplica a nota maxima da etapa.

Nota ausente nao e zero. A etapa so recebe resultado quando todos os
criterios com peso positivo estao completos e seus pesos somam 100.
"""

from models.atividade_model import Atividade
from models.criterio_model import Criterio
from models.etapa_model import Etapa
from models.nota_model import Nota
from models.utils import numero

TOLERANCIA_PESO = 0.01


def resumo_pesos(criterios):
    """Soma os pesos ATIVOS (peso > 0) e diz se a etapa pode ser calculada.

    Uma etapa sem nenhum criterio, ou so com criterios de peso 0, nunca e
    valida - nao ha o que calcular. criterios: lista de dict com "peso".
    """
    ativos = [c for c in criterios if (c.get("peso") or 0) > 0]
    soma = sum(float(c.get("peso") or 0) for c in ativos)
    valido = bool(ativos) and abs(soma - 100.0) <= TOLERANCIA_PESO
    return round(soma, 2), valido


def _calcular_criterio(aluno_id, turma_id, etapa_id, criterio):
    """Criterio sem atividade ou com nota pendente permanece incompleto."""
    atividades = Atividade.find_por_criterio(turma_id, etapa_id, criterio["id"])

    resultado = {
        "criterio_id": criterio["id"],
        "criterio": criterio["nome"],
        "peso": numero(criterio.get("peso")),
        "tem_atividade": bool(atividades),
        "total_atividades": len(atividades),
        "atividades_avaliadas": 0,
        "pontos_obtidos": None,
        "pontos_possiveis": None,
        "desempenho_percentual": None,
        "contribuicao": None,
        "completo": False,
    }

    if not atividades:
        return resultado

    ids = [a["id"] for a in atividades]
    valores = Nota.valores_por_atividade(aluno_id, ids)

    avaliadas = [a for a in atividades if a["id"] in valores]
    resultado["atividades_avaliadas"] = len(avaliadas)
    resultado["completo"] = len(avaliadas) == len(atividades)

    if not avaliadas:
        return resultado

    obtido = sum(float(valores[a["id"]]) for a in avaliadas)
    possivel = sum(float(a["nota_maxima"] or 0) for a in avaliadas)

    resultado["pontos_obtidos"] = round(obtido, 2)
    resultado["pontos_possiveis"] = round(possivel, 2)

    # Atividades legadas podem nao ter nota maxima configurada.
    if possivel <= 0:
        return resultado

    desempenho = obtido / possivel
    resultado["desempenho_percentual"] = round(desempenho * 100, 2)

    if resultado["completo"]:
        peso_fracao = float(criterio.get("peso") or 0) / 100
        resultado["contribuicao"] = round(desempenho * peso_fracao * 100, 2)

    return resultado


def calcular_desempenho_etapa(aluno_id, turma_id, etapa):
    """Desempenho completo de um aluno em uma etapa.

    'etapa' e o dict de Etapa.to_dict (precisa de id, nota_minima,
    nota_maxima). Quem valida que o aluno pertence a escola/turma e o
    chamador (aluno_acessivel) - esta funcao so calcula.
    """
    criterios = Criterio.find_all_by_etapa(etapa["id"], etapa["coordenacao_id"])

    soma_pesos, pesos_validos = resumo_pesos(criterios)

    criterios_calc = [
        _calcular_criterio(aluno_id, turma_id, etapa["id"], c)
        for c in criterios
    ]

    total_atividades = sum(c["total_atividades"] for c in criterios_calc)
    atividades_avaliadas = sum(c["atividades_avaliadas"] for c in criterios_calc)

    base = {
        "etapa_id": etapa["id"],
        "etapa": etapa.get("nome"),
        "ordem": etapa.get("ordem"),
        "nota_minima": etapa.get("nota_minima"),
        "nota_maxima": etapa.get("nota_maxima"),
        "peso_total": soma_pesos,
        "fechada": bool(etapa.get("fechada")),
        "criterios": criterios_calc,
        # Contagem agregada dos criterios - para o boletim mostrar quantas
        # atividades ja foram avaliadas e quantas ainda faltam, sem o
        # frontend precisar somar os criterios na mao.
        "total_atividades": total_atividades,
        "atividades_avaliadas": atividades_avaliadas,
        "atividades_sem_nota": total_atividades - atividades_avaliadas,
        "completo": False,
        "mensagem": None,
        "nota_calculada": None,
        "percentual": None,
    }

    tem_escala = etapa.get("nota_minima") is not None and etapa.get("nota_maxima") is not None

    if not pesos_validos or not tem_escala:
        if not criterios:
            mensagem = "Nenhum criterio configurado para esta etapa."
        elif not pesos_validos:
            mensagem = (
                "Os pesos dos criterios somam %s%% (precisam somar 100%%)."
                % soma_pesos
            )
        else:
            mensagem = "Etapa sem nota minima/maxima configurada."
        base.update({
            "situacao": "configuracao_invalida",
            "mensagem": mensagem,
        })
        return base

    ativos = [c for c in criterios_calc if (c["peso"] or 0) > 0]
    completo = all(c["completo"] for c in ativos)

    if not completo:
        base["situacao"] = "em_andamento"
        return base

    soma_contribuicao = sum((c["contribuicao"] or 0) for c in ativos) / 100
    nota_maxima = float(etapa["nota_maxima"])
    nota_minima = float(etapa["nota_minima"])
    nota_calculada = soma_contribuicao * nota_maxima

    situacao = "adequado" if nota_calculada >= nota_minima else "abaixo_do_minimo"

    base.update({
        "completo": True,
        "situacao": situacao,
        "nota_calculada": round(nota_calculada, 2),
        "percentual": round(soma_contribuicao * 100, 2),
    })
    return base


def calcular_todas_etapas(aluno_id, turma_id, coordenacao_id, ano_letivo):
    """Desempenho do aluno em cada etapa configurada da escola, em ordem."""
    etapas = Etapa.find_all_by_coordenacao(coordenacao_id, ano_letivo)
    resultado = []
    for linha in etapas:
        etapa = Etapa.to_dict(linha)
        etapa["coordenacao_id"] = coordenacao_id
        resultado.append(calcular_desempenho_etapa(aluno_id, turma_id, etapa))
    resultado.sort(key=lambda e: e["ordem"] or 0)
    return resultado


def etapa_atual(coordenacao_id, ano_letivo):
    """Usa a etapa ativa que abrange hoje; sem datas, usa a de maior ordem.

    Retorna tambem a regra usada, para o dashboard explicar a escolha.
    """
    from datetime import date

    linhas = Etapa.find_all_by_coordenacao(coordenacao_id, ano_letivo)
    ativas = [linha for linha in linhas if linha.get("ativa")]
    if not ativas:
        return None, "sem_etapas_configuradas"

    hoje = date.today()
    por_data = [
        linha for linha in ativas
        if linha.get("data_inicio") and linha.get("data_fim")
        and linha["data_inicio"] <= hoje <= linha["data_fim"]
    ]
    if por_data:
        etapa = Etapa.to_dict(por_data[0])
        etapa["coordenacao_id"] = coordenacao_id
        return etapa, "intervalo_de_datas"

    maior_ordem = max(ativas, key=lambda linha: linha["ordem"])
    etapa = Etapa.to_dict(maior_ordem)
    etapa["coordenacao_id"] = coordenacao_id
    return etapa, "maior_ordem_configurada"


def calcular_consolidado_geral(etapas_calculadas):
    """Consolidado do aluno usando so etapas FECHADAS com resultado pronto.

    Etapa aberta, em_andamento ou com configuracao_invalida nunca entra -
    contar uma etapa ainda em curso equivaleria a trata-la como zero, o que
    o Marco 2 ja proibe para nota ausente. Sem nenhuma etapa fechada e
    completa, o consolidado fica "em_andamento": a funcao nunca inventa uma
    media. A situacao geral e simples de proposito (Marco 3 pede uma regra
    simples, nao um sistema de auditoria): abaixo do minimo se QUALQUER
    etapa fechada considerada estiver abaixo do minimo dela.
    """
    consideradas = [
        etapa for etapa in etapas_calculadas
        if etapa.get("fechada") and etapa.get("completo")
        and etapa.get("percentual") is not None
    ]

    if not consideradas:
        return {
            "situacao": "em_andamento",
            "percentual": None,
            "etapas_consideradas": 0,
            "mensagem": "Nenhuma etapa fechada ainda para consolidar.",
        }

    percentual_medio = round(
        sum(etapa["percentual"] for etapa in consideradas) / len(consideradas), 2
    )
    abaixo_do_minimo = any(
        etapa["situacao"] == "abaixo_do_minimo" for etapa in consideradas
    )

    return {
        "situacao": "abaixo_do_minimo" if abaixo_do_minimo else "adequado",
        "percentual": percentual_medio,
        "etapas_consideradas": len(consideradas),
        "mensagem": None,
    }

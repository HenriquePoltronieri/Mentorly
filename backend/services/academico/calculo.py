"""Motor unico do calculo academico (Marco 2).

Ninguem mais calcula media/desempenho no projeto: nem o Flutter (o
GradeCalculator.dart antigo nunca era chamado e foi removido), nem outro
service do backend. Dashboard e estatisticas do aluno passam por aqui.

--------------------------------------------------------------------------
A REGRA, em portugues
--------------------------------------------------------------------------
Para cada criterio de uma etapa:

    desempenho_criterio = pontos_obtidos / pontos_possiveis

    pontos_obtidos  = soma do valor das notas LANCADAS nas atividades
                       daquele criterio, para aquele aluno;
    pontos_possiveis = soma do nota_maxima so dessas mesmas atividades
                        (as que tem nota lancada).

Uma atividade sem nota lancada para o aluno NAO entra nem no obtido nem no
possivel - ela nao e tratada como zero. Isso e o que separa "nao avaliado"
de "avaliado e tirou zero" (Etapa 5 do pedido). Por isso um criterio so e
"completo" quando TODAS as atividades dele, para aquele aluno, tem nota.

    contribuicao_criterio = (peso_criterio / 100) * desempenho_criterio

    nota_calculada_etapa = soma das contribuicoes * etapa.nota_maxima
    percentual_etapa     = soma das contribuicoes * 100

A etapa so e "completa" (e so entao ganha nota_calculada) quando TODOS os
criterios com peso > 0 estao completos. Enquanto faltar avaliacao, a etapa
fica "em_andamento" e nota_calculada e None - nunca um numero inventado.

--------------------------------------------------------------------------
Peso: formato e validacao
--------------------------------------------------------------------------
criterio.peso e um numero de 0 a 100 (pontos percentuais), DECIMAL(5,2) no
schema. Os pesos dos criterios ATIVOS de uma etapa (os que tem peso > 0)
precisam somar 100 (tolerancia 0.01, por causa de arredondamento de
ponto flutuante) para a etapa poder ser calculada. Antes do Marco 2 esse
numero nunca era validado nem usado em lugar nenhum - qualquer valor era
aceito e ignorado. Agora ele e a base do calculo, entao uma soma errada
bloqueia o resultado (situacao "configuracao_invalida") em vez de calcular
silenciosamente com uma configuracao que a Coordenacao nunca validou.

--------------------------------------------------------------------------
Arredondamento
--------------------------------------------------------------------------
Todo o calculo interno (fracoes, contribuicoes, somas) e feito em float
cheio, sem arredondar em nenhum passo intermediario - arredondar cedo
acumula erro (Etapa 14 do pedido). O round(..., 2) so acontece na hora de
montar o dict de saida, cada campo uma vez so.
"""

from models.atividade_model import Atividade
from models.criterio_model import Criterio
from models.etapa_model import Etapa
from models.nota_model import Nota
from models.utils import numero

TOLERANCIA_PESO = 0.01


# ---------------------------------------------------------------------
# Pesos
# ---------------------------------------------------------------------

def resumo_pesos(criterios):
    """Soma os pesos ATIVOS (peso > 0) e diz se a etapa pode ser calculada.

    Uma etapa sem nenhum criterio, ou so com criterios de peso 0, nunca e
    valida - nao ha o que calcular. criterios: lista de dict com "peso".
    """
    ativos = [c for c in criterios if (c.get("peso") or 0) > 0]
    soma = sum(float(c.get("peso") or 0) for c in ativos)
    valido = bool(ativos) and abs(soma - 100.0) <= TOLERANCIA_PESO
    return round(soma, 2), valido


# ---------------------------------------------------------------------
# Calculo por criterio
# ---------------------------------------------------------------------

def _calcular_criterio(aluno_id, turma_id, etapa_id, criterio):
    """Desempenho de um aluno em um criterio. Nunca levanta excecao.

    completo=False cobre os dois casos que a Etapa 4 pede para nao
    confundir: criterio sem nenhuma atividade ainda, e criterio com
    atividade mas sem nota lancada para este aluno.
    """
    atividades = Atividade.find_por_criterio(turma_id, etapa_id, criterio["id"])

    resultado = {
        "criterio_id": criterio["id"],
        "criterio": criterio["nome"],
        "peso": numero(criterio.get("peso")),
        "tem_atividade": bool(atividades),
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
    resultado["completo"] = len(avaliadas) == len(atividades)

    if not avaliadas:
        return resultado

    obtido = sum(float(valores[a["id"]]) for a in avaliadas)
    possivel = sum(float(a["nota_maxima"] or 0) for a in avaliadas)

    resultado["pontos_obtidos"] = round(obtido, 2)
    resultado["pontos_possiveis"] = round(possivel, 2)

    # Divisao por zero: atividade legada/mal configurada com nota_maxima
    # zerada. Sem isso o campo vira NaN/Infinity em vez de None.
    if possivel <= 0:
        return resultado

    desempenho = obtido / possivel
    resultado["desempenho_percentual"] = round(desempenho * 100, 2)

    if resultado["completo"]:
        peso_fracao = float(criterio.get("peso") or 0) / 100
        resultado["contribuicao"] = round(desempenho * peso_fracao * 100, 2)

    return resultado


# ---------------------------------------------------------------------
# Calculo por etapa
# ---------------------------------------------------------------------

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

    base = {
        "etapa_id": etapa["id"],
        "etapa": etapa.get("nome"),
        "ordem": etapa.get("ordem"),
        "nota_minima": etapa.get("nota_minima"),
        "nota_maxima": etapa.get("nota_maxima"),
        "peso_total": soma_pesos,
        "criterios": criterios_calc,
    }

    tem_escala = etapa.get("nota_minima") is not None and etapa.get("nota_maxima") is not None

    if not pesos_validos or not tem_escala:
        if not criterios:
            mensagem = "Nenhum criterio configurado para esta etapa."
        elif not pesos_validos:
            mensagem = (
                "Os pesos dos criterios somam %s%% (precisam somar 100%%)."
                % (soma_pesos if soma_pesos == int(soma_pesos) else soma_pesos)
            )
        else:
            mensagem = "Etapa sem nota minima/maxima configurada."
        base.update({
            "completo": False,
            "situacao": "configuracao_invalida",
            "mensagem": mensagem,
            "nota_calculada": None,
            "percentual": None,
        })
        return base

    ativos = [c for c in criterios_calc if (c["peso"] or 0) > 0]
    completo = all(c["completo"] for c in ativos)

    if not completo:
        base.update({
            "completo": False,
            "situacao": "em_andamento",
            "mensagem": None,
            "nota_calculada": None,
            "percentual": None,
        })
        return base

    soma_contribuicao = sum((c["contribuicao"] or 0) for c in ativos) / 100
    nota_maxima = float(etapa["nota_maxima"])
    nota_minima = float(etapa["nota_minima"])
    nota_calculada = soma_contribuicao * nota_maxima

    situacao = "adequado" if nota_calculada >= nota_minima else "abaixo_do_minimo"

    base.update({
        "completo": True,
        "situacao": situacao,
        "mensagem": None,
        "nota_calculada": round(nota_calculada, 2),
        "percentual": round(soma_contribuicao * 100, 2),
    })
    return base


# ---------------------------------------------------------------------
# Todas as etapas de um aluno
# ---------------------------------------------------------------------

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


# ---------------------------------------------------------------------
# Etapa atual
# ---------------------------------------------------------------------

def etapa_atual(coordenacao_id, ano_letivo):
    """Qual etapa vale 'agora' para o dashboard e para 'aluno em risco'.

    Regra, em ordem (a primeira que encontrar uma etapa decide):

      1. Etapa ativa cujo intervalo [data_inicio, data_fim] cobre hoje.
         So funciona se a Coordenacao preencheu essas datas - o schema
         permite NULL e a tela de configuracao atual nao pede essa data,
         entao na pratica isso raramente decide.
      2. Fallback: a etapa ativa de MAIOR ordem entre as configuradas
         para o ano letivo. E uma aproximacao deliberada ("a ultima
         etapa que a escola configurou e provavelmente a corrente"),
         nao uma leitura de calendario.

    Devolve (etapa_dict_ou_None, regra_usada) para quem consome deixar
    explicito qual criterio decidiu, como pedido na Etapa 10.
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

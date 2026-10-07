"""Caso de uso: sugestao de atividade e questoes para o Professor (Marco 9B).

Este service NAO grava nada. Ele valida quem pede, monta um contexto sem dados
de aluno, pede a sugestao ao AIClient e a devolve. A atividade so passa a
existir quando o Professor confirma no app e o fluxo normal de criacao
(CreateActivityService) a salva, repetindo as validacoes.
"""

from models.criterio_model import Criterio
from models.etapa_model import Etapa
from models.professor_turma_model import ProfessorTurma
from models.turma_model import Turma
from services.activity.validacao import validar_etapa_e_criterio
from services.ia.client import AIClient
from services.ia.contrato_atividade import (
    MAX_QUESTOES,
    TIPOS_PEDIDO,
    caso_gerar_atividade,
)


DIFICULDADES = ("facil", "media", "dificil")
QUANTIDADE_PADRAO = 5


def _limpar(valor, limite):
    """Texto digitado pelo Professor vai para o prompt: sem delimitadores nem quebras."""
    return " ".join(str(valor or "").replace("<", " ").replace(">", " ").split())[:limite]


def _texto_opcional(dados, chave, limite, rotulo):
    bruto = dados.get(chave)
    if bruto is None:
        return ""
    if not isinstance(bruto, str):
        raise ValueError("%s invalido" % rotulo)
    if len(bruto.strip()) > limite:
        raise ValueError("%s: no maximo %d caracteres" % (rotulo, limite))
    return _limpar(bruto, limite)


def _quantidade(bruto):
    if bruto is None or bruto == "":
        return QUANTIDADE_PADRAO
    if isinstance(bruto, bool) or not isinstance(bruto, (int, str)):
        raise ValueError("A quantidade de questoes precisa ser um numero inteiro")
    try:
        valor = int(bruto)
    except ValueError:
        raise ValueError("A quantidade de questoes precisa ser um numero inteiro")
    if valor < 1 or valor > MAX_QUESTOES:
        raise ValueError("A quantidade de questoes deve ficar entre 1 e %d" % MAX_QUESTOES)
    return valor


def validar_pedido(dados):
    """Valida o que o Professor digitou. ValueError vira 400."""
    if not isinstance(dados, dict):
        raise ValueError("Pedido invalido")

    tema = dados.get("tema")
    if not isinstance(tema, str) or not tema.strip():
        raise ValueError("Informe o tema da atividade")
    if len(tema.strip()) > 200:
        raise ValueError("Tema: no maximo 200 caracteres")

    dificuldade = dados.get("dificuldade") or "media"
    if dificuldade not in DIFICULDADES:
        raise ValueError("Dificuldade invalida: use facil, media ou dificil")

    tipo = dados.get("tipo") or "mista"
    if tipo not in TIPOS_PEDIDO:
        raise ValueError("Tipo invalido: use discursiva, objetiva ou mista")

    return {
        "tema": _limpar(tema, 200),
        "objetivo": _texto_opcional(dados, "objetivo", 500, "Objetivo"),
        "observacoes": _texto_opcional(dados, "observacoes", 500, "Observacoes"),
        "dificuldade": dificuldade,
        "quantidade": _quantidade(dados.get("quantidadeQuestoes")),
        "tipo": tipo,
    }


class GerarAtividadeIaService:
    def __init__(self, client=None):
        self.client = client or AIClient()

    def execute(self, turma_id, professor_id, coordenacao_id, dados):
        # 1. Quem pede: professor vinculado a turma da propria escola. 404 para
        #    qualquer outra combinacao, sem confirmar que a turma existe.
        if not ProfessorTurma.professor_leciona_na_turma(professor_id, turma_id):
            raise LookupError("Turma nao encontrada")
        turma = Turma.find_by_id(turma_id, coordenacao_id)
        if not turma:
            raise LookupError("Turma nao encontrada")

        # 2. O que pede.
        pedido = validar_pedido(dados)

        # 3. Mesmas regras da criacao de atividade: etapa da escola, do ano da
        #    turma e aberta; criterio pertencente a essa etapa. Etapa e criterio
        #    sao opcionais aqui (so alinham o conteudo), mas andam juntos.
        etapa_id, criterio_id = validar_etapa_e_criterio(
            coordenacao_id, dados.get("etapaId"), dados.get("criterioId"),
            obrigatorio=False, ano_turma=turma["ano_letivo"],
        )
        etapa = Etapa.find_by_id(etapa_id, coordenacao_id) if etapa_id else None
        criterio = Criterio.find_by_id(criterio_id, coordenacao_id) if criterio_id else None

        # 4. Contexto minimo. Nenhum dado de aluno, professor ou identificador.
        payload = {
            "turma": {
                "nome": _limpar(turma["nome"], 80),
                "disciplina": _limpar(turma.get("disciplina"), 80) or None,
                "anoLetivo": turma["ano_letivo"],
            },
            "etapa": _limpar(etapa["nome"], 80) if etapa else None,
            "criterioDeAvaliacao": _limpar(criterio["nome"], 80) if criterio else None,
            "pedido": {
                "tema": pedido["tema"],
                "objetivo": pedido["objetivo"] or None,
                "dificuldade": pedido["dificuldade"],
                "quantidadeQuestoes": pedido["quantidade"],
                "tipoDasQuestoes": pedido["tipo"],
                "observacoes": pedido["observacoes"] or None,
            },
        }

        sugestao = self.client.gerar(
            payload, caso_gerar_atividade(pedido["quantidade"], pedido["tipo"])
        )
        return {
            "contexto": {
                "turma": turma["nome"],
                "anoLetivo": turma["ano_letivo"],
                "etapa": etapa["nome"] if etapa else None,
                "criterio": criterio["nome"] if criterio else None,
            },
            "geradoPorIA": True,
            "modelo": self.client.model,
            "sugestao": sugestao,
        }

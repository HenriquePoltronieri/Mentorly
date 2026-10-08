"""Caso de uso: correcao assistida de uma resposta discursiva (Marco 9C).

Este service NAO grava nada e nao conhece o aluno: recebe o texto que o
Professor colou, valida quem pede, pede a avaliacao ao AIClient e devolve uma
SUGESTAO. A nota oficial e a que o Professor digitar e salvar pelo fluxo normal
(LancarNotasService). O percentual e calculado aqui, nunca pela IA.
"""

import math

from models.etapa_model import Etapa
from services.ia.client import AIClient
from services.ia.contrato_correcao import caso_corrigir_resposta
from services.professor.notas import _atividade_do_professor


MAX_QUESTAO = 2000
MAX_ESPERADA = 3000
MAX_RESPOSTA = 5000
MAX_ITENS_RUBRICA = 6


def _limpar(valor, limite):
    """Texto colado pelo Professor vai para o prompt: sem delimitadores nem quebras."""
    return " ".join(str(valor or "").replace("<", " ").replace(">", " ").split())[:limite]


def _texto_obrigatorio(dados, chave, limite, rotulo):
    bruto = dados.get(chave)
    if not isinstance(bruto, str) or not bruto.strip():
        raise ValueError("Informe %s" % rotulo)
    if len(bruto.strip()) > limite:
        raise ValueError("%s: no maximo %d caracteres" % (rotulo.capitalize(), limite))
    return _limpar(bruto, limite)


def _numero(bruto, rotulo):
    if isinstance(bruto, bool) or not isinstance(bruto, (int, float, str)):
        raise ValueError("%s precisa ser um numero" % rotulo)
    try:
        valor = float(str(bruto).replace(",", "."))
    except ValueError:
        raise ValueError("%s precisa ser um numero" % rotulo)
    if not math.isfinite(valor):
        raise ValueError("%s precisa ser um numero" % rotulo)
    return valor


def _rubrica(bruta):
    if bruta is None or bruta == []:
        return []
    if not isinstance(bruta, list) or len(bruta) > MAX_ITENS_RUBRICA:
        raise ValueError("Rubrica invalida: ate %d itens" % MAX_ITENS_RUBRICA)
    itens = []
    for item in bruta:
        if not isinstance(item, dict):
            raise ValueError("Rubrica invalida")
        nome = item.get("item")
        if not isinstance(nome, str) or not nome.strip() or len(nome.strip()) > 200:
            raise ValueError("Cada item da rubrica precisa de um nome de ate 200 caracteres")
        peso = item.get("peso")
        if peso is not None:
            peso = _numero(peso, "O peso do item da rubrica")
            if peso < 0 or peso > 100:
                raise ValueError("O peso do item da rubrica deve ficar entre 0 e 100")
        itens.append({"item": _limpar(nome, 200), "peso": peso})
    return itens


def validar_pedido(dados, valor_maximo_atividade):
    """Valida o que o Professor colou. ValueError vira 400."""
    if not isinstance(dados, dict):
        raise ValueError("Pedido invalido")

    bruto = dados.get("valorMaximo")
    if bruto is None or bruto == "":
        valor_maximo = valor_maximo_atividade
    else:
        valor_maximo = _numero(bruto, "O valor maximo")
        if valor_maximo <= 0:
            raise ValueError("O valor maximo precisa ser maior que zero")
        if valor_maximo > valor_maximo_atividade:
            raise ValueError(
                "O valor maximo nao pode passar do valor da atividade (%s)"
                % _limpo(valor_maximo_atividade)
            )

    return {
        "questao": _texto_obrigatorio(dados, "questao", MAX_QUESTAO, "a questao"),
        "respostaEsperada": _texto_obrigatorio(
            dados, "respostaEsperada", MAX_ESPERADA, "a resposta esperada"),
        "respostaAluno": _texto_obrigatorio(
            dados, "respostaAluno", MAX_RESPOSTA, "a resposta do aluno"),
        "valorMaximo": valor_maximo,
        "rubrica": _rubrica(dados.get("rubrica")),
    }


class CorrigirRespostaIaService:
    def __init__(self, client=None):
        self.client = client or AIClient()

    def execute(self, atividade_id, professor_id, dados):
        # 1. Quem pede: a atividade precisa ser de uma turma do Professor (404
        #    para qualquer outra combinacao, inclusive outra escola).
        atividade = _atividade_do_professor(atividade_id, professor_id)

        # 2. Etapa fechada: o resultado serviria para lancar nota, que o
        #    backend recusa. Nao gasta chamada de IA a toa.
        if atividade.get("etapa_id") and Etapa.esta_fechada(
            atividade["etapa_id"], atividade["coordenacao_id"]
        ):
            raise ValueError(
                "Nao e possivel corrigir: a etapa desta atividade ja esta fechada."
            )
        if atividade.get("nota_maxima") is None:
            raise ValueError(
                "Esta atividade ainda nao tem valor maximo definido. "
                "Edite a atividade e informe quanto ela vale."
            )

        # 3. O que foi colado.
        pedido = validar_pedido(dados, float(atividade["nota_maxima"]))

        # 4. Contexto minimo. Sem nome ou qualquer dado do aluno, e sem ids.
        payload = {
            "atividade": _limpar(atividade["titulo"], 200),
            "criterioOficial": (
                {"nome": _limpar(atividade["criterio_nome"], 100)}
                if atividade.get("criterio_nome") else None
            ),
            "questao": pedido["questao"],
            "respostaEsperada": pedido["respostaEsperada"],
            "respostaAluno": pedido["respostaAluno"],
            "valorMaximo": pedido["valorMaximo"],
            "rubrica": pedido["rubrica"],
        }

        sugestao = self.client.gerar(
            payload,
            caso_corrigir_resposta(
                pedido["valorMaximo"],
                pedido["respostaAluno"],
                [item["item"] for item in pedido["rubrica"]],
            ),
        )

        # 5. Percentual deterministico: a IA nao participa deste calculo.
        sugestao["valorMaximo"] = pedido["valorMaximo"]
        sugestao["percentual"] = round(
            sugestao["notaSugerida"] / pedido["valorMaximo"] * 100, 2
        )
        return {
            "contexto": {
                "atividade": atividade["titulo"],
                "criterio": atividade.get("criterio_nome"),
                "valorMaximo": pedido["valorMaximo"],
            },
            "geradoPorIA": True,
            "modelo": self.client.model,
            "sugestao": sugestao,
        }


def _limpo(valor):
    """20.0 vira "20"; 13.5 continua "13.5". So para a mensagem de erro."""
    numero = float(valor)
    return str(int(numero)) if numero == int(numero) else str(numero)

"""Conversores usados pelos serializers dos Models.

O PyMySQL devolve DATETIME como datetime e DECIMAL como Decimal, e o
jsonify do Flask nao sabe serializar nenhum dos dois. Todo to_dict de
Model passa os valores por aqui antes de devolver.
"""

from datetime import date, datetime
from decimal import Decimal


def iso(valor):
    """datetime/date -> string ISO. Qualquer outra coisa passa direto."""
    if isinstance(valor, (datetime, date)):
        return valor.isoformat()
    return valor


def numero(valor):
    """Decimal -> float, preservando None."""
    if isinstance(valor, Decimal):
        return float(valor)
    return valor


def booleano(valor):
    """TINYINT(1) -> bool, preservando None."""
    if valor is None:
        return None
    return bool(valor)


def normalizar(linha):
    """Converte um dict inteiro vindo do banco para tipos serializaveis."""
    if linha is None:
        return None
    return {chave: numero(iso(valor)) for chave, valor in linha.items()}


def normalizar_lista(linhas):
    return [normalizar(linha) for linha in linhas]

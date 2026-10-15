"""Horario de Brasilia, UTC-3, usando apenas a biblioteca padrao Python."""
from datetime import datetime, timezone, timedelta

BRASILIA = timezone(timedelta(hours=-3))


def agora_brasilia():
    return datetime.now(BRASILIA)

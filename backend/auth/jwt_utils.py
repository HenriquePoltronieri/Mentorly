"""Geracao e validacao do JWT usado pelo app.

O payload carrega a escola (coordenacao_id). Todo endpoint que lista dados
tira a escola daqui, nunca de um parametro enviado pelo cliente - e o que
impede um usuario de pedir os dados de outra coordenacao.
"""

import secrets
from datetime import datetime, timedelta, timezone

import jwt

from config import SECRET_KEY, TOKEN_EXPIRACAO_HORAS

ALGORITMO = "HS256"

TIPO_COORDENACAO = "coordenacao"
TIPO_PROFESSOR = "professor"


def gerar_token(usuario_id, tipo, coordenacao_id):
    """Monta o JWT.

    coordenacao_id e o proprio id quando o usuario e a coordenacao, e o id
    da escola dona quando e um professor.
    """
    agora = datetime.now(timezone.utc)
    payload = {
        "sub": str(usuario_id),
        "uid": usuario_id,
        "tipo": tipo,
        "coordenacao_id": coordenacao_id,
        "iat": agora,
        "exp": agora + timedelta(hours=TOKEN_EXPIRACAO_HORAS),
    }
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITMO)


def decodificar_token(token):
    """Devolve o payload, ou None se o token for invalido/expirado."""
    try:
        return jwt.decode(token, SECRET_KEY, algorithms=[ALGORITMO])
    except jwt.PyJWTError:
        return None


def extrair_token(cabecalho_authorization):
    """Tira o token do cabecalho 'Bearer <token>' que o Flutter envia."""
    if not cabecalho_authorization:
        return None
    partes = cabecalho_authorization.split()
    if len(partes) != 2 or partes[0].lower() != "bearer":
        return None
    return partes[1]


def gerar_token_convite():
    """Token opaco do convite que o professor recebe por email."""
    return secrets.token_urlsafe(32)[:64]


def gerar_codigo_verificacao():
    """Codigo numerico de 6 digitos da verificacao em duas etapas."""
    return "%06d" % secrets.randbelow(1000000)

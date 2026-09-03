"""Decorators de autenticacao e de papel.

Sao eles que resolvem duas regras de negocio no backend, e nao so
escondendo botao no frontend:

  - a Coordenacao NAO cria atividade nem lanca nota (@professor_required);
  - o Professor NAO configura o ano letivo (@coordenacao_required).

Depois de qualquer um deles, g.usuario tem:
    {"id": int, "tipo": "coordenacao"|"professor", "coordenacao_id": int}
"""

from functools import wraps

from flask import g, jsonify, request

from auth.jwt_utils import (
    TIPO_COORDENACAO,
    TIPO_PROFESSOR,
    decodificar_token,
    extrair_token,
)


def _carregar_usuario():
    """Le o token e popula g.usuario. Devolve None se falhar.

    O caminho normal e o cabecalho 'Authorization: Bearer <token>'. Como
    fallback, aceita ?token=<token> na query string: os downloads de modelo
    de planilha sao abertos pelo navegador (launchUrl), que nao tem como
    mandar cabecalho. So os endpoints de download usam essa porta.
    """
    token = extrair_token(request.headers.get("Authorization"))
    if not token:
        token = request.args.get("token")
    if not token:
        return None

    payload = decodificar_token(token)
    if not payload:
        return None

    g.usuario = {
        "id": payload.get("uid"),
        "tipo": payload.get("tipo"),
        "coordenacao_id": payload.get("coordenacao_id"),
    }
    return g.usuario


def auth_required(funcao):
    """Exige um token valido, de qualquer papel."""

    @wraps(funcao)
    def wrapper(*args, **kwargs):
        if _carregar_usuario() is None:
            return jsonify({"error": "Autenticacao necessaria"}), 401
        return funcao(*args, **kwargs)

    return wrapper


def coordenacao_required(funcao):
    """Exige um token de Coordenacao.

    Usado nas rotas de cadastro de turma, aluno, vinculo de professor e
    configuracao do ano letivo.
    """

    @wraps(funcao)
    def wrapper(*args, **kwargs):
        usuario = _carregar_usuario()
        if usuario is None:
            return jsonify({"error": "Autenticacao necessaria"}), 401
        if usuario["tipo"] != TIPO_COORDENACAO:
            return jsonify(
                {"error": "Esta acao e exclusiva da Coordenacao"}
            ), 403
        return funcao(*args, **kwargs)

    return wrapper


def professor_required(funcao):
    """Exige um token de Professor.

    Usado em tudo que e conteudo pedagogico: criar/editar/excluir atividade
    e lancar nota. A Coordenacao recebe 403 aqui - e o que corrige o bug de
    a coordenacao conseguir criar atividades.
    """

    @wraps(funcao)
    def wrapper(*args, **kwargs):
        usuario = _carregar_usuario()
        if usuario is None:
            return jsonify({"error": "Autenticacao necessaria"}), 401
        if usuario["tipo"] != TIPO_PROFESSOR:
            return jsonify(
                {"error": "Esta acao e exclusiva do Professor"}
            ), 403
        return funcao(*args, **kwargs)

    return wrapper


# ---------------------------------------------------------------------
# Atalhos usados pelos controllers
# ---------------------------------------------------------------------

def coordenacao_atual():
    """Id da escola do usuario logado. Vem do token, nunca da requisicao."""
    return g.usuario["coordenacao_id"]


def usuario_atual_id():
    return g.usuario["id"]


def eh_professor():
    return g.usuario["tipo"] == TIPO_PROFESSOR

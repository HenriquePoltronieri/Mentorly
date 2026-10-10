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


def token_na_url_so_neste_download(funcao):
    """Marca UMA rota GET de download como a unica excecao ao Bearer-only.

    Os modelos de planilha sao abertos pelo navegador (launchUrl no Flutter),
    que nao consegue mandar cabecalho: so essas rotas aceitam ?token=. A marca
    vale para a view onde o decorator e aplicado (aplique-o ABAIXO do decorator
    de papel) e nunca vira regra geral.
    """
    funcao.aceita_token_na_url = True
    return funcao


def _carregar_usuario(aceita_token_na_url=False):
    """Le o token e popula g.usuario. Devolve None se falhar.

    O padrao e o cabecalho 'Authorization: Bearer <token>', e so ele. A query
    string ?token= NAO autentica endpoint nenhum, exceto os downloads marcados
    com token_na_url_so_neste_download, e ainda assim so em GET e so quando a
    requisicao NAO traz cabecalho Authorization: com cabecalho presente (valido
    ou nao) a identidade vem dele e a URL e ignorada, nunca o contrario.
    """
    cabecalho = request.headers.get("Authorization")
    if cabecalho:
        token = extrair_token(cabecalho)
    elif aceita_token_na_url and request.method == "GET":
        token = request.args.get("token")
    else:
        token = None
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


def _professor_habilitado(usuario):
    """Confere no banco o estado administrativo de token de Professor.

    Algumas leituras compartilhadas usam ``@auth_required`` e decidem o
    recorte pelo tipo do token. A guarda tambem precisa valer nelas, para um
    JWT emitido antes da desativacao nao continuar servindo para consultas.
    """
    if usuario["tipo"] != TIPO_PROFESSOR:
        return True
    from models.professor_model import Professor
    professor = Professor.find_by_id(usuario["id"], usuario["coordenacao_id"])
    return bool(professor and professor.get("habilitado", True))


def _professor_desativado():
    """403 do professor desativado, com `code` para o app distinguir este caso.

    Os outros 403 (papel/permissao) nao levam `code` e nao encerram a sessao no
    app; este, sim, porque o token deixou de valer para aquele professor.
    """
    return jsonify({
        "error": "Professor desativado",
        "code": "professor_desativado",
    }), 403


def auth_required(funcao):
    """Exige um token valido, de qualquer papel."""

    @wraps(funcao)
    def wrapper(*args, **kwargs):
        usuario = _carregar_usuario(getattr(funcao, "aceita_token_na_url", False))
        if usuario is None:
            return jsonify({"error": "Autenticacao necessaria"}), 401
        if not _professor_habilitado(usuario):
            return _professor_desativado()
        return funcao(*args, **kwargs)

    return wrapper


def coordenacao_required(funcao):
    """Exige um token de Coordenacao.

    Usado nas rotas de cadastro de turma, aluno, vinculo de professor e
    configuracao do ano letivo.
    """

    @wraps(funcao)
    def wrapper(*args, **kwargs):
        usuario = _carregar_usuario(getattr(funcao, "aceita_token_na_url", False))
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
        usuario = _carregar_usuario(getattr(funcao, "aceita_token_na_url", False))
        if usuario is None:
            return jsonify({"error": "Autenticacao necessaria"}), 401
        if usuario["tipo"] != TIPO_PROFESSOR:
            return jsonify(
                {"error": "Esta acao e exclusiva do Professor"}
            ), 403
        # O JWT pode ter sido emitido antes de uma desativacao. A guarda e a
        # mesma de @auth_required, pois ambos precisam bloquear o token.
        if not _professor_habilitado(usuario):
            return _professor_desativado()
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

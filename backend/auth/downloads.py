"""Permissao de 2 minutos para UM arquivo, sem colocar o JWT da sessao na URL."""
from itsdangerous import URLSafeTimedSerializer, BadSignature, SignatureExpired
import config


def gerar_permissao(usuario, caminho):
    return URLSafeTimedSerializer(config.SECRET_KEY, salt='mentorly-download-v1').dumps(
        {**usuario, 'caminho': caminho})


def ler_permissao(token, caminho):
    try:
        dados = URLSafeTimedSerializer(config.SECRET_KEY, salt='mentorly-download-v1').loads(token, max_age=120)
        if (not isinstance(dados, dict) or dados.get('caminho') != caminho or
                dados.get('tipo') not in ('professor', 'coordenacao') or
                type(dados.get('id')) is not int or type(dados.get('coordenacao_id')) is not int):
            return None
        return {'uid': dados['id'], 'tipo': dados['tipo'], 'coordenacao_id': dados['coordenacao_id']}
    except (BadSignature, SignatureExpired, TypeError):
        return None

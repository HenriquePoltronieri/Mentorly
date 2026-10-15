from flask import Blueprint, g, jsonify, request, current_app
from auth.decorators import auth_required
from services.acesso_escola import consultar

acesso_blueprint = Blueprint('acesso', __name__)


@acesso_blueprint.get('/api/acesso')
@auth_required
def meu_acesso():
    return jsonify(consultar(g.usuario['coordenacao_id']))


@acesso_blueprint.get('/api/downloads/autorizar')
@auth_required
def autorizar_download():
    caminho = request.args.get('caminho', '')
    if not caminho.startswith('/') or '?' in caminho or len(caminho) > 300:
        return jsonify({'error': 'Arquivo inválido.'}), 400
    try:
        endpoint, _ = current_app.url_map.bind('').match('/api' + caminho, method='GET')
    except Exception:
        return jsonify({'error': 'Arquivo não encontrado.'}), 404
    view = current_app.view_functions[endpoint]
    if not getattr(view, 'aceita_token_na_url', False):
        return jsonify({'error': 'Este endereço não permite download.'}), 400
    from auth.downloads import gerar_permissao
    return jsonify({'token': gerar_permissao(g.usuario, '/api' + caminho)})

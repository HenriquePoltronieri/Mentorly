"""API da administracao Flutter. Sessao HttpOnly, CSRF e SQL direto."""
import hmac
import secrets
from functools import wraps

from flask import Blueprint, request, session, jsonify, g, abort
from werkzeug.security import check_password_hash, generate_password_hash

from database.connection import query_one, execute
from controllers.admin_escolas_controller import AdminEscolasController
from services import entrada
from services.rate_limit import limitar_por_origem

admin_blueprint = Blueprint('admin', __name__, url_prefix='/api/admin')
admin_escolas_controller = AdminEscolasController()
HASH_INEXISTENTE = generate_password_hash(secrets.token_urlsafe(24))


def _csrf():
    if not isinstance(session.get('csrf'), str):
        session['csrf'] = secrets.token_urlsafe(32)
    return session['csrf']


@admin_blueprint.before_request
def proteger_alteracoes():
    esperado = _csrf()
    if request.method in ('POST', 'PUT', 'DELETE', 'PATCH'):
        recebido = request.headers.get('X-CSRF-Token', '')
        if not hmac.compare_digest(esperado.encode('utf-8'), recebido.encode('utf-8')):
            abort(400, description='Sessão do formulário expirada. Atualize a página e tente novamente.')


def _administrador():
    admin_id = session.get('admin_id')
    if type(admin_id) is not int:
        return None
    admin = query_one('SELECT id,nome,email,ativo,versao_sessao FROM administrador WHERE id=%s', (admin_id,))
    if not admin or not admin['ativo'] or admin['versao_sessao'] != session.get('versao_sessao'):
        session.clear()
        return None
    return admin


def administrador_required(funcao):
    @wraps(funcao)
    def wrapper(*args, **kwargs):
        admin = _administrador()
        if admin is None:
            return jsonify({'error': 'Entre na administração para continuar.'}), 401
        g.administrador = admin
        return funcao(*args, **kwargs)
    return wrapper


@admin_blueprint.get('/sessao')
def sessao():
    admin = _administrador()
    return jsonify({'csrf': _csrf(), 'usuario': {'id': admin['id'], 'nome': admin['nome']}
                    if admin else None})


@admin_blueprint.post('/login')
def login():
    dados = request.get_json(silent=True) or {}
    try:
        email = entrada.texto(dados.get('email'), 'O e-mail', 150).lower()
        senha = entrada.senha(dados.get('senha'))
    except ValueError as erro:
        return jsonify({'error': str(erro)}), 400
    limitar_por_origem('admin_login', request.remote_addr, email)
    admin = query_one('SELECT * FROM administrador WHERE email=%s', (email,))
    confere = check_password_hash(admin['senha_hash'] if admin else HASH_INEXISTENTE, senha)
    if not senha or not confere or not admin or not admin['ativo']:
        return jsonify({'error': 'E-mail ou senha inválidos.'}), 401
    session.clear()
    session.update(admin_id=admin['id'], versao_sessao=admin['versao_sessao'])
    session.permanent = True
    return jsonify({'csrf': _csrf(), 'usuario': {'id': admin['id'], 'nome': admin['nome']}})


@admin_blueprint.get('/escolas')
@administrador_required
def painel():
    return admin_escolas_controller.listar()


@admin_blueprint.put('/escolas/<int:escola_id>/acesso')
@administrador_required
def salvar_acesso(escola_id):
    return admin_escolas_controller.salvar_acesso(escola_id)


@admin_blueprint.delete('/escolas/<int:escola_id>')
@administrador_required
def excluir_escola(escola_id):
    return admin_escolas_controller.excluir(escola_id)


@admin_blueprint.post('/sair')
@administrador_required
def sair():
    # Revoga tambem copias antigas do cookie desse administrador.
    execute('UPDATE administrador SET versao_sessao=versao_sessao+1 WHERE id=%s', (g.administrador['id'],))
    session.clear()
    return jsonify({'mensagem': 'Você saiu da administração.'})

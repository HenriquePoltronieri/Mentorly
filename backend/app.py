import time
from flask import Flask, g, jsonify, request, send_from_directory, redirect
from datetime import timedelta
import config
from routes.admin_routes import admin_blueprint
from routes.acesso_routes import acesso_blueprint

from config import DEBUG
from erros import AcessoNegado
from database.connection import init_database, install_procedures, install_schema
from database.connection import encerrar_conexao_requisicao
from database.orm import db
from sqlalchemy.engine import URL
from services.rate_limit import LimiteExcedido
from routes.activity_routes import activity_blueprint
from routes.auth_routes import auth_blueprint
from routes.class_routes import class_blueprint
from routes.config_routes import config_blueprint
from routes.coordenacao_routes import coordenacao_blueprint
from routes.dashboard_routes import dashboard_blueprint
from routes.trabalho_routes import trabalho_blueprint
from routes.professor_routes import (
    atividade_notas_blueprint,
    professor_blueprint,
)


def create_app():
    config.validar_producao()
    app = Flask(__name__)
    app.secret_key = config.SECRET_KEY
    app.config['SQLALCHEMY_DATABASE_URI'] = URL.create(
        'mysql+pymysql', username=config.DB_CONFIG['user'],
        password=config.DB_CONFIG['password'], host=config.DB_CONFIG['host'],
        port=config.DB_CONFIG['port'], database=config.DB_CONFIG['database'],
    )
    db.init_app(app)
    app.config.update(SESSION_COOKIE_NAME='mentorly_admin',
                      SESSION_COOKIE_HTTPONLY=True, SESSION_COOKIE_SAMESITE='Strict',
                      SESSION_COOKIE_SECURE=config.PRODUCAO,
                      PERMANENT_SESSION_LIFETIME=timedelta(hours=2),
                      MAX_FORM_MEMORY_SIZE=64 * 1024, MAX_FORM_PARTS=30)
    import os
    if config.PRODUCAO:
        app.config['TRUSTED_HOSTS'] = [h.strip() for h in os.environ.get('TRUSTED_HOSTS', '').split(',') if h.strip()]
    # Ative apenas se a aplicacao receber conexoes exclusivamente do proxy.
    if os.environ.get('TRUSTED_PROXY_HOPS') == '1':
        from werkzeug.middleware.proxy_fix import ProxyFix
        app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_proto=1)
    app.teardown_appcontext(encerrar_conexao_requisicao)

    @app.before_request
    def iniciar_medicao():
        g.inicio_requisicao = time.perf_counter()

    @app.after_request
    def registrar_tempo(response):
        duracao = (time.perf_counter() - getattr(g, 'inicio_requisicao', time.perf_counter())) * 1000
        response.headers["Server-Timing"] = 'app;dur=%.2f, db;desc="%d consultas"' % (duracao, getattr(g, "consultas_db", 0))
        # Usa o padrão da rota: nunca registra query string/token do convite.
        app.logger.info("%s %s status=%d tempo_ms=%.2f consultas=%d", request.method,
                        request.url_rule.rule if request.url_rule else "rota_ausente",
                        response.status_code, duracao, getattr(g, "consultas_db", 0))
        return response

    # Limite de upload das planilhas. Sem isso, um arquivo enorme fica
    # inteiro na memoria antes de o service conseguir recusar.
    app.config["MAX_CONTENT_LENGTH"] = 5 * 1024 * 1024

    app.register_blueprint(auth_blueprint)
    app.register_blueprint(coordenacao_blueprint)
    app.register_blueprint(professor_blueprint)
    app.register_blueprint(atividade_notas_blueprint)
    app.register_blueprint(config_blueprint)
    app.register_blueprint(class_blueprint)
    app.register_blueprint(activity_blueprint)
    app.register_blueprint(dashboard_blueprint)
    app.register_blueprint(trabalho_blueprint)
    app.register_blueprint(admin_blueprint)
    app.register_blueprint(acesso_blueprint)

    # Libera o acesso do Flutter Web: o app roda em outra porta, entao o
    # navegador trata como outra origem e bloqueia a chamada sem estes
    # cabecalhos. No emulador Android isso nao e necessario, mas nao atrapalha.
    @app.after_request
    def liberar_cors(response):
        origem = request.headers.get('Origin', '')
        if origem in config.CORS_ORIGINS:
            response.headers['Access-Control-Allow-Origin'] = origem
            response.vary.add('Origin')
            if request.path.startswith('/api/admin/'):
                response.headers['Access-Control-Allow-Credentials'] = 'true'
        response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization, X-CSRF-Token"
        response.headers["Access-Control-Allow-Methods"] = (
            "GET, POST, PUT, DELETE, OPTIONS"
        )
        response.headers["Access-Control-Expose-Headers"] = "Content-Disposition, Server-Timing"
        response.headers['X-Content-Type-Options'] = 'nosniff'
        response.headers['X-Frame-Options'] = 'DENY'
        response.headers['Referrer-Policy'] = 'no-referrer'
        if request.path.startswith(('/api/', '/admin')):
            response.headers['Cache-Control'] = 'no-store'
        if request.path.startswith('/admin'):
            response.headers['Content-Security-Policy'] = "default-src 'self'; form-action 'self'; frame-ancestors 'none'; base-uri 'self'"
        if request.path.startswith('/api/admin/'):
            response.headers['Content-Security-Policy'] = "default-src 'none'; frame-ancestors 'none'"
        if config.PRODUCAO:
            response.headers['Strict-Transport-Security'] = 'max-age=31536000'
        return response

    # Todo endpoint JSON espera um objeto. Corpo que e lista, texto ou numero
    # ([], "x", 5) quebraria o .get() dos controllers com AttributeError (500);
    # aqui vira 400. Corpo ausente ou JSON ilegivel segue o comportamento de
    # sempre (cada service valida os campos obrigatorios).
    @app.before_request
    def exigir_corpo_json_como_objeto():
        if request.method == 'OPTIONS':
            return '', 204
        if request.method in ("POST", "PUT", "PATCH"):
            corpo = request.get_json(silent=True)
            if corpo is not None and not isinstance(corpo, dict):
                return jsonify({
                    "error": "Corpo da requisicao invalido: envie um objeto JSON"
                }), 400

    # Erro inesperado: o cliente recebe uma resposta generica em JSON, sem HTML,
    # stack nem detalhe do banco. O motivo continua no log (o Flask ja registra
    # a excecao antes de chamar este handler) e, com debug ligado, o depurador
    # segue ativo porque a excecao se propaga. Erros conhecidos (400/401/403/
    # 404/409/422/503) sao respondidos pelos controllers e nao passam por aqui.
    @app.errorhandler(AcessoNegado)
    def acesso_negado(erro):
        return jsonify({"error": str(erro)}), 403

    @app.errorhandler(500)
    def erro_interno(_erro):
        return jsonify({"error": "Erro interno do servidor."}), 500

    # Limite de requisicoes sensiveis (login, codigos, convites, IA): 429 com a
    # mensagem do limite e Retry-After em segundos. Quem levanta a excecao ja
    # impediu o trabalho caro (a IA nao e chamada).
    @app.errorhandler(LimiteExcedido)
    def limite_excedido(erro):
        resposta = jsonify({"error": erro.mensagem})
        resposta.status_code = 429
        resposta.headers["Retry-After"] = str(erro.retry_after)
        return resposta

    @app.errorhandler(413)
    def arquivo_grande(_erro):
        return jsonify({"error": "Arquivo muito grande (limite de 5 MB)"}), 413

    from pymysql import IntegrityError

    @app.errorhandler(IntegrityError)
    def conflito_banco(_erro):
        return jsonify({'error': 'Registro já existente ou em uso. Atualize a página e confira os dados.'}), 409

    @app.errorhandler(400)
    def requisicao_invalida(erro):
        if request.path.startswith('/api/admin/'):
            return jsonify({'error': erro.description}), 400
        return jsonify({'error': 'Requisição inválida. Confira os dados enviados.'}), 400

    @app.get("/")
    def health_check():
        if config.WEB_BUILD_DIR:
            return send_from_directory(config.WEB_BUILD_DIR, 'index.html')
        return {"status": "ok", "service": "Mentorly API"}

    @app.get('/health')
    def health():
        from database.connection import query_one
        try:
            query_one('SELECT 1 AS ok')
            return {'status': 'ok'}
        except Exception:
            return {'status': 'indisponivel'}, 503

    @app.get('/admin')
    @app.get('/admin/')
    @app.get('/admin/login')
    def abrir_administracao():
        return redirect('/#/admin')

    @app.get('/<path:arquivo>')
    def aplicativo(arquivo):
        # send_from_directory protege contra ../ e nao expoe o codigo/backend.
        if config.WEB_BUILD_DIR and not arquivo.startswith(('api/', 'admin/')):
            return send_from_directory(config.WEB_BUILD_DIR, arquivo)
        return jsonify({'error': 'Endereço não encontrado.'}), 404

    return app


if __name__ == "__main__":
    init_database()
    install_schema()
    install_procedures()
    app = create_app()
    app.run(debug=DEBUG)

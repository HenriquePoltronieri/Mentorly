import time
from flask import Flask, g, jsonify, request

from config import DEBUG
from erros import AcessoNegado
from database.connection import init_database, install_procedures, install_schema
from database.connection import encerrar_conexao_requisicao
from services.rate_limit import LimiteExcedido
from routes.activity_routes import activity_blueprint
from routes.auth_routes import auth_blueprint
from routes.class_routes import class_blueprint
from routes.config_routes import config_blueprint
from routes.coordenacao_routes import coordenacao_blueprint
from routes.dashboard_routes import dashboard_blueprint
from routes.professor_routes import (
    atividade_notas_blueprint,
    professor_blueprint,
)


def create_app():
    app = Flask(__name__)
    app.teardown_appcontext(encerrar_conexao_requisicao)

    @app.before_request
    def iniciar_medicao():
        g.inicio_requisicao = time.perf_counter()

    @app.after_request
    def registrar_tempo(response):
        duracao = (time.perf_counter() - g.inicio_requisicao) * 1000
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

    # Libera o acesso do Flutter Web: o app roda em outra porta, entao o
    # navegador trata como outra origem e bloqueia a chamada sem estes
    # cabecalhos. No emulador Android isso nao e necessario, mas nao atrapalha.
    @app.after_request
    def liberar_cors(response):
        response.headers["Access-Control-Allow-Origin"] = "*"
        response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
        response.headers["Access-Control-Allow-Methods"] = (
            "GET, POST, PUT, DELETE, OPTIONS"
        )
        response.headers["Access-Control-Expose-Headers"] = "Content-Disposition, Server-Timing"
        return response

    # Todo endpoint JSON espera um objeto. Corpo que e lista, texto ou numero
    # ([], "x", 5) quebraria o .get() dos controllers com AttributeError (500);
    # aqui vira 400. Corpo ausente ou JSON ilegivel segue o comportamento de
    # sempre (cada service valida os campos obrigatorios).
    @app.before_request
    def exigir_corpo_json_como_objeto():
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

    @app.get("/")
    def health_check():
        return {"status": "ok", "service": "Mentorly API"}

    return app


if __name__ == "__main__":
    init_database()
    install_schema()
    install_procedures()
    app = create_app()
    app.run(debug=DEBUG)

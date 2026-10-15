"""Servidor local com a biblioteca padrao Python. Em producao use WSGI do provedor."""
from socketserver import ThreadingMixIn
from wsgiref.simple_server import WSGIServer, WSGIRequestHandler, make_server


class ServidorComThreads(ThreadingMixIn, WSGIServer):
    daemon_threads = True


class LogSemDadosPrivados(WSGIRequestHandler):
    def log_message(self, formato, *args):
        # O Flask ja registra a rota sem query; nao duplica tokens em URLs.
        pass


def servir(app, host='127.0.0.1', port=5000):
    with make_server(host, port, app, server_class=ServidorComThreads,
                     handler_class=LogSemDadosPrivados) as servidor:
        servidor.serve_forever()

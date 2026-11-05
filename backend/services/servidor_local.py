"""Servidor de desenvolvimento com porta exclusiva no Windows."""
import socket
from werkzeug.serving import ThreadedWSGIServer


class ServidorLocal(ThreadedWSGIServer):
    # SO_REUSEADDR no Windows permite dois servidores na mesma porta.
    allow_reuse_address = False

    def server_bind(self):
        if hasattr(socket, 'SO_EXCLUSIVEADDRUSE'):
            self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_EXCLUSIVEADDRUSE, 1)
        super().server_bind()


def executar(app, debug=False):
    app.debug = debug
    aplicacao = app
    if debug:
        from werkzeug.debug import DebuggedApplication
        aplicacao = DebuggedApplication(app, evalex=True)
    servidor = ServidorLocal('127.0.0.1', 5000, aplicacao)
    servidor.log_startup()
    print('CTRL+C encerra o backend. Reinicie apos alterar o codigo.', flush=True)
    try:
        servidor.serve_forever()
    finally:
        servidor.server_close()

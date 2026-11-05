import socket
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from services.servidor_local import ServidorLocal


class PortaExclusivaTest(unittest.TestCase):
    def test_segundo_servidor_nao_pode_reutilizar_porta(self):
        servidor = ServidorLocal('127.0.0.1', 0, lambda env, start: [])
        try:
            with socket.socket() as segundo:
                segundo.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
                with self.assertRaises(OSError):
                    segundo.bind(servidor.socket.getsockname())
        finally:
            servidor.server_close()


if __name__ == '__main__':
    unittest.main()

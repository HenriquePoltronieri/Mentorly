"""Excecoes de dominio compartilhadas por models, services e controllers.

RecursoNaoEncontrado e a UNICA forma de dizer "isto nao existe (para este
usuario)": o controller responde 404. Ela de proposito NAO herda de
LookupError: KeyError e IndexError herdam de LookupError, e usar LookupError
como "nao encontrado" fazia um bug interno (chave ou indice errado) virar um
404 com a chave no texto. Agora KeyError/IndexError seguem como qualquer bug:
500 generico, com o detalhe so no log.
"""


class RecursoNaoEncontrado(Exception):
    """Recurso inexistente, ou ocultado de quem nao tem acesso (404)."""

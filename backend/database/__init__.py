"""Camada de acesso ao banco (MySQL puro, sem ORM)."""

from database.connection import (  # noqa: F401
    execute,
    get_connection,
    init_database,
    insert,
    install_procedures,
    install_schema,
    query_all,
    query_one,
    transacao,
)

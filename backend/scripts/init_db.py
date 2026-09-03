"""Cria o banco, roda o schema e instala as procedures.

Uso (a partir da pasta backend):
    python scripts/init_db.py

O app.py tambem faz isso ao subir; este script existe para conseguir
recriar o banco sem precisar subir o Flask.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from config import DB_CONFIG
from database.connection import (
    init_database,
    install_procedures,
    install_schema,
    query_all,
)


def main():
    print("Banco alvo: %s@%s:%s/%s" % (
        DB_CONFIG["user"], DB_CONFIG["host"], DB_CONFIG["port"], DB_CONFIG["database"]
    ))

    init_database()
    print("  [ok] banco criado (ou ja existia)")

    install_schema()
    print("  [ok] schema.sql aplicado")

    install_procedures()
    print("  [ok] procedures.sql aplicado")

    tabelas = [list(linha.values())[0] for linha in query_all("SHOW TABLES")]
    print("\nTabelas (%d): %s" % (len(tabelas), ", ".join(tabelas)))

    procedures = query_all(
        "SELECT ROUTINE_NAME FROM information_schema.ROUTINES "
        "WHERE ROUTINE_SCHEMA = %s AND ROUTINE_TYPE = 'PROCEDURE' "
        "ORDER BY ROUTINE_NAME",
        (DB_CONFIG["database"],),
    )
    nomes = [p["ROUTINE_NAME"] for p in procedures]
    print("Procedures (%d): %s" % (len(nomes), ", ".join(nomes)))


if __name__ == "__main__":
    main()

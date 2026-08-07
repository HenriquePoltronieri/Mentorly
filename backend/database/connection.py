import os
import re

import pymysql

from config import DB_CONFIG

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROCEDURES_FILE = os.path.join(BASE_DIR, "database", "procedures.sql")


def init_database():
    connection = pymysql.connect(
        host=DB_CONFIG["host"],
        port=DB_CONFIG["port"],
        user=DB_CONFIG["user"],
        password=DB_CONFIG["password"],
    )
    try:
        with connection.cursor() as cursor:
            cursor.execute(f"CREATE DATABASE IF NOT EXISTS {DB_CONFIG['database']}")
        connection.commit()
    finally:
        connection.close()


def install_procedures():
    """Executa o arquivo procedures.sql no banco de dados.

    Divide o arquivo em statements individuais (separados por ';')
    e executa cada um, pois o PyMySQL não suporta múltiplos
    statements em uma única chamada.
    """
    if not os.path.exists(PROCEDURES_FILE):
        return False

    connection = pymysql.connect(
        host=DB_CONFIG["host"],
        port=DB_CONFIG["port"],
        user=DB_CONFIG["user"],
        password=DB_CONFIG["password"],
        database=DB_CONFIG["database"],
    )
    try:
        with connection.cursor() as cursor:
            with open(PROCEDURES_FILE, "r", encoding="utf-8") as file:
                content = file.read()

            # Remove comentários de linha (-- ...)
            content = re.sub(r"--[^\n]*", "", content)

            # Divide em blocos de procedures (cada um termina com 'END;')
            # e statements simples (CREATE TABLE, etc.)
            blocks = re.split(r"END;", content)
            statements = []
            for block in blocks:
                block = block.strip()
                if not block:
                    continue
                if "BEGIN" in block:
                    statements.append(block + "END;")
                else:
                    # Statement simples (sem BEGIN/END)
                    for stmt in block.split(";"):
                        stmt = stmt.strip()
                        if stmt:
                            statements.append(stmt)

            for statement in statements:
                cursor.execute(statement)
        connection.commit()
        return True
    finally:
        connection.close()
"""Acesso ao MySQL em SQL puro, sem ORM.

Este modulo e a unica porta de entrada para o banco. Os Models e os
Repositories usam os helpers daqui (query_all, query_one, execute,
insert, transacao) e escrevem SQL direto.
"""

import os

import pymysql
from pymysql.cursors import DictCursor

from config import DB_CONFIG

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCHEMA_FILE = os.path.join(BASE_DIR, "database", "schema.sql")
PROCEDURES_FILE = os.path.join(BASE_DIR, "database", "procedures.sql")


# ---------------------------------------------------------------------
# Conexao
# ---------------------------------------------------------------------

def get_connection(com_banco=True):
    """Abre uma conexao nova. com_banco=False serve para o CREATE DATABASE,
    que precisa rodar antes do banco existir."""
    parametros = {
        "host": DB_CONFIG["host"],
        "port": DB_CONFIG["port"],
        "user": DB_CONFIG["user"],
        "password": DB_CONFIG["password"],
        "charset": "utf8mb4",
        "cursorclass": DictCursor,
        "autocommit": False,
    }
    if com_banco:
        parametros["database"] = DB_CONFIG["database"]
    return pymysql.connect(**parametros)


# ---------------------------------------------------------------------
# Helpers de consulta
#
# Todos usam placeholders %s do PyMySQL. Nenhum valor vindo do usuario
# e concatenado na string de SQL.
# ---------------------------------------------------------------------

def query_all(sql, params=None):
    """Roda um SELECT e devolve uma lista de dicts."""
    conexao = get_connection()
    try:
        with conexao.cursor() as cursor:
            cursor.execute(sql, params or ())
            return cursor.fetchall()
    finally:
        conexao.close()


def query_one(sql, params=None):
    """Roda um SELECT e devolve o primeiro dict, ou None."""
    conexao = get_connection()
    try:
        with conexao.cursor() as cursor:
            cursor.execute(sql, params or ())
            return cursor.fetchone()
    finally:
        conexao.close()


def execute(sql, params=None):
    """Roda um INSERT/UPDATE/DELETE e devolve quantas linhas foram afetadas."""
    conexao = get_connection()
    try:
        with conexao.cursor() as cursor:
            afetadas = cursor.execute(sql, params or ())
        conexao.commit()
        return afetadas
    finally:
        conexao.close()


def insert(sql, params=None):
    """Roda um INSERT e devolve o id gerado."""
    conexao = get_connection()
    try:
        with conexao.cursor() as cursor:
            cursor.execute(sql, params or ())
            novo_id = cursor.lastrowid
        conexao.commit()
        return novo_id
    finally:
        conexao.close()


class transacao:
    """Agrupa varios comandos em uma transacao so.

    Uso:
        with transacao() as cursor:
            cursor.execute(...)
            cursor.execute(...)

    Se qualquer comando levantar excecao, o bloco inteiro sofre rollback.
    E o que garante que uma importacao de planilha nao deixe metade dos
    alunos gravados.
    """

    def __init__(self):
        self.conexao = None

    def __enter__(self):
        self.conexao = get_connection()
        self.cursor = self.conexao.cursor()
        return self.cursor

    def __exit__(self, tipo_erro, erro, traceback):
        try:
            if tipo_erro is None:
                self.conexao.commit()
            else:
                self.conexao.rollback()
        finally:
            self.cursor.close()
            self.conexao.close()
        return False


# ---------------------------------------------------------------------
# Criacao do banco / schema / procedures
# ---------------------------------------------------------------------

def init_database():
    """Cria o banco se ele ainda nao existir."""
    conexao = get_connection(com_banco=False)
    try:
        with conexao.cursor() as cursor:
            cursor.execute(
                "CREATE DATABASE IF NOT EXISTS `%s` "
                "CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
                % DB_CONFIG["database"]
            )
        conexao.commit()
    finally:
        conexao.close()


def _dividir_statements(conteudo):
    """Divide um arquivo .sql em comandos individuais.

    O PyMySQL executa um comando por vez, e o corpo de uma procedure tem
    varios ';' dentro. Por isso o parser respeita a diretiva DELIMITER:
    dentro de um bloco 'DELIMITER $$' o ';' deixa de separar comandos e
    quem separa passa a ser o '$$'.

    A versao anterior deste parser dividia o arquivo no texto 'END;', o
    que quebrava em qualquer procedure com IF ... END IF dentro.
    """
    delimitador = ";"
    statements = []
    atual = []

    for linha in conteudo.splitlines():
        sem_espaco = linha.strip()

        # Linha de comentario inteira: ignora.
        if not sem_espaco or sem_espaco.startswith("--"):
            continue

        # Troca de delimitador (comando do cliente, nao do servidor).
        if sem_espaco.upper().startswith("DELIMITER "):
            delimitador = sem_espaco.split(None, 1)[1].strip()
            continue

        atual.append(linha)

        if sem_espaco.endswith(delimitador):
            bloco = "\n".join(atual)
            bloco = bloco.rstrip()[: -len(delimitador)].strip()
            if bloco:
                statements.append(bloco)
            atual = []

    resto = "\n".join(atual).strip()
    if resto:
        statements.append(resto)

    return statements


def _rodar_arquivo_sql(caminho):
    if not os.path.exists(caminho):
        return False

    with open(caminho, "r", encoding="utf-8") as arquivo:
        conteudo = arquivo.read()

    conexao = get_connection()
    try:
        with conexao.cursor() as cursor:
            for statement in _dividir_statements(conteudo):
                cursor.execute(statement)
        conexao.commit()
        return True
    finally:
        conexao.close()


def install_schema():
    """Cria as tabelas a partir de database/schema.sql."""
    return _rodar_arquivo_sql(SCHEMA_FILE)


def install_procedures():
    """Instala as stored procedures a partir de database/procedures.sql."""
    return _rodar_arquivo_sql(PROCEDURES_FILE)

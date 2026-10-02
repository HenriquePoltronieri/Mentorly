"""Teste da migration do Marco 7 sobre um banco no formato anterior.

Cria <DB_NAME>_transferencia, portanto nunca usa o banco configurado do
projeto. Confirma o backfill, a preservacao dos dados e a idempotencia.
"""

import os
import sys

_BASE = os.environ.get("DB_NAME", "mentorly_db")
os.environ["DB_NAME"] = _BASE + "_transferencia"

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from config import DB_CONFIG
from database import migrations
from database.connection import (
    _dividir_statements, execute, get_connection, init_database, insert,
    query_all, query_one, SCHEMA_FILE,
)

BANCO = DB_CONFIG["database"]
assert BANCO.endswith("_transferencia")
falhas = []
_passos = [0]


def checar(condicao, descricao):
    _passos[0] += 1
    print("    %s %s" % ("ok  " if condicao else "FALHA", descricao))
    if not condicao:
        falhas.append(descricao)


DDL_LEGADO = [
    "CREATE TABLE coordenacao (id INT AUTO_INCREMENT PRIMARY KEY, "
    "nome VARCHAR(150) NOT NULL, email VARCHAR(150) NOT NULL, "
    "senha_hash VARCHAR(255) NOT NULL, "
    "UNIQUE KEY uk_coordenacao_email (email)) ENGINE=InnoDB",
    "CREATE TABLE turma (id INT AUTO_INCREMENT PRIMARY KEY, "
    "coordenacao_id INT NOT NULL, nome VARCHAR(120) NOT NULL, "
    "ano_letivo INT NOT NULL, UNIQUE KEY uk_turma_nome_escola (coordenacao_id, nome), "
    "UNIQUE KEY uk_turma_escola (coordenacao_id, id)) ENGINE=InnoDB",
    "CREATE TABLE aluno (id INT AUTO_INCREMENT PRIMARY KEY, turma_id INT NOT NULL, "
    "nome VARCHAR(150) NOT NULL, created_at DATETIME NOT NULL, "
    "KEY idx_aluno_turma (turma_id), "
    "CONSTRAINT fk_aluno_turma FOREIGN KEY (turma_id) REFERENCES turma(id) "
    "ON DELETE CASCADE) ENGINE=InnoDB",
]


def recriar_banco():
    conexao = get_connection(com_banco=False)
    try:
        with conexao.cursor() as cursor:
            cursor.execute("DROP DATABASE IF EXISTS `%s`" % BANCO)
        conexao.commit()
    finally:
        conexao.close()
    init_database()
    for ddl in DDL_LEGADO:
        execute(ddl)
    with open(SCHEMA_FILE, encoding="utf-8") as arquivo:
        for statement in _dividir_statements(arquivo.read()):
            if ("CREATE TABLE IF NOT EXISTS ano_letivo" in statement
                    or "CREATE TABLE IF NOT EXISTS aluno_turma_historico" in statement):
                execute(statement)


def main():
    print("Banco temporario: %s" % BANCO)
    recriar_banco()
    try:
        escola = insert(
            "INSERT INTO coordenacao (nome, email, senha_hash) VALUES (%s, %s, 'x')",
            ("Escola legado", "legado@transferencia.local"),
        )
        execute("INSERT INTO ano_letivo (coordenacao_id, ano, status) VALUES (%s, 2026, 'atual')", (escola,))
        turma_a = insert("INSERT INTO turma (coordenacao_id, nome, ano_letivo) VALUES (%s, '1 A', 2026)", (escola,))
        turma_b = insert("INSERT INTO turma (coordenacao_id, nome, ano_letivo) VALUES (%s, '1 B', 2026)", (escola,))
        aluno_a = insert(
            "INSERT INTO aluno (turma_id, nome, created_at) VALUES (%s, 'Ana Silva', '2026-02-01 10:00:00')", (turma_a,))
        aluno_b = insert(
            "INSERT INTO aluno (turma_id, nome, created_at) VALUES (%s, 'Bruno Lima', '2026-03-02 11:00:00')", (turma_b,))

        antes = {"alunos": query_one("SELECT COUNT(*) AS n FROM aluno")["n"],
                 "turmas": query_one("SELECT COUNT(*) AS n FROM turma")["n"]}
        print("\n[1] Primeira execucao")
        checar(migrations._historico_de_turma_dos_alunos() is True,
               "migration cria os vinculos iniciais")
        historicos = query_all(
            "SELECT aluno_id, turma_id, coordenacao_id, ano_letivo, data_inicio, data_fim "
            "FROM aluno_turma_historico ORDER BY aluno_id")
        checar(len(historicos) == 2, "cada aluno legado recebeu um vinculo")
        checar([(h["aluno_id"], h["turma_id"], h["ano_letivo"]) for h in historicos]
               == [(aluno_a, turma_a, 2026), (aluno_b, turma_b, 2026)],
               "vinculos usam turma e ano originais")
        checar(all(h["coordenacao_id"] == escola and h["data_fim"] is None
                   for h in historicos), "vinculos ficam abertos e na escola certa")
        checar(str(historicos[0]["data_inicio"]) == "2026-02-01",
               "data inicial aproveita created_at do aluno")
        checar({"alunos": query_one("SELECT COUNT(*) AS n FROM aluno")["n"],
                "turmas": query_one("SELECT COUNT(*) AS n FROM turma")["n"]} == antes,
               "migration preserva alunos e turmas")

        print("\n[2] Segunda execucao")
        checar(migrations._historico_de_turma_dos_alunos() is False,
               "segunda execucao nao cria registros")
        checar(query_one("SELECT COUNT(*) AS n FROM aluno_turma_historico")["n"] == 2,
               "segunda execucao nao duplica historico")
    finally:
        conexao = get_connection(com_banco=False)
        try:
            with conexao.cursor() as cursor:
                cursor.execute("DROP DATABASE IF EXISTS `%s`" % BANCO)
            conexao.commit()
        finally:
            conexao.close()

    print("\n%d verificacoes, %d falha(s)" % (_passos[0], len(falhas)))
    if falhas:
        sys.exit(1)
    print("MIGRATION TRANSFERENCIA OK")


if __name__ == "__main__":
    main()

"""Teste da migration do Marco 8 num banco anterior ao campo habilitado."""

import os
import sys

_BASE = os.environ.get("DB_NAME", "mentorly_db")
os.environ["DB_NAME"] = _BASE + "_professor_habilitado"
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from config import DB_CONFIG
from database import migrations
from database.connection import execute, get_connection, init_database, insert, query_one

BANCO = DB_CONFIG["database"]
assert BANCO.endswith("_professor_habilitado")
falhas = []
_passos = [0]


def checar(condicao, descricao):
    _passos[0] += 1
    print("    %s %s" % ("ok  " if condicao else "FALHA", descricao))
    if not condicao:
        falhas.append(descricao)


def recriar_banco():
    conexao = get_connection(com_banco=False)
    try:
        with conexao.cursor() as cursor:
            cursor.execute("DROP DATABASE IF EXISTS `%s`" % BANCO)
        conexao.commit()
    finally:
        conexao.close()
    init_database()
    execute(
        "CREATE TABLE coordenacao (id INT AUTO_INCREMENT PRIMARY KEY, "
        "nome VARCHAR(150), email VARCHAR(150), senha_hash VARCHAR(255)) ENGINE=InnoDB"
    )
    execute(
        "CREATE TABLE professor (id INT AUTO_INCREMENT PRIMARY KEY, "
        "coordenacao_id INT NOT NULL, nome VARCHAR(150), email VARCHAR(150), "
        "senha_hash VARCHAR(255) NULL, convite_token VARCHAR(64) NULL) ENGINE=InnoDB"
    )
    execute(
        "CREATE TABLE turma (id INT AUTO_INCREMENT PRIMARY KEY, "
        "coordenacao_id INT NOT NULL, nome VARCHAR(120)) ENGINE=InnoDB"
    )
    execute(
        "CREATE TABLE professor_turma (id INT AUTO_INCREMENT PRIMARY KEY, "
        "coordenacao_id INT NOT NULL, professor_id INT NOT NULL, turma_id INT NOT NULL) ENGINE=InnoDB"
    )


def main():
    print("Banco temporario: %s" % BANCO)
    recriar_banco()
    try:
        escola = insert("INSERT INTO coordenacao (nome, email, senha_hash) VALUES ('Escola', 'e@t', 'x')")
        professor = insert(
            "INSERT INTO professor (coordenacao_id, nome, email, senha_hash, convite_token) "
            "VALUES (%s, 'Ana', 'ana@t', 'hash-legado', 'convite-legado')", (escola,)
        )
        turma = insert("INSERT INTO turma (coordenacao_id, nome) VALUES (%s, '1 A')", (escola,))
        insert(
            "INSERT INTO professor_turma (coordenacao_id, professor_id, turma_id) VALUES (%s, %s, %s)",
            (escola, professor, turma),
        )

        print("\n[1] Primeira execucao")
        checar(migrations._professor_ganha_habilitado() is True,
               "migration cria a coluna habilitado")
        dado = query_one(
            "SELECT senha_hash, convite_token, habilitado FROM professor WHERE id = %s",
            (professor,),
        )
        checar(dado["habilitado"] == 1, "professor legado fica habilitado")
        checar(dado["senha_hash"] == "hash-legado" and dado["convite_token"] == "convite-legado",
               "migration preserva senha e convite")
        checar(query_one("SELECT COUNT(*) AS n FROM professor_turma")["n"] == 1,
               "migration preserva vinculo de turma")
        checar(migrations._coluna_existe("professor", "habilitado"),
               "campo fica persistido no schema")

        print("\n[2] Segunda execucao")
        checar(migrations._professor_ganha_habilitado() is False,
               "segunda execucao e idempotente")
        checar(query_one("SELECT COUNT(*) AS n FROM professor")["n"] == 1,
               "segunda execucao nao duplica professores")
        checar(query_one("SELECT habilitado FROM professor WHERE id = %s", (professor,))["habilitado"] == 1,
               "segunda execucao preserva habilitado")
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
    print("MIGRATION PROFESSOR HABILITADO OK")


if __name__ == "__main__":
    main()

"""Teste da migracao do Marco 6 (ano letivo) sobre um banco no formato ANTIGO.

O schema.sql so cria o que ainda nao existe, entao um banco que ja tem dados
depende da migracao para ganhar o cadastro de anos. Este script prova que ela:
  - preserva todas as turmas, etapas e atividades (nada e apagado nem movido);
  - da ano as turmas que nao tinham, cadastra os anos que ja existiam e escolhe
    o ano atual de cada escola;
  - instala as FKs e e IDEMPOTENTE (rodar de novo nao muda nada);
  - nao mexe numa escola que ja tem ano atual, mesmo se rodar de novo depois
    de uma execucao interrompida.

Ele NAO usa o banco do projeto: cria <DB_NAME>_mig, com o formato antigo das
tabelas, e apaga no final. A data de "hoje" e fixada em 02/10/2026, para o
resultado nao depender do relogio da maquina.

Uso (a partir da pasta backend):
    python scripts/test_migracao_ano_letivo.py
"""

import contextlib
import datetime
import io
import os
import sys

# O banco precisa ser escolhido ANTES de importar config/connection.
_BASE = os.environ.get("DB_NAME", "mentorly_db")
os.environ["DB_NAME"] = _BASE + "_mig"

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import pymysql

from config import DB_CONFIG
from database import migrations
from database.connection import (
    _dividir_statements, execute, get_connection, init_database, insert,
    query_all, query_one, SCHEMA_FILE,
)

BANCO = DB_CONFIG["database"]
assert BANCO.endswith("_mig"), "este teste so mexe em banco temporario *_mig"

HOJE = datetime.date(2026, 10, 2)

falhas = []
_passos = [0]


def checar(condicao, descricao):
    _passos[0] += 1
    if condicao:
        print("    ok   %s" % descricao)
    else:
        print("    FALHA %s" % descricao)
        falhas.append(descricao)


class DataFixa(datetime.date):
    @classmethod
    def today(cls):
        return cls(HOJE.year, HOJE.month, HOJE.day)


# Formato ANTIGO (antes do Marco 6): turma.ano_letivo pode ser NULL e nenhuma
# das duas tabelas aponta para um cadastro de anos.
DDL_LEGADO = [
    "CREATE TABLE coordenacao ("
    " id INT AUTO_INCREMENT PRIMARY KEY, nome VARCHAR(150) NOT NULL,"
    " email VARCHAR(150) NOT NULL, senha_hash VARCHAR(255) NOT NULL,"
    " UNIQUE KEY uk_coordenacao_email (email)) ENGINE=InnoDB",
    "CREATE TABLE turma ("
    " id INT AUTO_INCREMENT PRIMARY KEY, coordenacao_id INT NOT NULL,"
    " nome VARCHAR(120) NOT NULL, ano_letivo INT NULL,"
    " UNIQUE KEY uk_turma_nome_escola (coordenacao_id, nome),"
    " UNIQUE KEY uk_turma_escola (coordenacao_id, id),"
    " CONSTRAINT fk_turma_coordenacao FOREIGN KEY (coordenacao_id)"
    "   REFERENCES coordenacao (id)) ENGINE=InnoDB",
    "CREATE TABLE etapa ("
    " id INT AUTO_INCREMENT PRIMARY KEY, coordenacao_id INT NOT NULL,"
    " nome VARCHAR(80) NOT NULL, ordem INT NOT NULL, ano_letivo INT NOT NULL,"
    " UNIQUE KEY uk_etapa_ordem (coordenacao_id, ano_letivo, ordem),"
    " UNIQUE KEY uk_etapa_escola (coordenacao_id, id),"
    " CONSTRAINT fk_etapa_coordenacao FOREIGN KEY (coordenacao_id)"
    "   REFERENCES coordenacao (id)) ENGINE=InnoDB",
    "CREATE TABLE atividade ("
    " id INT AUTO_INCREMENT PRIMARY KEY, coordenacao_id INT NOT NULL,"
    " turma_id INT NOT NULL, etapa_id INT NULL,"
    " CONSTRAINT fk_atividade_turma FOREIGN KEY (coordenacao_id, turma_id)"
    "   REFERENCES turma (coordenacao_id, id)) ENGINE=InnoDB",
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
    # A tabela nova vem do proprio schema.sql, como acontece num banco real
    # (CREATE TABLE IF NOT EXISTS cria o que falta e ignora o que ja existe).
    with open(SCHEMA_FILE, "r", encoding="utf-8") as arquivo:
        for statement in _dividir_statements(arquivo.read()):
            if "CREATE TABLE IF NOT EXISTS ano_letivo" in statement:
                execute(statement)


def popular_legado():
    """Quatro escolas, cada uma testando um caso da migracao."""
    escolas = {}
    for rotulo in ("com_dados", "sem_ano_corrente", "vazia", "so_turma_sem_ano"):
        escolas[rotulo] = insert(
            "INSERT INTO coordenacao (nome, email, senha_hash) VALUES (%s, %s, 'x')",
            ("Escola %s" % rotulo, "%s@mig.local" % rotulo),
        )

    def turma(escola, nome, ano):
        return insert(
            "INSERT INTO turma (coordenacao_id, nome, ano_letivo) VALUES (%s, %s, %s)",
            (escolas[escola], nome, ano),
        )

    def etapa(escola, nome, ordem, ano):
        return insert(
            "INSERT INTO etapa (coordenacao_id, nome, ordem, ano_letivo) "
            "VALUES (%s, %s, %s, %s)", (escolas[escola], nome, ordem, ano),
        )

    # Escola com dados: turma sem ano + 2025/2026, etapas em 2025/2026/2027.
    t_sem_ano = turma("com_dados", "T sem ano", None)
    t_2025 = turma("com_dados", "T 2025", 2025)
    t_2026 = turma("com_dados", "T 2026", 2026)
    e_2025 = etapa("com_dados", "E1-2025", 1, 2025)
    etapa("com_dados", "E1-2026", 1, 2026)
    etapa("com_dados", "E2-2026", 2, 2026)
    etapa("com_dados", "E1-2027", 1, 2027)
    # Atividade antiga com a etapa de OUTRO ano que o da turma (dado sujo):
    # a migracao so avisa, nao corrige nem apaga.
    insert(
        "INSERT INTO atividade (coordenacao_id, turma_id, etapa_id) VALUES (%s, %s, %s)",
        (escolas["com_dados"], t_2026, e_2025),
    )
    # Escola cujos anos nao incluem o ano corrente (2026): atual = o maior.
    turma("sem_ano_corrente", "T 2024", 2024)
    etapa("sem_ano_corrente", "E1-2023", 1, 2023)
    # Escola sem nenhum dado: nao ganha ano nenhum.
    # Escola com so uma turma sem ano: ganha o ano corrente, como atual.
    turma("so_turma_sem_ano", "T unica", None)
    return escolas, {"t_sem_ano": t_sem_ano, "t_2025": t_2025, "t_2026": t_2026}


def anos_da_escola(escola_id):
    return {
        l["ano"]: l["status"]
        for l in query_all(
            "SELECT ano, status FROM ano_letivo WHERE coordenacao_id = %s", (escola_id,)
        )
    }


def fks_instaladas():
    colunas = ["coordenacao_id", "ano_letivo"]
    return (migrations._colunas_da_fk("turma", "fk_turma_ano_letivo") == colunas
            and migrations._colunas_da_fk("etapa", "fk_etapa_ano_letivo") == colunas)


def turma_ano_e_not_null():
    linha = query_one(
        "SELECT is_nullable AS n FROM information_schema.columns "
        "WHERE table_schema = %s AND table_name = 'turma' "
        "AND column_name = 'ano_letivo'", (BANCO,),
    )
    return linha["n"] == "NO"


def rodar_migracao():
    """Roda a migracao do Marco 6 com a data fixa, devolvendo (agiu, texto)."""
    original = migrations.date
    migrations.date = DataFixa
    saida = io.StringIO()
    try:
        with contextlib.redirect_stdout(saida):
            agiu = migrations._anos_letivos_cadastrados()
    finally:
        migrations.date = original
    return agiu, saida.getvalue()


def main():
    print("Banco temporario: %s" % BANCO)
    recriar_banco()
    escolas, ids = popular_legado()

    antes = {
        "turmas": query_one("SELECT COUNT(*) AS n FROM turma")["n"],
        "etapas": query_one("SELECT COUNT(*) AS n FROM etapa")["n"],
        "atividades": query_one("SELECT COUNT(*) AS n FROM atividade")["n"],
    }
    nomes_antes = sorted(r["nome"] for r in query_all("SELECT nome FROM turma"))

    try:
        print("\n[1] Antes: formato antigo, sem FKs")
        checar(not fks_instaladas(), "as FKs de ano letivo ainda nao existem")
        checar(not turma_ano_e_not_null(), "turma.ano_letivo ainda aceita NULL")
        checar(query_one("SELECT COUNT(*) AS n FROM ano_letivo")["n"] == 0,
               "o cadastro de anos comeca vazio")

        print("\n[2] Primeira execucao da migracao")
        agiu, texto = rodar_migracao()
        checar(agiu is True, "a migracao agiu")
        checar(fks_instaladas(), "as duas FKs foram instaladas")
        checar(turma_ano_e_not_null(), "turma.ano_letivo virou NOT NULL")
        checar("ATENCAO: 1 atividade" in texto,
               "avisou da atividade com etapa de outro ano (sem corrigir)")

        print("\n[3] Dados preservados")
        depois = {
            "turmas": query_one("SELECT COUNT(*) AS n FROM turma")["n"],
            "etapas": query_one("SELECT COUNT(*) AS n FROM etapa")["n"],
            "atividades": query_one("SELECT COUNT(*) AS n FROM atividade")["n"],
        }
        checar(depois == antes, "mesma quantidade de turmas, etapas e atividades: %s" % depois)
        checar(sorted(r["nome"] for r in query_all("SELECT nome FROM turma")) == nomes_antes,
               "as turmas continuam com os mesmos nomes")
        ano = lambda nome: query_one("SELECT ano_letivo AS a FROM turma WHERE nome = %s", (nome,))["a"]
        checar(ano("T 2025") == 2025 and ano("T 2026") == 2026,
               "turmas que ja tinham ano mantem o ano")
        checar(ano("T sem ano") == 2026,
               "turma sem ano recebeu o ano corrente (2026), o que o sistema ja assumia")
        checar(ano("T 2024") == 2024, "turma de outra escola nao foi alterada")

        print("\n[3b] Anos cadastrados e escolha do atual")
        a = anos_da_escola(escolas["com_dados"])
        checar(a == {2025: "encerrado", 2026: "atual", 2027: "planejamento"},
               "escola com dados: 2025 encerrado, 2026 atual, 2027 planejamento -> %s" % a)
        a = anos_da_escola(escolas["sem_ano_corrente"])
        checar(a == {2023: "encerrado", 2024: "atual"},
               "escola sem o ano corrente: o maior ano vira atual -> %s" % a)
        a = anos_da_escola(escolas["vazia"])
        checar(a == {}, "escola sem dados nao ganha ano nenhum")
        a = anos_da_escola(escolas["so_turma_sem_ano"])
        checar(a == {2026: "atual"}, "escola so com turma sem ano ganha o corrente como atual -> %s" % a)
        atuais = query_one(
            "SELECT COUNT(*) AS n FROM (SELECT coordenacao_id FROM ano_letivo "
            "WHERE status = 'atual' GROUP BY coordenacao_id HAVING COUNT(*) > 1) x"
        )["n"]
        checar(atuais == 0, "nenhuma escola ficou com dois anos atuais")

        print("\n[4] Idempotencia: segunda execucao")
        foto = query_all("SELECT coordenacao_id, ano, status FROM ano_letivo ORDER BY id")
        agiu, _ = rodar_migracao()
        checar(agiu is False, "a migracao reconhece que ja foi aplicada")
        checar(query_all("SELECT coordenacao_id, ano, status FROM ano_letivo ORDER BY id") == foto,
               "o cadastro de anos nao mudou")

        print("\n[5] Execucao interrompida: continua sem desfazer o que o usuario fez")
        # Simula uma execucao que parou antes das FKs, depois de o usuario ter
        # mexido nos anos da escola 'sem_ano_corrente' (agora 2023 e o atual).
        execute("ALTER TABLE turma DROP FOREIGN KEY fk_turma_ano_letivo")
        execute("ALTER TABLE etapa DROP FOREIGN KEY fk_etapa_ano_letivo")
        execute("ALTER TABLE turma MODIFY ano_letivo INT NULL")
        escola = escolas["sem_ano_corrente"]
        execute("UPDATE ano_letivo SET status = 'planejamento' WHERE coordenacao_id = %s", (escola,))
        execute("UPDATE ano_letivo SET status = 'atual' WHERE coordenacao_id = %s AND ano = 2023", (escola,))
        insert("INSERT INTO turma (coordenacao_id, nome, ano_letivo) VALUES (%s, %s, NULL)",
               (escola, "T nova sem ano"))
        agiu, _ = rodar_migracao()
        checar(agiu is True and fks_instaladas() and turma_ano_e_not_null(),
               "a nova execucao reinstala as FKs")
        checar(anos_da_escola(escola) == {2023: "atual", 2024: "planejamento", 2026: "planejamento"},
               "nao trocou o ano atual escolhido pelo usuario -> %s" % anos_da_escola(escola))
        checar(ano("T nova sem ano") == 2026, "a turma sem ano recebeu o ano corrente")

        print("\n[6] Depois: o banco passa a fazer valer a regra")
        try:
            insert("INSERT INTO turma (coordenacao_id, nome, ano_letivo) VALUES (%s, %s, %s)",
                   (escolas["com_dados"], "T ano inexistente", 2031))
            checar(False, "turma em ano nao cadastrado foi recusada")
        except pymysql.err.IntegrityError:
            checar(True, "turma em ano nao cadastrado foi recusada")
        try:
            insert("INSERT INTO etapa (coordenacao_id, nome, ordem, ano_letivo) VALUES (%s, %s, %s, %s)",
                   (escolas["vazia"], "E fora", 1, 2026))
            checar(False, "etapa em ano que a escola nao tem foi recusada")
        except pymysql.err.IntegrityError:
            checar(True, "etapa em ano que a escola nao tem foi recusada")
    finally:
        conexao = get_connection(com_banco=False)
        try:
            with conexao.cursor() as cursor:
                cursor.execute("DROP DATABASE IF EXISTS `%s`" % BANCO)
            conexao.commit()
        finally:
            conexao.close()
        print("\nBanco temporario %s removido." % BANCO)

    print("\n" + "=" * 62)
    print("%d verificacoes, %d falha(s)" % (_passos[0], len(falhas)))
    if falhas:
        print("MIGRACAO FALHOU:")
        for f in falhas:
            print("  - %s" % f)
        sys.exit(1)
    print("MIGRACAO OK")


if __name__ == "__main__":
    main()

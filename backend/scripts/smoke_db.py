"""Teste de fumaca da Etapa 0: escrita e leitura no banco.

Prova tres coisas antes de qualquer feature ser construida em cima:
  1. A conexao em SQL puro funciona (INSERT + SELECT de volta).
  2. O caminho coordenacao -> turma -> professor -> vinculo -> aluno fecha.
  3. O banco RECUSA vincular um professor da escola A a uma turma da
     escola B. Esse e o ponto critico do desenho: o isolamento por escola
     e uma invariante da FK composta, nao so uma clausula WHERE.

Uso (a partir da pasta backend):
    python scripts/smoke_db.py

O script limpa os dados de teste que ele mesmo cria ao terminar.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import pymysql

from database.connection import execute, insert, query_all, query_one
from database.procedure import call_procedure

MARCADOR = "smoke-test@mentorly.local"


def limpar():
    """Remove o que este script cria, respeitando a ordem das FKs."""
    escolas = query_all(
        "SELECT id FROM coordenacao WHERE email LIKE %s", ("%" + MARCADOR,)
    )
    for escola in escolas:
        cid = escola["id"]
        execute(
            "DELETE FROM professor_turma WHERE coordenacao_id = %s", (cid,)
        )
        execute(
            "DELETE FROM aluno WHERE turma_id IN "
            "(SELECT id FROM turma WHERE coordenacao_id = %s)", (cid,)
        )
        execute("DELETE FROM turma WHERE coordenacao_id = %s", (cid,))
        execute("DELETE FROM professor WHERE coordenacao_id = %s", (cid,))
        execute("DELETE FROM coordenacao WHERE id = %s", (cid,))


def criar_escola(rotulo):
    """Cria uma escola completa: coordenacao, turma, professor, aluno."""
    coordenacao_id = insert(
        "INSERT INTO coordenacao (nome, email, senha_hash, telefone) "
        "VALUES (%s, %s, %s, %s)",
        ("Escola %s" % rotulo, "%s.%s" % (rotulo.lower(), MARCADOR),
         "hash-de-teste", "31999990000"),
    )
    turma_id = insert(
        "INSERT INTO turma (coordenacao_id, nome, descricao, ano_letivo) "
        "VALUES (%s, %s, %s, %s)",
        (coordenacao_id, "9 Ano %s" % rotulo, "Turma de teste", 2026),
    )
    professor_id = insert(
        "INSERT INTO professor (coordenacao_id, nome, email, disciplina) "
        "VALUES (%s, %s, %s, %s)",
        (coordenacao_id, "Professor %s" % rotulo,
         "prof.%s.%s" % (rotulo.lower(), MARCADOR), "Matematica"),
    )
    insert(
        "INSERT INTO professor_turma (coordenacao_id, professor_id, turma_id) "
        "VALUES (%s, %s, %s)",
        (coordenacao_id, professor_id, turma_id),
    )
    insert(
        "INSERT INTO aluno (turma_id, nome, matricula) VALUES (%s, %s, %s)",
        (turma_id, "Aluno Teste %s" % rotulo, "MAT-%s-1" % rotulo),
    )
    return coordenacao_id, turma_id, professor_id


def main():
    falhas = []

    print("Limpando restos de execucoes anteriores...")
    limpar()

    # ---------------------------------------------------------------
    print("\n[1] Escrita: criando duas escolas independentes")
    escola_a = criar_escola("A")
    escola_b = criar_escola("B")
    print("    escola A -> coordenacao=%s turma=%s professor=%s" % escola_a)
    print("    escola B -> coordenacao=%s turma=%s professor=%s" % escola_b)

    coord_a, turma_a, prof_a = escola_a
    coord_b, turma_b, prof_b = escola_b

    # ---------------------------------------------------------------
    print("\n[2] Leitura: buscando de volta o que foi gravado")
    linha = query_one(
        "SELECT nome, email, telefone FROM coordenacao WHERE id = %s", (coord_a,)
    )
    print("    coordenacao A: %s" % linha)
    if not linha or linha["nome"] != "Escola A":
        falhas.append("nao leu de volta a coordenacao gravada")

    alunos = query_all(
        "SELECT al.nome, al.matricula, t.nome AS turma "
        "FROM aluno al INNER JOIN turma t ON t.id = al.turma_id "
        "WHERE t.coordenacao_id = %s",
        (coord_a,),
    )
    print("    alunos da escola A: %s" % alunos)
    if len(alunos) != 1:
        falhas.append("esperava 1 aluno na escola A, veio %d" % len(alunos))

    # ---------------------------------------------------------------
    print("\n[3] Isolamento: a escola A nao pode enxergar dados da B")
    turmas_a = query_all(
        "SELECT id, nome FROM turma WHERE coordenacao_id = %s", (coord_a,)
    )
    print("    turmas visiveis para A: %s" % turmas_a)
    if any(t["id"] == turma_b for t in turmas_a):
        falhas.append("turma da escola B apareceu na listagem da escola A")

    # ---------------------------------------------------------------
    print("\n[4] Ponto critico: vincular professor de A a turma de B")
    try:
        insert(
            "INSERT INTO professor_turma (coordenacao_id, professor_id, turma_id) "
            "VALUES (%s, %s, %s)",
            (coord_a, prof_a, turma_b),
        )
        falhas.append(
            "o banco ACEITOU vincular professor da escola A a turma da escola B"
        )
        print("    FALHOU: o vinculo entre escolas foi aceito")
    except pymysql.err.IntegrityError as erro:
        print("    OK: o banco recusou (%s)" % str(erro)[:90])

    # Mesma tentativa disfarcando a coordenacao_id, como faria um cliente
    # malicioso que descobriu o id da turma da outra escola.
    print("\n[5] Mesma tentativa passando a coordenacao_id da escola B")
    try:
        insert(
            "INSERT INTO professor_turma (coordenacao_id, professor_id, turma_id) "
            "VALUES (%s, %s, %s)",
            (coord_b, prof_a, turma_b),
        )
        falhas.append(
            "o banco ACEITOU o vinculo forjando a coordenacao_id"
        )
        print("    FALHOU: o vinculo forjado foi aceito")
    except pymysql.err.IntegrityError as erro:
        print("    OK: o banco recusou (%s)" % str(erro)[:90])

    # ---------------------------------------------------------------
    print("\n[6] Procedures: rodando com o filtro de escola")
    relatorio = call_procedure("sp_relatorio_turmas_atividades", coord_a)
    print("    sp_relatorio_turmas_atividades(A): %s" % relatorio)
    if any(l["id"] == turma_b for l in relatorio):
        falhas.append("relatorio da escola A trouxe turma da escola B")

    professores = call_procedure("sp_professores_por_coordenacao", coord_a)
    print("    sp_professores_por_coordenacao(A): %s" % professores)
    if len(professores) != 1:
        falhas.append(
            "esperava 1 professor na escola A, veio %d" % len(professores)
        )

    turmas_prof = call_procedure("sp_turmas_do_professor", prof_a)
    print("    sp_turmas_do_professor(prof A): %s" % turmas_prof)
    if len(turmas_prof) != 1 or turmas_prof[0]["id"] != turma_a:
        falhas.append("professor de A nao viu exatamente a turma dele")

    resumo = call_procedure("sp_resumo_sistema", coord_a)
    print("    sp_resumo_sistema(A): %s" % resumo)

    # ---------------------------------------------------------------
    print("\nLimpando os dados de teste...")
    limpar()

    print("\n" + "=" * 60)
    if falhas:
        print("SMOKE TEST FALHOU:")
        for f in falhas:
            print("  - %s" % f)
        sys.exit(1)
    print("SMOKE TEST OK: escrita, leitura, isolamento e procedures.")


if __name__ == "__main__":
    main()

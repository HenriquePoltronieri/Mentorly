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

# Ano fixo dos testes: nada aqui depende do relogio da maquina.
ANO = 2026


def limpar():
    """Remove o que este script cria, respeitando a ordem das FKs."""
    escolas = query_all(
        "SELECT id FROM coordenacao WHERE email LIKE %s", ("%" + MARCADOR,)
    )
    for escola in escolas:
        cid = escola["id"]
        execute("DELETE FROM atividade WHERE coordenacao_id = %s", (cid,))
        execute(
            "DELETE FROM professor_turma WHERE coordenacao_id = %s", (cid,)
        )
        execute(
            "DELETE FROM aluno WHERE turma_id IN "
            "(SELECT id FROM turma WHERE coordenacao_id = %s)", (cid,)
        )
        execute("DELETE FROM criterio WHERE coordenacao_id = %s", (cid,))
        execute("DELETE FROM etapa WHERE coordenacao_id = %s", (cid,))
        execute("DELETE FROM turma WHERE coordenacao_id = %s", (cid,))
        execute("DELETE FROM ano_letivo WHERE coordenacao_id = %s", (cid,))
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
    # Marco 6: turma e etapa so existem em um ano que a escola cadastrou.
    insert(
        "INSERT INTO ano_letivo (coordenacao_id, ano, status) "
        "VALUES (%s, %s, 'atual')",
        (coordenacao_id, ANO),
    )
    turma_id = insert(
        "INSERT INTO turma (coordenacao_id, nome, descricao, ano_letivo) "
        "VALUES (%s, %s, %s, %s)",
        (coordenacao_id, "9 Ano %s" % rotulo, "Turma de teste", ANO),
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
    etapa_id = insert(
        "INSERT INTO etapa "
        "(coordenacao_id, nome, ordem, ano_letivo, nota_minima, nota_maxima) "
        "VALUES (%s, %s, %s, %s, %s, %s)",
        (coordenacao_id, "1 Etapa", 1, ANO, 6, 10),
    )
    criterio_id = insert(
        "INSERT INTO criterio (coordenacao_id, etapa_id, nome, peso) "
        "VALUES (%s, %s, %s, %s)",
        (coordenacao_id, etapa_id, "Provas", 5),
    )
    return coordenacao_id, turma_id, professor_id, etapa_id, criterio_id


def main():
    falhas = []

    print("Limpando restos de execucoes anteriores...")
    limpar()

    # ---------------------------------------------------------------
    print("\n[1] Escrita: criando duas escolas independentes")
    escola_a = criar_escola("A")
    escola_b = criar_escola("B")
    print("    escola A -> coordenacao=%s turma=%s professor=%s "
          "etapa=%s criterio=%s" % escola_a)
    print("    escola B -> coordenacao=%s turma=%s professor=%s "
          "etapa=%s criterio=%s" % escola_b)

    coord_a, turma_a, prof_a, etapa_a, criterio_a = escola_a
    coord_b, turma_b, prof_b, etapa_b, criterio_b = escola_b

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
    # Marco 1: a atividade tambem carrega a escola, com FK composta para
    # turma, etapa e criterio. Antes disso as FKs eram simples
    # (REFERENCES etapa (id)), e o banco aceitava a etapa de outra escola.
    print("\n[6] Atividade da escola A apontando para a etapa da escola B")
    try:
        insert(
            "INSERT INTO atividade "
            "(coordenacao_id, turma_id, professor_id, etapa_id, criterio_id, "
            " titulo, nota_maxima) "
            "VALUES (%s, %s, %s, %s, %s, %s, %s)",
            (coord_a, turma_a, prof_a, etapa_b, criterio_a,
             "Atividade cruzada", 20),
        )
        falhas.append("o banco ACEITOU atividade com etapa de outra escola")
        print("    FALHOU: a atividade cruzada foi aceita")
    except pymysql.err.IntegrityError as erro:
        print("    OK: o banco recusou (%s)" % str(erro)[:90])

    print("\n[7] Mesma atividade com o criterio da escola B")
    try:
        insert(
            "INSERT INTO atividade "
            "(coordenacao_id, turma_id, professor_id, etapa_id, criterio_id, "
            " titulo, nota_maxima) "
            "VALUES (%s, %s, %s, %s, %s, %s, %s)",
            (coord_a, turma_a, prof_a, etapa_a, criterio_b,
             "Atividade cruzada", 20),
        )
        falhas.append("o banco ACEITOU atividade com criterio de outra escola")
        print("    FALHOU: o criterio cruzado foi aceito")
    except pymysql.err.IntegrityError as erro:
        print("    OK: o banco recusou (%s)" % str(erro)[:90])

    print("\n[8] Atividade legada: sem etapa nem criterio, continua valida")
    legada = insert(
        "INSERT INTO atividade "
        "(coordenacao_id, turma_id, professor_id, titulo) "
        "VALUES (%s, %s, %s, %s)",
        (coord_a, turma_a, prof_a, "Atividade sem etapa"),
    )
    if legada:
        print("    OK: em FK composta, chave com NULL nao e checada")
    else:
        falhas.append("atividade legada (sem etapa) foi recusada")

    print("\n[9] Atividade coerente dentro da escola A")
    valida = insert(
        "INSERT INTO atividade "
        "(coordenacao_id, turma_id, professor_id, etapa_id, criterio_id, "
        " titulo, nota_maxima) "
        "VALUES (%s, %s, %s, %s, %s, %s, %s)",
        (coord_a, turma_a, prof_a, etapa_a, criterio_a, "Prova 1", 20),
    )
    if valida:
        print("    OK: a combinacao correta e aceita")
    else:
        falhas.append("atividade valida da propria escola foi recusada")

    # ---------------------------------------------------------------
    print("\n[10] Procedures: rodando com o filtro de escola")
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
    # Marco 6: o ano letivo e um cadastro da escola, e turma/etapa so podem
    # apontar para um ano que ela tem. As escolas A e B ja tem 2026 atual:
    # a mesma escola nao repete ano, escolas diferentes podem.
    def deve_recusar(titulo, sql, params, falha):
        try:
            insert(sql, params)
            falhas.append(falha)
            print("    FALHOU: %s" % titulo)
        except pymysql.err.MySQLError as erro:
            print("    OK: o banco recusou (%s)" % str(erro)[:90])

    print("\n[11] Ano letivo: turma em ano que a escola nao cadastrou")
    deve_recusar(
        "turma em ano nao cadastrado",
        "INSERT INTO turma (coordenacao_id, nome, ano_letivo) VALUES (%s, %s, %s)",
        (coord_a, "Turma sem ano cadastrado", 2031),
        "o banco ACEITOU turma em ano que a escola nao cadastrou",
    )

    print("\n[12] Ano letivo: turma de A no ano cadastrado so pela escola B")
    insert(
        "INSERT INTO ano_letivo (coordenacao_id, ano, status) "
        "VALUES (%s, %s, 'planejamento')",
        (coord_b, 2030),
    )
    deve_recusar(
        "turma de A usando ano de B",
        "INSERT INTO turma (coordenacao_id, nome, ano_letivo) VALUES (%s, %s, %s)",
        (coord_a, "Turma no ano da escola B", 2030),
        "o banco ACEITOU turma da escola A em ano que so a escola B tem",
    )

    print("\n[13] Ano letivo: etapa em ano que a escola nao cadastrou")
    deve_recusar(
        "etapa em ano nao cadastrado",
        "INSERT INTO etapa (coordenacao_id, nome, ordem, ano_letivo) "
        "VALUES (%s, %s, %s, %s)",
        (coord_a, "Etapa de 2031", 1, 2031),
        "o banco ACEITOU etapa em ano que a escola nao cadastrou",
    )

    print("\n[14] Ano letivo: mesmo ano duas vezes na mesma escola")
    deve_recusar(
        "ano repetido na escola",
        "INSERT INTO ano_letivo (coordenacao_id, ano, status) VALUES (%s, %s, %s)",
        (coord_a, ANO, "planejamento"),
        "o banco ACEITOU o mesmo ano duas vezes na mesma escola",
    )
    mesmos = query_all(
        "SELECT coordenacao_id FROM ano_letivo "
        "WHERE ano = %s AND coordenacao_id IN (%s, %s)",
        (ANO, coord_a, coord_b),
    )
    if len(mesmos) == 2:
        print("    OK: escolas diferentes podem ter o mesmo ano (A e B tem %d)" % ANO)
    else:
        falhas.append("escolas diferentes nao conseguiram ter o mesmo ano")

    print("\n[15] Ano letivo: so um ano atual por escola")
    insert(
        "INSERT INTO ano_letivo (coordenacao_id, ano, status) "
        "VALUES (%s, %s, 'planejamento')",
        (coord_a, 2027),
    )
    try:
        execute(
            "UPDATE ano_letivo SET status = 'atual' "
            "WHERE coordenacao_id = %s AND ano = %s", (coord_a, 2027),
        )
        falhas.append("o banco ACEITOU dois anos atuais na mesma escola")
        print("    FALHOU: dois anos atuais")
    except pymysql.err.IntegrityError as erro:
        print("    OK: o banco recusou (%s)" % str(erro)[:90])
    # Anos fora de 'atual' podem ser varios (planejamento e encerrado repetem).
    insert(
        "INSERT INTO ano_letivo (coordenacao_id, ano, status) "
        "VALUES (%s, %s, 'encerrado')", (coord_a, 2025),
    )
    insert(
        "INSERT INTO ano_letivo (coordenacao_id, ano, status) "
        "VALUES (%s, %s, 'encerrado')", (coord_a, 2024),
    )
    print("    OK: anos encerrados e em planejamento podem ser varios")

    print("\n[16] Ano letivo: status invalido e turma sem ano")
    deve_recusar(
        "status fora da lista",
        "INSERT INTO ano_letivo (coordenacao_id, ano, status) VALUES (%s, %s, %s)",
        (coord_a, 2040, "qualquer"),
        "o banco ACEITOU um status invalido",
    )
    deve_recusar(
        "turma sem ano",
        "INSERT INTO turma (coordenacao_id, nome, ano_letivo) VALUES (%s, %s, NULL)",
        (coord_a, "Turma sem ano"),
        "o banco ACEITOU turma sem ano letivo",
    )

    print("\n[17] Ano letivo: nao se apaga ano que ainda tem turma")
    try:
        execute(
            "DELETE FROM ano_letivo WHERE coordenacao_id = %s AND ano = %s",
            (coord_a, ANO),
        )
        falhas.append("o banco ACEITOU apagar um ano que tem turma e etapa")
        print("    FALHOU: o ano com dados foi apagado")
    except pymysql.err.IntegrityError as erro:
        print("    OK: o banco recusou (%s)" % str(erro)[:90])

    # ---------------------------------------------------------------
    print("\nLimpando os dados de teste...")
    limpar()

    print("\n" + "=" * 60)
    if falhas:
        print("SMOKE TEST FALHOU:")
        for f in falhas:
            print("  - %s" % f)
        sys.exit(1)
    print("SMOKE TEST OK: escrita, leitura, isolamento, ano letivo e procedures.")


if __name__ == "__main__":
    main()

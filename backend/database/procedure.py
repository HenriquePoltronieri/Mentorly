"""Unico lugar do projeto onde um CALL de procedure e emitido.

A regra da arquitetura e que SQL e CALL nao aparecem no Controller nem no
Service: quem conversa com o banco e a Model ou o Repository, e os
Repositories chamam call_procedure daqui.
"""

from database.connection import get_connection

# Procedures que o backend pode chamar. O nome da procedure entra na string
# de SQL (nao da para usar placeholder para identificador), entao ele e
# validado contra esta lista em vez de ser interpolado direto.
PROCEDURES_PERMITIDAS = {
    "sp_relatorio_turmas_atividades",
    "sp_buscar_atividades",
    "sp_professores_por_coordenacao",
    "sp_resumo_sistema",
    "sp_turmas_do_professor",
    "sp_alunos_em_risco",
}


def call_procedure(proc_name, *args):
    """Executa uma stored procedure e devolve as linhas como lista de dicts."""
    if proc_name not in PROCEDURES_PERMITIDAS:
        raise ValueError("Procedure nao permitida: %s" % proc_name)

    placeholders = ", ".join(["%s"] * len(args))
    sql = "CALL %s(%s)" % (proc_name, placeholders)

    conexao = get_connection()
    try:
        with conexao.cursor() as cursor:
            cursor.execute(sql, args)
            linhas = cursor.fetchall()
        # Procedure com SELECT deixa o resultado pendente na conexao;
        # o commit fecha a transacao implicita aberta pelo CALL.
        conexao.commit()
        return linhas
    finally:
        conexao.close()

from sqlalchemy import text

from database import db


def call_procedure(proc_name, *args):
    """Executa uma stored procedure do MySQL e retorna os resultados.

    A primeira query retorna o conjunto de dados da procedure.
    """
    placeholders = ", ".join([":arg%d" % i for i in range(len(args))])
    sql = text("CALL %s(%s)" % (proc_name, placeholders))
    params = {"arg%d" % i: value for i, value in enumerate(args)}

    result = db.session.execute(sql, params)
    rows = [dict(row._mapping) for row in result.fetchall()]
    return rows
"""Model do codigo de verificacao em duas etapas."""

from datetime import datetime, timedelta

from config import CODIGO_EXPIRACAO_MINUTOS
from database.connection import execute, insert, query_one


class CodigoVerificacao:
    TABELA = "codigo_verificacao"

    @staticmethod
    def criar(email, codigo):
        """Invalida os codigos anteriores do email e grava um novo.

        Sem a invalidacao, um codigo antigo continuaria valendo depois de o
        usuario pedir outro.
        """
        execute(
            "UPDATE codigo_verificacao SET usado = 1 "
            "WHERE email = %s AND usado = 0",
            (email,),
        )
        expira_em = datetime.now() + timedelta(minutes=CODIGO_EXPIRACAO_MINUTOS)
        return insert(
            "INSERT INTO codigo_verificacao (email, codigo, expira_em) "
            "VALUES (%s, %s, %s)",
            (email, codigo, expira_em),
        )

    @staticmethod
    def validar(email, codigo):
        """Confere o codigo e o marca como usado. Devolve True/False."""
        linha = query_one(
            "SELECT id FROM codigo_verificacao "
            "WHERE email = %s AND codigo = %s AND usado = 0 "
            "AND expira_em > NOW() "
            "ORDER BY id DESC LIMIT 1",
            (email, codigo),
        )
        if not linha:
            return False
        execute(
            "UPDATE codigo_verificacao SET usado = 1 WHERE id = %s",
            (linha["id"],),
        )
        return True

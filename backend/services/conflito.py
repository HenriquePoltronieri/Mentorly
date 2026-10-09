"""Conflito de integridade esperado em uma exclusao (vira HTTP 409).

O banco recusa apagar um registro que ainda e referenciado por outro (FK com
ON DELETE RESTRICT): e a protecao dos dados funcionando. Aqui so se reconhece
esse caso especifico - violacao de FK ao APAGAR - para o service devolver uma
mensagem de negocio. Qualquer outro erro de banco continua subindo como esta,
para um bug real nao ser confundido com "tem dados vinculados".
"""

import pymysql

# 1451: nao da para apagar/alterar a linha pai (FK). 1217: o mesmo, em versoes
# antigas do MySQL.
_FK_AO_APAGAR = (1451, 1217)


# 1062: valor duplicado em indice unico.
_DUPLICADO = (1062,)


class ConflitoDeIntegridade(Exception):
    """A exclusao e valida, mas colide com dados que dependem do registro."""


def excluir_ou_conflito(excluir, mensagem):
    """Roda a exclusao; violacao de FK vira ConflitoDeIntegridade(mensagem).

    A mensagem e a do projeto: o erro bruto, o SQL e o nome da constraint ficam
    so na excecao original (encadeada), nunca na resposta.
    """
    try:
        return excluir()
    except pymysql.err.IntegrityError as erro:
        if erro.args and erro.args[0] in _FK_AO_APAGAR:
            raise ConflitoDeIntegridade(mensagem) from erro
        raise


def gravar_ou_conflito(gravar, mensagem):
    """Roda a gravacao; violacao de indice unico (1062) vira ConflitoDeIntegridade.

    Rede de seguranca para a corrida entre dois pedidos: o service ja confere a
    duplicidade antes, o banco tem a ultima palavra. Outros erros sobem.
    """
    try:
        return gravar()
    except pymysql.err.IntegrityError as erro:
        if erro.args and erro.args[0] in _DUPLICADO:
            raise ConflitoDeIntegridade(mensagem) from erro
        raise

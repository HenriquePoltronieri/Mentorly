"""Validacao das linhas vindas de planilha (e do cadastro manual).

A regra de negocio pedida e "nome completo obrigatorio". Aqui isso vira:
nao vazio, com pelo menos dois termos de 2+ letras. Assim "Joao" e recusado
mas "Ana Lima" passa.
"""

import math
import re

from services import entrada

# Validacao proposital de email: so o formato basico. Nao vale recusar um
# email real por causa de uma regex esperta demais.
_EMAIL = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


def validar_nome_completo(nome):
    """Devolve (nome_limpo, erro). erro e None quando esta tudo certo."""
    if nome is not None and not isinstance(nome, str):
        return None, "nome invalido"
    nome = (nome or "").strip()
    nome = re.sub(r"\s+", " ", nome)

    if not nome:
        return None, "nome vazio"
    if len(nome) > entrada.LIMITE_NOME:
        return None, "nome muito longo (maximo %d caracteres)" % entrada.LIMITE_NOME

    partes = [p for p in nome.split(" ") if len(p) >= 2]
    if len(partes) < 2:
        return None, "nome incompleto (informe nome e sobrenome)"

    return nome, None


def validar_email(email):
    """Devolve (email_limpo_ou_None, erro). Usada no cadastro/importacao e
    tambem na edicao de aluno (services/aluno/gerenciar_aluno.py), para as
    duas nao aceitarem formatos diferentes de email."""
    if email is not None and not isinstance(email, str):
        return None, "email invalido"
    email = (email or "").strip().lower() or None
    if email and len(email) > entrada.LIMITE_EMAIL:
        return None, "email muito longo (maximo %d caracteres)" % entrada.LIMITE_EMAIL
    if email and not _EMAIL.match(email):
        return None, "email invalido"
    return email, None


def validar_linha_aluno(linha):
    """Valida uma linha de aluno. Devolve (dados, erro)."""
    nome, erro = validar_nome_completo(linha.get("nome"))
    if erro:
        return None, erro

    matricula = linha.get("matricula")
    if matricula is not None and not isinstance(matricula, str):
        return None, "matricula invalida"
    matricula = (matricula or "").strip() or None
    if matricula and len(matricula) > entrada.LIMITE_MATRICULA:
        return None, "matricula muito longa (maximo %d caracteres)" % entrada.LIMITE_MATRICULA

    email, erro = validar_email(linha.get("email"))
    if erro:
        return None, erro

    return {"nome": nome, "matricula": matricula, "email": email}, None


def validar_linha_nota(linha, nota_maxima=None):
    """Valida uma linha de nota. Devolve (dados, erro)."""
    bruto = linha.get("nota")
    if bruto is None or str(bruto).strip() == "":
        return None, "nota vazia"

    # Planilha brasileira costuma vir com virgula decimal.
    texto = str(bruto).strip().replace(",", ".")
    try:
        valor = float(texto)
    except ValueError:
        return None, "nota nao e um numero"

    if not math.isfinite(valor):
        return None, "nota nao e um numero"
    if valor < 0:
        return None, "nota negativa"
    if nota_maxima is not None and valor > float(nota_maxima):
        return None, "nota acima do maximo da atividade (%s)" % nota_maxima

    observacao = (linha.get("observacao") or "").strip() or None
    if observacao and len(observacao) > entrada.LIMITE_OBSERVACAO:
        return None, "observacao muito longa (maximo %d caracteres)" % entrada.LIMITE_OBSERVACAO
    return {"valor": valor, "observacao": observacao}, None

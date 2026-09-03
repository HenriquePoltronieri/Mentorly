"""Validacao das linhas vindas de planilha (e do cadastro manual).

A regra de negocio pedida e "nome completo obrigatorio". Aqui isso vira:
nao vazio, com pelo menos dois termos de 2+ letras. Assim "Joao" e recusado
mas "Ana Lima" passa.
"""

import re

# Validacao proposital de email: so o formato basico. Nao vale recusar um
# email real por causa de uma regex esperta demais.
_EMAIL = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


def validar_nome_completo(nome):
    """Devolve (nome_limpo, erro). erro e None quando esta tudo certo."""
    nome = (nome or "").strip()
    nome = re.sub(r"\s+", " ", nome)

    if not nome:
        return None, "nome vazio"

    partes = [p for p in nome.split(" ") if len(p) >= 2]
    if len(partes) < 2:
        return None, "nome incompleto (informe nome e sobrenome)"

    return nome, None


def validar_linha_aluno(linha):
    """Valida uma linha de aluno. Devolve (dados, erro)."""
    nome, erro = validar_nome_completo(linha.get("nome"))
    if erro:
        return None, erro

    matricula = (linha.get("matricula") or "").strip() or None

    email = (linha.get("email") or "").strip().lower() or None
    if email and not _EMAIL.match(email):
        return None, "email invalido"

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

    if valor < 0:
        return None, "nota negativa"
    if nota_maxima is not None and valor > float(nota_maxima):
        return None, "nota acima do maximo da atividade (%s)" % nota_maxima

    return {
        "valor": valor,
        "observacao": (linha.get("observacao") or "").strip() or None,
    }, None

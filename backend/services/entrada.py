"""Validacao simples de entradas da API: tipo, limite e numero finito.

Existe para a primeira recusa de um valor ruim ser uma mensagem de negocio
(HTTP 400), e nao um erro do driver do MySQL ou um AttributeError. Nao e um
sistema de schemas: so os poucos campos que a auditoria (M-01) provou que
chegavam ao banco ou ao `.strip()` com o tipo errado.

Tudo aqui levanta EntradaInvalida, que e um ValueError: os controllers que ja
respondem 400 para ValueError continuam funcionando, e os que usam 409 para
duplicidade (turma, professor) a tratam antes, para um dado malformado nao
parecer duplicidade.
"""

import math
from datetime import date, datetime

# Limites do schema.sql (VARCHAR) e do DECIMAL(5,2) (ate 999,99).
LIMITE_NOME = 150
LIMITE_EMAIL = 150
LIMITE_TELEFONE = 30
LIMITE_MATRICULA = 50
LIMITE_DISCIPLINA = 100
LIMITE_TURNO = 30
LIMITE_NOME_TURMA = 120
LIMITE_NOME_ETAPA = 80
LIMITE_NOME_CRITERIO = 80
LIMITE_TITULO = 200
LIMITE_OBSERVACAO = 255
# TEXT guarda 65535 bytes e um caractere utf8mb4 ocupa ate 4: 16000 caracteres
# nunca estouram a coluna.
LIMITE_DESCRICAO = 16000
LIMITE_SENHA = 128
LIMITE_CODIGO = 64
MAXIMO_DECIMAL = 999.99
ORDEM_MAXIMA = 1000


class EntradaInvalida(ValueError):
    """Dado enviado com tipo, tamanho ou valor impossivel (vira 400)."""


def texto(valor, rotulo, limite, *, aparar=True):
    """Texto opcional: None vira "". Tipo errado ou acima do limite e erro.

    Nao decide se vazio e aceitavel: cada service ja tem a propria regra e a
    propria mensagem para "obrigatorio". aparar=False preserva o conteudo
    (descricao) e so confere o tamanho.
    """
    if valor is None:
        return ""
    if not isinstance(valor, str):
        raise EntradaInvalida("%s precisa ser um texto" % rotulo)
    resultado = valor.strip() if aparar else valor
    if len(resultado.strip()) > limite:
        raise EntradaInvalida("%s: no maximo %d caracteres" % (rotulo, limite))
    return resultado


def senha(valor, rotulo="A senha"):
    """Senha nunca e aparada; so confere tipo e um teto de tamanho."""
    if valor is None:
        return ""
    if not isinstance(valor, str):
        raise EntradaInvalida("%s precisa ser um texto" % rotulo)
    if len(valor) > LIMITE_SENHA:
        raise EntradaInvalida("%s: no maximo %d caracteres" % (rotulo, LIMITE_SENHA))
    return valor


def numero_finito(bruto, rotulo):
    """float finito a partir de numero ou texto ("7,5" vale 7.5).

    Recusa bool, NaN, Infinity, lista/objeto e texto nao numerico.
    """
    if isinstance(bruto, bool) or not isinstance(bruto, (int, float, str)):
        raise EntradaInvalida("%s precisa ser um numero" % rotulo)
    try:
        valor = float(str(bruto).strip().replace(",", "."))
    except ValueError:
        raise EntradaInvalida("%s precisa ser um numero" % rotulo)
    if not math.isfinite(valor):
        raise EntradaInvalida("%s precisa ser um numero" % rotulo)
    return valor


def numero_na_faixa(bruto, rotulo, minimo=0.0, maximo=MAXIMO_DECIMAL,
                    minimo_exclusivo=False):
    """Numero finito dentro de [minimo, maximo] (ou (minimo, maximo])."""
    valor = numero_finito(bruto, rotulo)
    abaixo = valor <= minimo if minimo_exclusivo else valor < minimo
    if abaixo or valor > maximo:
        if minimo_exclusivo:
            raise EntradaInvalida(
                "%s precisa ser maior que %s e no maximo %s"
                % (rotulo, _limpo(minimo), _limpo(maximo))
            )
        raise EntradaInvalida(
            "%s precisa ficar entre %s e %s"
            % (rotulo, _limpo(minimo), _limpo(maximo))
        )
    return valor


def inteiro(bruto, rotulo):
    """int a partir de int, texto de digitos ou float inteiro finito."""
    if isinstance(bruto, bool) or not isinstance(bruto, (int, float, str)):
        raise EntradaInvalida("%s invalido" % rotulo)
    try:
        if isinstance(bruto, float):
            if not math.isfinite(bruto) or bruto != int(bruto):
                raise ValueError
            return int(bruto)
        return int(str(bruto).strip())
    except (ValueError, OverflowError):
        raise EntradaInvalida("%s invalido" % rotulo)


def data_iso(bruto, rotulo):
    """date a partir de 'AAAA-MM-DD' (ou data e hora ISO). None/"" -> None."""
    if bruto is None:
        return None
    if not isinstance(bruto, str):
        raise EntradaInvalida("%s invalida" % rotulo)
    conteudo = bruto.strip()
    if not conteudo:
        return None
    try:
        return date.fromisoformat(conteudo)
    except ValueError:
        pass
    try:
        return datetime.fromisoformat(conteudo).date()
    except ValueError:
        raise EntradaInvalida("%s invalida (use AAAA-MM-DD)" % rotulo)


def _limpo(valor):
    return str(int(valor)) if float(valor) == int(valor) else str(valor)

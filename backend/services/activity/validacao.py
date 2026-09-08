"""Regras de validacao da atividade, em um lugar so.

Create e Update chamam exatamente estas funcoes. Duplicar a regra nos dois
services seria a maneira mais facil de deixar a edicao mais fraca que a
criacao - que e justamente o buraco que a ETAPA 9 pede para fechar.

Convencao de erro:
  ValueError  -> 400 (o dado enviado esta errado)
  LookupError -> 404 (o id nao existe PARA ESTA ESCOLA)

O 404 e proposital no caso de etapa/criterio de outra coordenacao: um 403
confirmaria que aquele id existe em algum lugar do sistema.
"""

from models.criterio_model import Criterio
from models.etapa_model import Etapa


def validar_nota_maxima(bruto, obrigatorio=True):
    """Converte e valida o valor maximo da atividade.

    Aceita numero, "20" e "20,5" (virgula decimal, que e como o teclado
    brasileiro digita). Recusa vazio, texto, zero e negativo.
    """
    if bruto is None or str(bruto).strip() == "":
        if obrigatorio:
            raise ValueError("Informe quanto a atividade vale")
        return None

    try:
        valor = float(str(bruto).replace(",", "."))
    except (TypeError, ValueError):
        raise ValueError("O valor da atividade precisa ser um numero")

    if valor <= 0:
        raise ValueError("O valor da atividade precisa ser maior que zero")

    return valor


def validar_etapa_e_criterio(coordenacao_id, etapa_id, criterio_id,
                             obrigatorio=True):
    """Confere que a etapa e o criterio sao da escola do token.

    Nunca confia no id que veio do cliente: as duas buscas ja filtram por
    coordenacao_id, entao um id da escola B simplesmente nao e encontrado.
    O criterio ainda precisa pertencer a etapa escolhida - senao daria para
    montar uma combinacao que a Coordenacao nunca configurou.
    """
    if etapa_id is None or str(etapa_id).strip() == "":
        if obrigatorio:
            raise ValueError("Escolha a etapa da atividade")
        etapa_id = None
    if criterio_id is None or str(criterio_id).strip() == "":
        if obrigatorio:
            raise ValueError("Escolha o criterio da atividade")
        criterio_id = None

    if etapa_id is None and criterio_id is None:
        return None, None

    # Criterio sem etapa nao da para checar o pertencimento, entao os dois
    # andam juntos.
    if etapa_id is None or criterio_id is None:
        raise ValueError("Etapa e criterio precisam ser informados juntos")

    try:
        etapa_id = int(etapa_id)
        criterio_id = int(criterio_id)
    except (TypeError, ValueError):
        raise ValueError("Etapa ou criterio invalido")

    etapa = Etapa.find_by_id(etapa_id, coordenacao_id)
    if not etapa:
        raise LookupError("Etapa nao encontrada")

    criterio = Criterio.find_by_id(criterio_id, coordenacao_id)
    if not criterio:
        raise LookupError("Criterio nao encontrado")

    if criterio["etapa_id"] != etapa["id"]:
        raise LookupError("Criterio nao encontrado nesta etapa")

    return etapa["id"], criterio["id"]

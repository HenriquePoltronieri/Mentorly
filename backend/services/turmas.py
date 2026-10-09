from models.turma_model import Turma
from services import entrada
from services.config.anos_letivos import (
    exigir_ano_nao_encerrado,
    resolver_ano_letivo,
    validar_ano,
)
from services.conflito import excluir_ou_conflito


def _descricao(valor):
    """Descricao opcional: so confere tipo e tamanho; o conteudo e preservado."""
    if valor is None:
        return None
    entrada.texto(valor, "A descricao", entrada.LIMITE_DESCRICAO, aparar=False)
    return valor


def _opcional(valor, rotulo, limite):
    """Texto opcional que continua None quando nao veio (None nao altera)."""
    if valor is None:
        return None
    return entrada.texto(valor, rotulo, limite)


def listar_turmas(coordenacao_id, ano_letivo=None):
    """Turmas da escola; com ano_letivo, so as daquele ano."""
    linhas = Turma.find_all_by_coordenacao(coordenacao_id, ano_letivo)
    for linha in linhas:
        linha["total_alunos"] = Turma.contar_alunos(linha["id"])
    return [Turma.to_dict(linha) for linha in linhas]


def buscar_turma(turma_id, coordenacao_id):
    # None resulta em 404, sem revelar turmas de outra escola.
    linha = Turma.find_by_id(turma_id, coordenacao_id)
    if not linha:
        return None
    linha["total_alunos"] = Turma.contar_alunos(turma_id)
    return Turma.to_dict(linha)


def criar_turma(coordenacao_id, nome, descricao=None, disciplina=None,
                turno=None, ano_letivo=None):
    nome = entrada.texto(nome, "O nome da turma", entrada.LIMITE_NOME_TURMA)
    descricao = _descricao(descricao)
    disciplina = _opcional(disciplina, "A disciplina", entrada.LIMITE_DISCIPLINA)
    turno = _opcional(turno, "O turno", entrada.LIMITE_TURNO)
    if not nome:
        raise ValueError("O nome da turma e obrigatorio")

    # O nome e unico dentro da escola, nao no sistema inteiro.
    if Turma.find_by_nome(nome, coordenacao_id):
        raise ValueError("Ja existe uma turma com este nome nesta escola")

    # Toda turma pertence a um ano letivo DESTA escola. Sem ano informado, vale
    # o ano atual da escola (nunca o do relogio); ano de outra escola, ou nao
    # cadastrado, vira LookupError (404); ano encerrado nao recebe turma nova.
    ano = resolver_ano_letivo(coordenacao_id, ano_letivo)["ano"]

    turma_id = Turma.create(
        coordenacao_id, nome, descricao, disciplina, turno, ano
    )
    return Turma.to_dict(Turma.find_by_id(turma_id, coordenacao_id))


def atualizar_turma(turma_id, coordenacao_id, nome=None, descricao=None,
                    disciplina=None, turno=None, ano_letivo=None):
    atual = Turma.find_by_id(turma_id, coordenacao_id)
    if not atual:
        raise LookupError("Turma nao encontrada")
    exigir_ano_nao_encerrado(coordenacao_id, atual["ano_letivo"])

    descricao = _descricao(descricao)
    disciplina = _opcional(disciplina, "A disciplina", entrada.LIMITE_DISCIPLINA)
    turno = _opcional(turno, "O turno", entrada.LIMITE_TURNO)
    if nome is not None:
        nome = entrada.texto(nome, "O nome da turma", entrada.LIMITE_NOME_TURMA)
        if not nome:
            raise ValueError("O nome da turma nao pode ficar vazio")
        duplicada = Turma.find_by_nome(nome, coordenacao_id)
        if duplicada and duplicada["id"] != turma_id:
            raise ValueError("Ja existe uma turma com este nome nesta escola")

    novo_ano = None
    if ano_letivo is not None and str(ano_letivo).strip() != "":
        ano = validar_ano(ano_letivo)
        # Reenviar o ano que a turma ja tem nao pode falhar so porque o ano
        # foi encerrado depois: so uma MUDANCA de ano passa pela validacao.
        if ano != atual["ano_letivo"]:
            resolver_ano_letivo(coordenacao_id, ano)
            # As atividades da turma apontam para etapas do ano antigo; mover
            # a turma de ano deixaria atividade e etapa em anos diferentes.
            if Turma.contar_atividades(turma_id):
                raise ValueError(
                    "A turma ja tem atividades e nao pode mudar de ano letivo"
                )
            novo_ano = ano

    Turma.update(
        turma_id, coordenacao_id, nome, descricao, disciplina, turno,
        novo_ano,
    )
    return Turma.to_dict(Turma.find_by_id(turma_id, coordenacao_id))


def excluir_turma(turma_id, coordenacao_id):
    """O schema cascateia os alunos, atividades e notas da turma excluida."""
    turma = Turma.find_by_id(turma_id, coordenacao_id)
    if not turma:
        raise LookupError("Turma nao encontrada")
    exigir_ano_nao_encerrado(coordenacao_id, turma["ano_letivo"])
    excluir_ou_conflito(
        lambda: Turma.delete(turma_id, coordenacao_id),
        "Esta turma possui dados historicos vinculados e nao pode ser excluida.",
    )

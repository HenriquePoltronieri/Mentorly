from models.turma_model import Turma


def listar_turmas(coordenacao_id):
    linhas = Turma.find_all_by_coordenacao(coordenacao_id)
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
    nome = (nome or "").strip()
    if not nome:
        raise ValueError("O nome da turma e obrigatorio")

    # O nome e unico dentro da escola, nao no sistema inteiro.
    if Turma.find_by_nome(nome, coordenacao_id):
        raise ValueError("Ja existe uma turma com este nome nesta escola")

    turma_id = Turma.create(
        coordenacao_id, nome, descricao, disciplina, turno, ano_letivo
    )
    return Turma.to_dict(Turma.find_by_id(turma_id, coordenacao_id))


def atualizar_turma(turma_id, coordenacao_id, nome=None, descricao=None,
                    disciplina=None, turno=None, ano_letivo=None):
    atual = Turma.find_by_id(turma_id, coordenacao_id)
    if not atual:
        raise LookupError("Turma nao encontrada")

    if nome is not None:
        nome = nome.strip()
        if not nome:
            raise ValueError("O nome da turma nao pode ficar vazio")
        duplicada = Turma.find_by_nome(nome, coordenacao_id)
        if duplicada and duplicada["id"] != turma_id:
            raise ValueError("Ja existe uma turma com este nome nesta escola")

    Turma.update(
        turma_id, coordenacao_id, nome, descricao, disciplina, turno,
        ano_letivo,
    )
    return Turma.to_dict(Turma.find_by_id(turma_id, coordenacao_id))


def excluir_turma(turma_id, coordenacao_id):
    """O schema cascateia os alunos, atividades e notas da turma excluida."""
    if not Turma.find_by_id(turma_id, coordenacao_id):
        raise LookupError("Turma nao encontrada")
    Turma.delete(turma_id, coordenacao_id)

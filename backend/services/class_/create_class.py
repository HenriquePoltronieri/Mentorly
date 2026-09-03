from models.turma_model import Turma


class CreateClassService:
    """Cadastra uma turma na escola de quem esta logado.

    O nome so precisa ser unico dentro da escola: duas coordenacoes
    diferentes podem ter uma turma "9 Ano A" cada uma.
    """

    def execute(self, coordenacao_id, nome, descricao=None, disciplina=None,
                turno=None, ano_letivo=None):
        nome = (nome or "").strip()
        if not nome:
            raise ValueError("O nome da turma e obrigatorio")

        if Turma.find_by_nome(nome, coordenacao_id):
            raise ValueError("Ja existe uma turma com este nome nesta escola")

        turma_id = Turma.create(
            coordenacao_id, nome, descricao, disciplina, turno, ano_letivo
        )
        return Turma.to_dict(Turma.find_by_id(turma_id, coordenacao_id))

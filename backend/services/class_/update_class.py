from models.turma_model import Turma


class UpdateClassService:
    def execute(self, turma_id, coordenacao_id, nome=None, descricao=None,
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

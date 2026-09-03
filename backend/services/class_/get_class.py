from models.turma_model import Turma


class GetClassService:
    """Busca uma turma pelo id, dentro da escola de quem esta logado.

    Turma de outra coordenacao devolve None -> o controller responde 404.
    Responder 404 em vez de 403 evita confirmar que aquele id existe.
    """

    def execute(self, turma_id, coordenacao_id):
        linha = Turma.find_by_id(turma_id, coordenacao_id)
        if not linha:
            return None
        linha["total_alunos"] = Turma.contar_alunos(turma_id)
        return Turma.to_dict(linha)

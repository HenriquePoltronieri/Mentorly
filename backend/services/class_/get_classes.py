from models.turma_model import Turma


class GetClassesService:
    """Lista as turmas da escola de quem esta logado.

    coordenacao_id vem do token (auth/decorators.coordenacao_atual), nunca
    da query string: nao existe forma de o cliente pedir as turmas de outra
    coordenacao.
    """

    def execute(self, coordenacao_id):
        linhas = Turma.find_all_by_coordenacao(coordenacao_id)
        for linha in linhas:
            linha["total_alunos"] = Turma.contar_alunos(linha["id"])
        return [Turma.to_dict(linha) for linha in linhas]

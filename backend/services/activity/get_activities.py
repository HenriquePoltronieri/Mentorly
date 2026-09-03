from models.atividade_model import Atividade


class GetActivitiesService:
    """Lista atividades no recorte de quem esta pedindo.

    Coordenacao ve as atividades da escola (so leitura, para relatorio e
    busca). Professor ve so as das turmas vinculadas a ele.
    """

    def execute(self, coordenacao_id, professor_id=None, turma_id=None):
        if professor_id is not None:
            linhas = Atividade.find_all_by_professor(professor_id, turma_id)
        else:
            linhas = Atividade.find_all_by_coordenacao(coordenacao_id, turma_id)
        return [Atividade.to_dict(linha) for linha in linhas]

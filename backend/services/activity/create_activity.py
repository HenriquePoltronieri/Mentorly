from datetime import datetime

from models.atividade_model import Atividade
from models.professor_turma_model import ProfessorTurma
from models.turma_model import Turma


def parse_data(valor):
    """Aceita string ISO, vazio ou None. Vazio vira None em vez de erro 500."""
    if valor is None:
        return None
    if isinstance(valor, datetime):
        return valor
    texto = str(valor).strip()
    if not texto:
        return None
    try:
        return datetime.fromisoformat(texto)
    except ValueError:
        raise ValueError("Data de entrega invalida")


class CreateActivityService:
    """Cria uma atividade.

    Regra de negocio: atividade e conteudo pedagogico, entao so o Professor
    cria (a rota usa @professor_required) e so dentro de turma vinculada a
    ele. professor_id vem do token, nunca do corpo da requisicao.
    """

    def execute(self, professor_id, turma_id, titulo, descricao=None,
                data_entrega=None, etapa_id=None, criterio_id=None,
                nota_maxima=None):
        titulo = (titulo or "").strip()
        if not titulo:
            raise ValueError("O titulo da atividade e obrigatorio")
        if not turma_id:
            raise ValueError("A turma e obrigatoria")

        if not ProfessorTurma.professor_leciona_na_turma(professor_id, turma_id):
            raise LookupError("Turma nao encontrada")

        atividade_id = Atividade.create(
            turma_id, professor_id, titulo, descricao,
            parse_data(data_entrega), etapa_id, criterio_id, nota_maxima,
        )
        return Atividade.to_dict(Atividade.find_by_id(atividade_id))

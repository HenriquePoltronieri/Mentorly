from datetime import datetime

from models.atividade_model import Atividade
from models.professor_turma_model import ProfessorTurma
from services.activity.validacao import (
    validar_etapa_e_criterio,
    validar_nota_maxima,
)


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
    ele. professor_id e coordenacao_id vem do token, nunca do corpo.

    Toda atividade nova precisa de etapa, criterio e valor maximo - e o que
    permite calcular a media por etapa com o peso do criterio depois. As
    atividades antigas, criadas antes desta regra, continuam validas; so as
    novas passam por aqui.
    """

    def execute(self, coordenacao_id, professor_id, turma_id, titulo,
                descricao=None, data_entrega=None, etapa_id=None,
                criterio_id=None, nota_maxima=None):
        titulo = (titulo or "").strip()
        if not titulo:
            raise ValueError("O titulo da atividade e obrigatorio")
        if not turma_id:
            raise ValueError("A turma e obrigatoria")

        # Ownership da turma. O vinculo professor_turma so existe dentro de
        # uma escola (FK composta), entao isto ja barra turma de outra
        # coordenacao tambem.
        if not ProfessorTurma.professor_leciona_na_turma(professor_id, turma_id):
            raise LookupError("Turma nao encontrada")

        # Etapa e criterio precisam ser da escola do token. Nunca confiar no
        # id que chegou do cliente.
        etapa_id, criterio_id = validar_etapa_e_criterio(
            coordenacao_id, etapa_id, criterio_id
        )
        nota_maxima = validar_nota_maxima(nota_maxima)

        atividade_id = Atividade.create(
            coordenacao_id, turma_id, professor_id, titulo, descricao,
            parse_data(data_entrega), etapa_id, criterio_id, nota_maxima,
        )
        return Atividade.to_dict(Atividade.find_by_id(atividade_id))

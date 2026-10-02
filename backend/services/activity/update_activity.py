from models.atividade_model import Atividade
from models.etapa_model import Etapa
from models.nota_model import Nota
from models.professor_turma_model import ProfessorTurma
from services.activity.create_activity import parse_data
from services.activity.validacao import (
    validar_etapa_e_criterio,
    validar_nota_maxima,
)


class UpdateActivityService:
    """Edita uma atividade, revalidando tudo do zero.

    Nada do que ja estava gravado e tratado como confiavel: turma, etapa,
    criterio e valor passam pelas mesmas regras da criacao. Confiar no dado
    antigo deixaria a edicao mais fraca que a criacao - bastaria criar a
    atividade correta e depois editar com um id de outra escola.
    """

    def execute(self, atividade_id, coordenacao_id, professor_id, titulo=None,
                descricao=None, turma_id=None, data_entrega=None, etapa_id=None,
                criterio_id=None, nota_maxima=None):
        atual = Atividade.find_by_id(atividade_id)
        if not atual:
            raise LookupError("Atividade nao encontrada")

        # A atividade tem que estar em uma turma do professor logado.
        if not ProfessorTurma.professor_leciona_na_turma(
            professor_id, atual["turma_id"]
        ):
            raise LookupError("Atividade nao encontrada")

        # Atividade de etapa ja fechada fica congelada por inteiro (mesmo
        # so trocando o titulo): senao o resultado que a Coordenacao ja deu
        # como definitivo mudaria sozinho. validar_etapa_e_criterio cobre o
        # caso de mover a atividade PARA uma etapa fechada; isto aqui cobre
        # o caso de ela ja estar em uma.
        if atual.get("etapa_id") and Etapa.esta_fechada(
            atual["etapa_id"], coordenacao_id
        ):
            raise ValueError(
                "Esta atividade pertence a uma etapa fechada. Peca a "
                "coordenacao para reabri-la antes de editar."
            )

        if titulo is not None:
            titulo = titulo.strip()
            if not titulo:
                raise ValueError("O titulo nao pode ficar vazio")

        # Mover a atividade para outra turma so vale se a turma destino
        # tambem for do professor.
        if turma_id is not None and turma_id != atual["turma_id"]:
            if not ProfessorTurma.professor_leciona_na_turma(
                professor_id, turma_id
            ):
                raise LookupError("Turma nao encontrada")

        # Etapa e criterio: so mexe quando vieram na requisicao, mas quando
        # vieram passam pela validacao completa de escola.
        if etapa_id is not None or criterio_id is not None:
            etapa_id, criterio_id = validar_etapa_e_criterio(
                coordenacao_id,
                etapa_id if etapa_id is not None else atual.get("etapa_id"),
                criterio_id if criterio_id is not None
                else atual.get("criterio_id"),
            )

        if nota_maxima is not None:
            nota_maxima = validar_nota_maxima(nota_maxima)

            # Reduzir o teto abaixo de uma nota ja lancada deixaria aluno
            # com nota acima do maximo da propria atividade.
            maior = Nota.maior_nota_da_atividade(atividade_id)
            if maior is not None and float(maior) > nota_maxima:
                raise ValueError(
                    "Ja existe nota %s lancada nesta atividade. Apague ou "
                    "corrija essa nota antes de baixar o valor para %s."
                    % (_limpo(maior), _limpo(nota_maxima))
                )

        Atividade.update(
            atividade_id, titulo, descricao, turma_id,
            parse_data(data_entrega), etapa_id, criterio_id, nota_maxima,
        )
        return Atividade.to_dict(Atividade.find_by_id(atividade_id))


def _limpo(valor):
    """20.0 vira "20"; 13.5 continua "13.5". So para a mensagem de erro."""
    numero = float(valor)
    return str(int(numero)) if numero == int(numero) else str(numero)

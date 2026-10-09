from models.atividade_model import Atividade
from models.etapa_model import Etapa
from models.nota_model import Nota
from models.professor_turma_model import ProfessorTurma
from models.turma_model import Turma
from services import entrada
from services.config.anos_letivos import exigir_ano_nao_encerrado
from services.activity.create_activity import parse_data
from services.activity.validacao import (
    validar_ano_da_etapa,
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

        # Atividade de turma de ano encerrado e historico: nem editar nem mover.
        turma_atual = Turma.find_by_id(atual["turma_id"], coordenacao_id)
        if turma_atual:
            exigir_ano_nao_encerrado(coordenacao_id, turma_atual["ano_letivo"])

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

        if descricao is not None:
            entrada.texto(descricao, "A descricao", entrada.LIMITE_DESCRICAO,
                          aparar=False)
        if titulo is not None:
            titulo = entrada.texto(titulo, "O titulo", entrada.LIMITE_TITULO)
            if not titulo:
                raise ValueError("O titulo nao pode ficar vazio")

        # Uma unica consulta serve a protecao da turma (I-02) e a dos campos
        # academicos (M-03). Nota 0 conta como nota lancada.
        tem_notas = Nota.contar_da_atividade(atividade_id) > 0

        # Mover a atividade para outra turma so vale se a turma destino
        # tambem for do professor.
        if turma_id is not None and turma_id != atual["turma_id"]:
            if not ProfessorTurma.professor_leciona_na_turma(
                professor_id, turma_id
            ):
                raise LookupError("Turma nao encontrada")
            # As notas apontam para alunos da turma de origem: mover a
            # atividade deixaria essas notas presas a uma turma onde os
            # alunos nao estao, e sumiriam das listas e do boletim.
            if tem_notas:
                raise ValueError(
                    "Esta atividade ja tem notas lancadas e nao pode ser "
                    "movida para outra turma. Apague as notas ou crie a "
                    "atividade na outra turma."
                )

        # A etapa da atividade precisa ser do mesmo ano letivo da turma em que
        # ela vai ficar (a nova, se estiver sendo movida).
        turma_final = turma_id if turma_id is not None else atual["turma_id"]
        turma = Turma.find_by_id(turma_final, coordenacao_id)
        if not turma:
            raise LookupError("Turma nao encontrada")
        exigir_ano_nao_encerrado(coordenacao_id, turma["ano_letivo"])

        # Etapa e criterio: so mexe quando vieram na requisicao, mas quando
        # vieram passam pela validacao completa de escola e de ano.
        if etapa_id is not None or criterio_id is not None:
            etapa_id, criterio_id = validar_etapa_e_criterio(
                coordenacao_id,
                etapa_id if etapa_id is not None else atual.get("etapa_id"),
                criterio_id if criterio_id is not None
                else atual.get("criterio_id"),
                ano_turma=turma["ano_letivo"],
            )
        elif turma_final != atual["turma_id"] and atual.get("etapa_id"):
            # Mover a atividade de turma mantendo a etapa: a etapa tem que ser
            # do ano da turma nova.
            etapa_da_atividade = Etapa.find_by_id(atual["etapa_id"], coordenacao_id)
            if etapa_da_atividade:
                validar_ano_da_etapa(etapa_da_atividade, turma["ano_letivo"])

        if nota_maxima is not None:
            nota_maxima = validar_nota_maxima(nota_maxima)

        # Depois de achar e validar tudo dentro da escola (um id de outra
        # escola continua 404, sem revelar se ha notas): com nota lancada,
        # etapa, criterio e valor maximo ficam congelados. Mudar qualquer um
        # muda retroativamente o que a nota significa (8 de 10 vira 8 de 20)
        # sem relancar nada. So conta mudanca REAL: reenviar o mesmo valor e
        # permitido. Titulo, descricao e data seguem editaveis.
        if tem_notas and _muda_dado_academico(
            atual, etapa_id, criterio_id, nota_maxima
        ):
            raise ValueError(MENSAGEM_ATIVIDADE_COM_NOTAS)

        Atividade.update(
            atividade_id, titulo, descricao, turma_id,
            parse_data(data_entrega), etapa_id, criterio_id, nota_maxima,
        )
        return Atividade.to_dict(Atividade.find_by_id(atividade_id))


MENSAGEM_ATIVIDADE_COM_NOTAS = (
    "Esta atividade ja possui notas lancadas e seus dados academicos (etapa, "
    "criterio e valor maximo) nao podem ser alterados."
)


def _mesmo_id(enviado, atual):
    """True quando o campo nao veio ou veio igual ao que ja esta gravado."""
    if enviado is None or str(enviado).strip() == "":
        return True
    try:
        return int(enviado) == atual
    except (TypeError, ValueError, OverflowError):
        return False


def _muda_dado_academico(atual, etapa_id, criterio_id, nota_maxima):
    if not _mesmo_id(etapa_id, atual.get("etapa_id")):
        return True
    if not _mesmo_id(criterio_id, atual.get("criterio_id")):
        return True
    if nota_maxima is not None and str(nota_maxima).strip() != "":
        # Valor invalido segue o erro proprio da validacao (400), nao esta
        # mensagem; o valor gravado tem duas casas (DECIMAL(5,2)).
        novo = validar_nota_maxima(nota_maxima)
        gravado = atual.get("nota_maxima")
        return gravado is None or round(novo, 2) != round(float(gravado), 2)
    return False

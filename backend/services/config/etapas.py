from models.aluno_model import Aluno
from models.ano_letivo_model import AnoLetivo
from models.criterio_model import Criterio
from models.etapa_model import Etapa
from models.turma_model import Turma
from services.academico.calculo import calcular_desempenho_etapa, resumo_pesos
from services.config.anos_letivos import resolver_ano_letivo
from services import entrada
from services.conflito import (
    ConflitoDeIntegridade,
    excluir_ou_conflito,
    gravar_ou_conflito,
)


MENSAGEM_ORDEM_DUPLICADA = "Ja existe uma etapa com esta ordem neste ano letivo."


def _ordem(bruto, obrigatoria):
    """Ordem da etapa: inteiro de 1 a ORDEM_MAXIMA."""
    try:
        ordem = entrada.inteiro(bruto, "A ordem da etapa")
    except entrada.EntradaInvalida:
        raise ValueError(
            "A ordem da etapa e obrigatoria" if obrigatoria
            else "A ordem da etapa precisa ser um numero inteiro"
        )
    if ordem < 1:
        raise ValueError("A ordem da etapa precisa ser 1 ou maior")
    if ordem > entrada.ORDEM_MAXIMA:
        raise ValueError(
            "A ordem da etapa precisa ser no maximo %d" % entrada.ORDEM_MAXIMA
        )
    return ordem


def _exigir_datas_em_ordem(data_inicio, data_fim):
    if data_inicio and data_fim and data_inicio > data_fim:
        raise entrada.EntradaInvalida(
            "A data de inicio nao pode ser depois da data de fim"
        )


MENSAGEM_ETAPA_FECHADA = (
    "A etapa esta fechada e sua configuracao nao pode ser alterada. "
    "Peca a coordenacao para reabri-la."
)


def exigir_etapa_aberta(etapa):
    """Etapa fechada congela a configuracao: o resultado ja dado como definitivo
    nao pode mudar por peso, nota minima/maxima, ordem ou criterio.

    Chamada DEPOIS de achar a etapa dentro da escola (404 para quem nao tem
    acesso), para nao revelar o estado de uma etapa alheia. A reabertura e o
    caminho oficial para voltar a editar.
    """
    if etapa.get("fechada"):
        raise ValueError(MENSAGEM_ETAPA_FECHADA)


class ListarEtapasService:
    """Etapas configuradas pela escola.

    E o que faz a configuracao ser PADRAO DA ESCOLA: o app chama isto ao
    abrir o fluxo e, se ja houver etapas, edita as existentes em vez de
    montar tudo de novo.

    Etapas sao sempre de UM ano letivo. Sem ano informado, devolve as do ano
    atual da escola (lista vazia se a escola ainda nao marcou um): nunca
    mistura etapas de anos diferentes.
    """

    def execute(self, coordenacao_id, ano_letivo=None):
        if ano_letivo is None:
            atual = AnoLetivo.atual(coordenacao_id)
            if atual is None:
                return []
            ano_letivo = atual["ano"]
        linhas = Etapa.find_all_by_coordenacao(coordenacao_id, ano_letivo)
        resultado = []
        for linha in linhas:
            etapa = Etapa.to_dict(linha)
            criterios = Criterio.find_all_by_etapa(linha["id"], coordenacao_id)
            etapa["criterios"] = [Criterio.to_dict(c) for c in criterios]
            # Feedback imediato pra tela de configuracao: sem isso a
            # Coordenacao so descobre que os pesos estao errados quando
            # o Professor tentar ver o desempenho de um aluno.
            soma, valido = resumo_pesos(criterios)
            etapa["pesoTotal"] = soma
            etapa["pesoValido"] = valido
            resultado.append(etapa)
        return resultado


class BuscarEtapaService:
    def execute(self, etapa_id, coordenacao_id):
        linha = Etapa.find_by_id(etapa_id, coordenacao_id)
        if not linha:
            raise LookupError("Etapa nao encontrada")
        etapa = Etapa.to_dict(linha)
        criterios = Criterio.find_all_by_etapa(etapa_id, coordenacao_id)
        etapa["criterios"] = [Criterio.to_dict(c) for c in criterios]
        soma, valido = resumo_pesos(criterios)
        etapa["pesoTotal"] = soma
        etapa["pesoValido"] = valido
        return etapa


class SalvarEtapaService:
    """Cria a etapa, ou atualiza a que ja existe naquela ordem/ano.

    Usa upsert de proposito: passar pelo fluxo de configuracao de novo nao
    pode duplicar as etapas da escola.
    """

    def execute(self, coordenacao_id, nome, ordem, ano_letivo=None,
                data_inicio=None, data_fim=None, ativa=True):
        nome = entrada.texto(nome, "O nome da etapa", entrada.LIMITE_NOME_ETAPA)
        if not nome:
            raise ValueError("O nome da etapa e obrigatorio")

        ordem = _ordem(ordem, obrigatoria=True)
        data_inicio = entrada.data_iso(data_inicio, "A data de inicio")
        data_fim = entrada.data_iso(data_fim, "A data de fim")
        _exigir_datas_em_ordem(data_inicio, data_fim)

        # O ano vem do cadastro da escola: sem ano informado, o ano atual
        # (nunca o do relogio); ano que a escola nao tem vira 404. Reconfigurar
        # uma etapa que ja existe e permitido mesmo em ano encerrado; criar
        # etapa nova nele, nao.
        registro = resolver_ano_letivo(
            coordenacao_id, ano_letivo, permitir_encerrado=True
        )
        ano_letivo = registro["ano"]
        if (registro["status"] == "encerrado"
                and not Etapa.find_by_ordem(coordenacao_id, ano_letivo, ordem)):
            raise ValueError(
                "O ano letivo %d esta encerrado e nao recebe etapas novas"
                % ano_letivo
            )

        existente = Etapa.find_by_ordem(coordenacao_id, ano_letivo, ordem)
        if existente:
            # O upsert reconfigura a etapa que ja existe naquela ordem/ano.
            exigir_etapa_aberta(existente)

        etapa_id = Etapa.upsert(
            coordenacao_id, nome, ordem, ano_letivo, data_inicio, data_fim, ativa
        )
        return Etapa.to_dict(Etapa.find_by_id(etapa_id, coordenacao_id))


class AtualizarEtapaService:
    def execute(self, etapa_id, coordenacao_id, nome=None, ordem=None,
                data_inicio=None, data_fim=None, ativa=None):
        etapa = Etapa.find_by_id(etapa_id, coordenacao_id)
        if not etapa:
            raise LookupError("Etapa nao encontrada")
        exigir_etapa_aberta(etapa)
        if nome is not None:
            nome = entrada.texto(nome, "O nome da etapa", entrada.LIMITE_NOME_ETAPA)
            if not nome:
                raise ValueError("O nome da etapa nao pode ficar vazio")
        if ordem is not None:
            ordem = _ordem(ordem, obrigatoria=False)
            duplicada = Etapa.find_by_ordem(
                coordenacao_id, etapa["ano_letivo"], ordem
            )
            if duplicada and duplicada["id"] != etapa_id:
                raise ConflitoDeIntegridade(MENSAGEM_ORDEM_DUPLICADA)
        data_inicio = entrada.data_iso(data_inicio, "A data de inicio")
        data_fim = entrada.data_iso(data_fim, "A data de fim")
        # Com so uma das datas no pedido, vale a outra que ja esta gravada.
        _exigir_datas_em_ordem(
            data_inicio or etapa.get("data_inicio"),
            data_fim or etapa.get("data_fim"),
        )
        gravar_ou_conflito(
            lambda: Etapa.update(
                etapa_id, coordenacao_id, nome, ordem, data_inicio, data_fim,
                ativa,
            ),
            MENSAGEM_ORDEM_DUPLICADA,
        )
        return Etapa.to_dict(Etapa.find_by_id(etapa_id, coordenacao_id))


class DefinirNotasEtapaService:
    """Grava a nota minima e maxima de uma etapa.

    Fica separado do upsert da etapa para que reconfigurar o ano letivo nao
    apague as notas que ja tinham sido definidas.
    """

    def execute(self, etapa_id, coordenacao_id, nota_minima, nota_maxima):
        etapa = Etapa.find_by_id(etapa_id, coordenacao_id)
        if not etapa:
            raise LookupError("Etapa nao encontrada")
        exigir_etapa_aberta(etapa)

        try:
            nota_minima = entrada.numero_finito(nota_minima, "A nota minima")
            nota_maxima = entrada.numero_finito(nota_maxima, "A nota maxima")
        except entrada.EntradaInvalida:
            raise ValueError("Informe numeros validos para as notas")

        if nota_minima < 0 or nota_maxima < 0:
            raise ValueError("As notas nao podem ser negativas")
        if nota_minima > entrada.MAXIMO_DECIMAL or nota_maxima > entrada.MAXIMO_DECIMAL:
            raise ValueError("As notas nao podem passar de 999,99")
        if nota_minima >= nota_maxima:
            raise ValueError("A nota minima precisa ser menor que a maxima")

        Etapa.definir_notas(etapa_id, coordenacao_id, nota_minima, nota_maxima)
        return Etapa.to_dict(Etapa.find_by_id(etapa_id, coordenacao_id))


class ExcluirEtapaService:
    def execute(self, etapa_id, coordenacao_id):
        etapa = Etapa.find_by_id(etapa_id, coordenacao_id)
        if not etapa:
            raise LookupError("Etapa nao encontrada")
        exigir_etapa_aberta(etapa)
        excluir_ou_conflito(
            lambda: Etapa.delete(etapa_id, coordenacao_id),
            "Esta etapa possui dados vinculados e nao pode ser excluida.",
        )


def _contar_alunos_incompletos(etapa):
    """Quantos alunos da escola ainda tem atividade sem nota nesta etapa.

    Etapa e configuracao da escola para UM ano letivo, entao percorre so as
    turmas desse ano (as de outros anos nem usam esta etapa). Nao inventa
    nenhuma regra nova: usa o mesmo calcular_desempenho_etapa que o boletim e
    o dashboard ja chamam, e so conta quem tem "atividades_sem_nota" > 0. O
    fechamento continua sendo permitido de qualquer forma - isto e so para a
    Coordenacao decidir com informacao, nao para bloquear nada (Marco 4).
    """
    incompletos = 0
    for turma in Turma.find_all_by_coordenacao(
        etapa["coordenacao_id"], etapa["ano_letivo"]
    ):
        for aluno in Aluno.find_all_by_turma(turma["id"]):
            resultado = calcular_desempenho_etapa(aluno["id"], turma["id"], etapa)
            if resultado["atividades_sem_nota"] > 0:
                incompletos += 1
    return incompletos


class FecharEtapaService:
    """Fecha a etapa: o resultado calculado fica congelado ate a reabertura.

    So a Coordenacao chama isto (rota com @coordenacao_required). Depois do
    fechamento, criar/editar atividade e lancar/importar nota nesta etapa
    passam a ser recusados - ver services/activity/validacao.py e
    services/professor/notas.py.

    O fechamento NAO e bloqueado por aluno incompleto (decisao do Marco 4):
    a Coordenacao pode ter motivo legitimo para fechar mesmo assim (aluno
    evadido, por exemplo). O que muda e que a resposta agora informa
    quantos alunos ficam com atividade sem nota nesta etapa, para a
    Coordenacao decidir com informacao em vez de descobrir depois.
    """

    def execute(self, etapa_id, coordenacao_id):
        etapa = Etapa.find_by_id(etapa_id, coordenacao_id)
        if not etapa:
            raise LookupError("Etapa nao encontrada")
        if etapa.get("fechada"):
            raise ValueError("Etapa ja esta fechada")

        alunos_incompletos = _contar_alunos_incompletos(etapa)

        Etapa.fechar(etapa_id, coordenacao_id)
        resultado = Etapa.to_dict(Etapa.find_by_id(etapa_id, coordenacao_id))
        resultado["alunosIncompletos"] = alunos_incompletos
        return resultado


class ReabrirEtapaService:
    """Reabre uma etapa fechada, para a Coordenacao corrigir alguma nota."""

    def execute(self, etapa_id, coordenacao_id):
        etapa = Etapa.find_by_id(etapa_id, coordenacao_id)
        if not etapa:
            raise LookupError("Etapa nao encontrada")
        if not etapa.get("fechada"):
            raise ValueError("Etapa ja esta aberta")
        Etapa.reabrir(etapa_id, coordenacao_id)
        return Etapa.to_dict(Etapa.find_by_id(etapa_id, coordenacao_id))

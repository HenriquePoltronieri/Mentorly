"""Casos de uso do Ano Letivo (Marco 6).

Convencao de erro, a mesma do resto do projeto:
  ValueError          -> 400 (o dado enviado esta errado)
  AnoLetivoConflito   -> 409 (o pedido e valido, mas conflita com o estado)
  LookupError         -> 404 (o id nao existe PARA ESTA ESCOLA)

So a Coordenacao administra anos letivos; o coordenacao_id vem sempre do
token. O Professor nao tem rota aqui: ele apenas consome o contexto
(o ano das turmas dele e o ano atual da escola, no dashboard).
"""

from models.ano_letivo_model import AnoLetivo, STATUS_VALIDOS

ANO_MINIMO = 2000
ANO_MAXIMO = 2100


class AnoLetivoConflito(ValueError):
    """Pedido valido que conflita com o estado atual (vira 409)."""


class AnoEncerrado(ValueError):
    """Escrita em dados de um ano letivo encerrado (vira 400)."""


def exigir_ano_nao_encerrado(coordenacao_id, ano):
    """Ano encerrado e historico somente leitura: recusa qualquer escrita.

    E a regra unica usada por turma, aluno, etapa, criterio, atividade e nota.
    Quem chama ja achou o recurso DENTRO da escola (404 para quem nao tem
    acesso), entao o status do ano de outra escola nunca e revelado. Leitura
    nao passa por aqui.
    """
    registro = AnoLetivo.find_by_ano(coordenacao_id, ano)
    if registro and registro["status"] == "encerrado":
        raise AnoEncerrado(
            "O ano letivo %d esta encerrado e nao permite alteracoes." % ano
        )


def validar_ano(bruto):
    try:
        ano = int(str(bruto).strip())
    except (TypeError, ValueError):
        raise ValueError("Informe o ano letivo como um numero, por exemplo 2026")
    if ano < ANO_MINIMO or ano > ANO_MAXIMO:
        raise ValueError(
            "O ano letivo precisa estar entre %d e %d" % (ANO_MINIMO, ANO_MAXIMO)
        )
    return ano


def _validar_status(bruto):
    status = bruto.strip().lower() if isinstance(bruto, str) else bruto
    if status not in STATUS_VALIDOS:
        raise ValueError(
            "Status invalido. Use: %s" % ", ".join(STATUS_VALIDOS)
        )
    return status


def _como_booleano(bruto):
    if isinstance(bruto, str):
        return bruto.strip().lower() in ("1", "true", "sim")
    return bool(bruto)


def _serializar(coordenacao_id, ano_letivo_id):
    """Devolve o ano ja com os totais de turmas e etapas."""
    for linha in AnoLetivo.find_all_by_coordenacao(coordenacao_id):
        if linha["id"] == ano_letivo_id:
            return AnoLetivo.to_dict(linha)
    raise LookupError("Ano letivo nao encontrado")


def resolver_ano_letivo(coordenacao_id, ano_letivo=None, permitir_encerrado=False):
    """Decide qual ano usar e confere que ele e desta escola.

    Substitui o antigo date.today().year: sem ano informado, vale o ano ATUAL
    cadastrado pela escola, nunca o do relogio. Devolve o registro do ano
    (dict), para quem chama poder olhar o status.

    Anos encerrados nao recebem turma nem etapa nova, a nao ser que o chamador
    peca o contrario (permitir_encerrado), por exemplo ao reaproveitar uma
    etapa que ja existia.
    """
    if ano_letivo is None or str(ano_letivo).strip() == "":
        atual = AnoLetivo.atual(coordenacao_id)
        if not atual:
            raise ValueError(
                "A escola ainda nao tem um ano letivo atual. Cadastre um ano "
                "letivo e marque-o como atual, ou informe o ano."
            )
        return atual

    ano = validar_ano(ano_letivo)
    registro = AnoLetivo.find_by_ano(coordenacao_id, ano)
    # 404 tambem para o ano que so existe em OUTRA escola: nao confirma nada.
    if not registro:
        raise LookupError("Ano letivo nao encontrado")
    if registro["status"] == "encerrado" and not permitir_encerrado:
        raise ValueError(
            "O ano letivo %d esta encerrado e nao recebe turmas nem etapas novas"
            % ano
        )
    return registro


class ListarAnosLetivosService:
    def execute(self, coordenacao_id):
        return [
            AnoLetivo.to_dict(linha)
            for linha in AnoLetivo.find_all_by_coordenacao(coordenacao_id)
        ]


class CriarAnoLetivoService:
    """Cadastra um ano para a escola. Nasce em planejamento, a menos que o
    pedido diga outro status.

    Marcar como atual ao criar segue a mesma regra de AtualizarAnoLetivoService:
    so um ano atual por escola; para trocar, o pedido precisa confirmar com
    encerrar_atual (o ano atual passa a encerrado na mesma transacao).
    """

    def execute(self, coordenacao_id, ano, status=None, encerrar_atual=False):
        ano = validar_ano(ano)
        status = _validar_status(status) if status is not None else "planejamento"

        if AnoLetivo.find_by_ano(coordenacao_id, ano):
            raise AnoLetivoConflito(
                "A escola ja tem o ano letivo %d cadastrado" % ano
            )

        if status != "atual":
            novo_id = AnoLetivo.create(coordenacao_id, ano, status)
            return _serializar(coordenacao_id, novo_id)

        atual = AnoLetivo.atual(coordenacao_id)
        if atual is None:
            novo_id = AnoLetivo.create(coordenacao_id, ano, "atual")
        elif _como_booleano(encerrar_atual):
            novo_id = AnoLetivo.create(coordenacao_id, ano, "planejamento")
            AnoLetivo.trocar_atual(coordenacao_id, atual["id"], novo_id)
        else:
            raise AnoLetivoConflito(
                "O ano letivo %d ja e o atual desta escola. Encerre-o antes "
                "ou confirme a troca." % atual["ano"]
            )
        return _serializar(coordenacao_id, novo_id)


class AtualizarAnoLetivoService:
    """Muda o status de um ano (planejamento, atual ou encerrado).

    O numero do ano nao muda: ele e a chave que turma e etapa usam, e mudar
    em silencio moveria as turmas de ano.
    """

    def execute(self, ano_letivo_id, coordenacao_id, status, encerrar_atual=False):
        status = _validar_status(status)

        registro = AnoLetivo.find_by_id(ano_letivo_id, coordenacao_id)
        if not registro:
            raise LookupError("Ano letivo nao encontrado")

        if registro["status"] == status:
            return _serializar(coordenacao_id, registro["id"])

        if status == "atual":
            atual = AnoLetivo.atual(coordenacao_id)
            if atual is not None and atual["id"] != registro["id"]:
                if not _como_booleano(encerrar_atual):
                    raise AnoLetivoConflito(
                        "O ano letivo %d ja e o atual desta escola. Encerre-o "
                        "antes ou confirme a troca." % atual["ano"]
                    )
                AnoLetivo.trocar_atual(coordenacao_id, atual["id"], registro["id"])
                return _serializar(coordenacao_id, registro["id"])

        AnoLetivo.definir_status(registro["id"], coordenacao_id, status)
        return _serializar(coordenacao_id, registro["id"])


class ExcluirAnoLetivoService:
    """So exclui ano sem nenhuma turma nem etapa: serve para desfazer um
    cadastro errado, nao para apagar historico."""

    def execute(self, ano_letivo_id, coordenacao_id):
        registro = AnoLetivo.find_by_id(ano_letivo_id, coordenacao_id)
        if not registro:
            raise LookupError("Ano letivo nao encontrado")

        turmas, etapas = AnoLetivo.contar_dados(coordenacao_id, registro["ano"])
        if turmas or etapas:
            raise AnoLetivoConflito(
                "O ano letivo %d tem %d turma(s) e %d etapa(s) e nao pode ser "
                "excluido. Encerre-o para mante-lo como historico."
                % (registro["ano"], turmas, etapas)
            )
        AnoLetivo.delete(registro["id"], coordenacao_id)

"""Valida a configuração inteira antes de iniciar qualquer gravação."""
from decimal import Decimal
from datetime import date
import unicodedata

from models.configuracao_ano_model import ConfiguracaoAno
from services import entrada
from services.conflito import excluir_ou_conflito
from services.config.etapas import ListarEtapasService


def _decimal(valor, rotulo, maximo):
    numero = entrada.numero_na_faixa(valor, rotulo, 0, maximo)
    decimal = Decimal(str(numero))
    if decimal != decimal.quantize(Decimal("0.01")):
        raise ValueError("%s: use no máximo duas casas decimais." % rotulo)
    return decimal


def _data(valor, rotulo):
    if valor in (None, ""):
        return None
    try:
        return date.fromisoformat(str(valor)[:10])
    except (TypeError, ValueError):
        raise ValueError("%s: informe uma data válida." % rotulo)


def validar_configuracao(etapas, criterios):
    if not isinstance(etapas, list) or not 1 <= len(etapas) <= 12:
        raise ValueError("Escolha de 1 a 12 etapas.")
    if not isinstance(criterios, list) or not 1 <= len(criterios) <= 30:
        raise ValueError("Escolha de 1 a 30 critérios.")
    etapas_validas = []
    for indice, etapa in enumerate(etapas, 1):
        if not isinstance(etapa, dict):
            raise ValueError("Informe os dados de cada etapa.")
        minima = _decimal(etapa.get("nota_minima"), "Mínimo para aprovação", 999.99)
        maxima = _decimal(etapa.get("nota_maxima"), "Pontos da etapa", 999.99)
        if minima >= maxima:
            raise ValueError("Etapa %d: o mínimo para aprovação deve ser menor que os pontos da etapa." % indice)
        nome = entrada.texto(etapa.get("nome", "Etapa %d" % indice), "Nome da etapa", entrada.LIMITE_NOME_ETAPA)
        if not nome:
            raise ValueError("Preencha o nome de cada etapa.")
        inicio = _data(etapa.get("data_inicio"), "Início da etapa %d" % indice)
        fim = _data(etapa.get("data_fim"), "Fim da etapa %d" % indice)
        if (inicio is None) != (fim is None):
            raise ValueError("Etapa %d: informe as duas datas ou deixe ambas vazias." % indice)
        if inicio and fim and fim < inicio:
            raise ValueError("Etapa %d: a data final deve ser igual ou posterior à inicial." % indice)
        etapas_validas.append({"nome": nome, "nota_minima": minima,
                               "nota_maxima": maxima, "data_inicio": inicio,
                               "data_fim": fim})
    datadas = [e for e in etapas_validas if e["data_inicio"]]
    for anterior, atual in zip(datadas, datadas[1:]):
        if atual["data_inicio"] <= anterior["data_fim"]:
            raise ValueError("As datas das etapas não podem se sobrepor.")
    nomes = set()
    criterios_validos = []
    for criterio in criterios:
        if not isinstance(criterio, dict):
            raise ValueError("Informe o nome e o peso de cada critério.")
        nome = entrada.texto(criterio.get("nome"), "Nome do critério", entrada.LIMITE_NOME_CRITERIO)
        chave = "".join(c for c in unicodedata.normalize("NFD", nome.casefold()) if not unicodedata.combining(c))
        if not nome or chave in nomes:
            raise ValueError("Os critérios precisam ter nomes diferentes e preenchidos.")
        nomes.add(chave)
        maximos_brutos = criterio.get("notas_maximas")
        if maximos_brutos is None:
            # Compatibilidade com clientes antigos: a parcela de pontos segue
            # o peso do criterio em cada etapa.
            peso = _decimal(criterio.get("peso"), "Peso", 100)
            maximos = [
                (etapa["nota_maxima"] * peso / Decimal("100")).quantize(Decimal("0.01"))
                for etapa in etapas_validas
            ]
        else:
            if not isinstance(maximos_brutos, list) or len(maximos_brutos) != len(etapas_validas):
                raise ValueError("Informe o máximo do critério em cada etapa.")
            peso = _decimal(criterio.get("peso"), "Peso", 100)
            maximos = [
                _decimal(valor, "Máximo do critério na etapa %d" % (indice + 1), 999.99)
                for indice, valor in enumerate(maximos_brutos)
            ]
            if any(valor <= 0 for valor in maximos):
                raise ValueError("O máximo de cada critério precisa ser maior que zero.")
        criterios_validos.append({"nome": nome, "peso": peso, "notas_maximas": maximos})
    if sum(c["peso"] for c in criterios_validos) != Decimal("100"):
        raise ValueError("A soma dos pesos precisa ser exatamente 100%.")
    for indice, etapa in enumerate(etapas_validas):
        total = sum(c["notas_maximas"][indice] for c in criterios_validos)
        if total != etapa["nota_maxima"]:
            raise ValueError(
                "Etapa %d: a soma dos máximos dos critérios precisa ser %s pontos (está em %s)."
                % (indice + 1, etapa["nota_maxima"], total)
            )
    return etapas_validas, criterios_validos


class SalvarConfiguracaoAnoService:
    def execute(self, coordenacao_id, ano, etapas, criterios):
        etapas, criterios = validar_configuracao(etapas, criterios)
        excluir_ou_conflito(
            lambda: ConfiguracaoAno.salvar(coordenacao_id, ano, etapas, criterios),
            "Uma etapa ou critério que você tentou remover possui atividades vinculadas. Mantenha-o na configuração.",
        )
        return ListarEtapasService().execute(coordenacao_id, ano)

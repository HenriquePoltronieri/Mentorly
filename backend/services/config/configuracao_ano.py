"""Valida a configuração inteira antes de iniciar qualquer gravação."""
from decimal import Decimal
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
        etapas_validas.append({"nome": nome, "nota_minima": minima, "nota_maxima": maxima})
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
        criterios_validos.append({"nome": nome, "peso": _decimal(criterio.get("peso"), "Peso", 100)})
    if sum(c["peso"] for c in criterios_validos) != Decimal("100"):
        raise ValueError("A soma dos pesos precisa ser exatamente 100%.")
    return etapas_validas, criterios_validos


class SalvarConfiguracaoAnoService:
    def execute(self, coordenacao_id, ano, etapas, criterios):
        etapas, criterios = validar_configuracao(etapas, criterios)
        excluir_ou_conflito(
            lambda: ConfiguracaoAno.salvar(coordenacao_id, ano, etapas, criterios),
            "Uma etapa ou critério que você tentou remover possui atividades vinculadas. Mantenha-o na configuração.",
        )
        return ListarEtapasService().execute(coordenacao_id, ano)

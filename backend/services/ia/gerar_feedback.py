"""Caso de uso: feedback e plano de recuperacao de um aluno em uma etapa (Marco 9D).

Somente LEITURA. Este service nao grava nada, nao altera nota, situacao,
criterio ou etapa e nao conhece o nome do aluno: ele pede ao motor academico
(services/academico/calculo.py) o resultado oficial da etapa, monta um payload
sem identificador pessoal e pede ao AIClient uma SUGESTAO pedagogica. Quem
calcula e o Mentorly; a IA so interpreta; o Professor revisa.

Etapa fechada: a geracao e permitida. Diferente de lancar nota, aqui nada e
escrito, e olhar o desempenho de uma etapa encerrada e justamente um uso comum.
"""

from decimal import Decimal

from models.etapa_model import Etapa
from services.academico.calculo import calcular_desempenho_etapa
from services.aluno.acesso_turma import aluno_acessivel
from services.ia.client import AIClient
from services.ia.contrato_feedback import (
    PLANOS,
    caso_gerar_feedback,
    numeros_do_payload,
)
from services.ia.gerar_insights_turma import DadosInsuficientesError
from erros import RecursoNaoEncontrado


def _limpar(valor, limite=100):
    """Nome de etapa/criterio vai para o prompt: sem delimitadores nem quebras."""
    return " ".join(str(valor or "").replace("<", " ").replace(">", " ").split())[:limite]


def _json(valor):
    """Payload so com tipos JSON: o MySQL devolve DECIMAL como Decimal, que o json recusa."""
    if isinstance(valor, Decimal):
        return float(valor)
    if isinstance(valor, dict):
        return {chave: _json(item) for chave, item in valor.items()}
    if isinstance(valor, list):
        return [_json(item) for item in valor]
    return valor


def _etapa_id(dados):
    bruto = dados.get("etapaId") if isinstance(dados, dict) else None
    if bruto is None or bruto == "" or isinstance(bruto, bool):
        raise ValueError("Escolha a etapa para gerar o feedback")
    try:
        return int(bruto)
    except (TypeError, ValueError):
        raise ValueError("Etapa invalida")


class GerarFeedbackIaService:
    def __init__(self, client=None):
        self.client = client or AIClient()

    def execute(self, aluno_id, professor_id, coordenacao_id, dados):
        # 1. Quem pede: aluno de uma turma vinculada ao Professor, da escola do
        #    token. 404 para qualquer outra combinacao (outra turma, outra
        #    escola, aluno inexistente), sem confirmar que o aluno existe.
        aluno = aluno_acessivel(aluno_id, coordenacao_id, professor_id)

        # 2. Etapa explicita (nunca "a etapa atual" implicita), da escola e do
        #    mesmo ano letivo da turma do aluno.
        etapa_id = _etapa_id(dados)
        etapa = Etapa.find_by_id(etapa_id, coordenacao_id)
        if not etapa:
            raise RecursoNaoEncontrado("Etapa nao encontrada")
        if etapa["ano_letivo"] != aluno["ano_letivo"]:
            raise ValueError(
                "A etapa e do ano letivo %d, mas a turma do aluno e do ano "
                "letivo %d. Escolha uma etapa do mesmo ano."
                % (etapa["ano_letivo"], aluno["ano_letivo"])
            )

        # 3. Resultado oficial, calculado pelo motor. A IA nao recalcula nada.
        resultado = calcular_desempenho_etapa(aluno_id, aluno["turma_id"], etapa)

        # 4. Base minima: sem configuracao valida ou sem nenhuma atividade
        #    avaliada nao ha o que interpretar, e a Groq nao e chamada.
        if resultado["situacao"] == "configuracao_invalida":
            raise DadosInsuficientesError(
                resultado.get("mensagem")
                or "A etapa ainda nao tem configuracao suficiente para gerar o feedback."
            )
        if resultado["atividades_avaliadas"] == 0:
            raise DadosInsuficientesError(
                "O aluno ainda nao tem atividade avaliada nesta etapa."
            )

        situacao = resultado["situacao"]
        payload = _json({
            "tipoDePlano": PLANOS[situacao],
            "etapa": {
                "nome": _limpar(resultado["etapa"]),
                "notaMinima": resultado["nota_minima"],
                "notaMaxima": resultado["nota_maxima"],
            },
            "resultado": {
                "nota": resultado["nota_calculada"],
                "percentual": resultado["percentual"],
                "situacao": situacao,
                "completo": resultado["completo"],
            },
            "criterios": [
                {
                    "nome": _limpar(c["criterio"]),
                    "peso": c.get("peso"),
                    "desempenhoPercentual": c.get("desempenho_percentual"),
                    "completo": c.get("completo", False),
                    "atividadesAvaliadas": c.get("atividades_avaliadas", 0),
                    "atividadesSemNotaLancada": max(
                        c.get("total_atividades", 0) - c.get("atividades_avaliadas", 0), 0
                    ),
                    "totalAtividades": c.get("total_atividades", 0),
                }
                for c in resultado["criterios"]
            ],
            "atividades": {
                "avaliadas": resultado["atividades_avaliadas"],
                "semNotaLancada": resultado["atividades_sem_nota"],
                "total": resultado["total_atividades"],
            },
        })

        sugestao = self.client.gerar(
            payload, caso_gerar_feedback(situacao, numeros_do_payload(payload))
        )
        return {
            "contexto": {
                "etapa": resultado["etapa"],
                "etapaId": resultado["etapa_id"],
                "anoLetivo": aluno["ano_letivo"],
                "fechada": resultado["fechada"],
                "tipoPlano": PLANOS[situacao],
                # Resultado OFICIAL, do motor: a tela o mostra ao lado da sugestao.
                "resultadoOficial": payload["resultado"],
                "atividades": payload["atividades"],
            },
            "geradoPorIA": True,
            "modelo": self.client.model,
            "sugestao": sugestao,
        }

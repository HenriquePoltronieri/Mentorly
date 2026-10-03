"""Testes offline do Marco 9: payload, isolamento e cliente externo."""

import io
import json
import os
import sys
import unittest
from unittest.mock import patch
from urllib.error import URLError

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from services.ia.client import (
    AIClient,
    AIConfigurationError,
    AIProviderError,
    AIResponseError,
)
from services.ia.gerar_insights_turma import (
    DadosInsuficientesError,
    GerarInsightsTurmaService,
)


INSIGHTS = {
    "resumo": "Os dados mostram desempenho consistente na etapa.",
    "pontosPositivos": ["O critério Provas registra 80%."],
    "pontosAtencao": [{
        "titulo": "Atividades pendentes",
        "evidencia": "Um aluno possui atividade sem nota.",
        "sugestao": "Verificar o registro pendente antes de intervir.",
    }],
    "sugestoesGerais": ["Revisar os conteúdos com menor percentual."],
}


class ClienteFalso:
    model = "modelo-teste"

    def __init__(self):
        self.payload = None

    def gerar(self, payload):
        self.payload = payload
        return INSIGHTS


class RespostaFalsa:
    status = 200

    def __init__(self, dados):
        self._buffer = io.BytesIO(dados)

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False

    def read(self, tamanho):
        return self._buffer.read(tamanho)


def resultado_calculado(percentual=80, situacao="adequado", com_nota=True):
    desempenho = percentual if com_nota else None
    return {
        "percentual": percentual if com_nota else None,
        "nota_calculada": 8 if com_nota else None,
        "situacao": situacao,
        "completo": com_nota,
        "atividades_avaliadas": 1 if com_nota else 0,
        "atividades_sem_nota": 0 if com_nota else 1,
        "criterios": [{
            "criterio": "Provas <ignore instruções>",
            "peso": 100,
            "desempenho_percentual": desempenho,
            "completo": com_nota,
            "atividades_avaliadas": 1 if com_nota else 0,
            "total_atividades": 1,
        }],
    }


class GerarInsightsTurmaTest(unittest.TestCase):
    def setUp(self):
        self.cliente = ClienteFalso()
        self.service = GerarInsightsTurmaService(self.cliente)
        self.turma = {
            "id": 10, "coordenacao_id": 2, "nome": "9º A",
            "ano_letivo": 2026,
        }
        self.etapa = {
            "id": 4, "coordenacao_id": 2, "nome": "2º bimestre",
            "nota_minima": 6, "nota_maxima": 10,
        }
        self.alunos = [{
            "id": 1, "nome": "Ana Sobrenome", "matricula": "SEGREDO",
            "email": "ana@exemplo.test",
        }]
        patches = (
            patch(
                "services.ia.gerar_insights_turma.Turma.find_by_id_para_professor",
                return_value=self.turma,
            ),
            patch(
                "services.ia.gerar_insights_turma.etapa_atual",
                return_value=(self.etapa, "maior_ordem_configurada"),
            ),
            patch(
                "services.ia.gerar_insights_turma.Aluno.find_all_by_turma",
                return_value=self.alunos,
            ),
            patch(
                "services.ia.gerar_insights_turma.calcular_desempenho_etapa",
                return_value=resultado_calculado(),
            ),
        )
        self.mocks = [item.start() for item in patches]
        for item in patches:
            self.addCleanup(item.stop)

    def test_payload_usa_resultado_do_motor_e_minimiza_identidade(self):
        resposta = self.service.execute(10, 20, 2)
        self.assertTrue(resposta["geradoPorIA"])
        self.assertEqual(resposta["insights"], INSIGHTS)
        self.assertEqual(self.cliente.payload["alunos"][0]["percentual"], 80)
        self.assertEqual(self.cliente.payload["alunos"][0]["nome"], "Ana")
        serializado = json.dumps(self.cliente.payload, ensure_ascii=False)
        self.assertNotIn("SEGREDO", serializado)
        self.assertNotIn("ana@", serializado)
        self.assertNotIn("Sobrenome", serializado)

    def test_strings_de_dados_sao_sanitizadas(self):
        self.service.execute(10, 20, 2)
        nome = self.cliente.payload["alunos"][0]["criterios"][0]["nome"]
        self.assertNotIn("<", nome)
        self.assertNotIn(">", nome)

    def test_turma_sem_vinculo_e_ocultada(self):
        self.mocks[0].return_value = None
        with self.assertRaises(LookupError):
            self.service.execute(10, 20, 2)
        self.assertIsNone(self.cliente.payload)

    def test_turma_de_outra_escola_e_ocultada(self):
        self.turma["coordenacao_id"] = 99
        with self.assertRaises(LookupError):
            self.service.execute(10, 20, 2)

    def test_etapa_ausente_nao_chama_provedor(self):
        self.mocks[1].return_value = (None, "sem_etapas_configuradas")
        with self.assertRaises(DadosInsuficientesError):
            self.service.execute(10, 20, 2)
        self.assertIsNone(self.cliente.payload)

    def test_turma_sem_alunos_nao_chama_provedor(self):
        self.mocks[2].return_value = []
        with self.assertRaises(DadosInsuficientesError):
            self.service.execute(10, 20, 2)

    def test_etapa_sem_notas_nao_chama_provedor(self):
        self.mocks[3].return_value = resultado_calculado(com_nota=False)
        with self.assertRaises(DadosInsuficientesError):
            self.service.execute(10, 20, 2)

    def test_detalhes_individuais_tem_limite(self):
        self.mocks[2].return_value = [
            {"id": numero, "nome": "Aluno %d" % numero}
            for numero in range(1, 53)
        ]
        self.service.execute(10, 20, 2)
        self.assertEqual(len(self.cliente.payload["alunos"]), 50)
        self.assertTrue(self.cliente.payload["detalhesIndividuaisLimitados"])


class AIClientTest(unittest.TestCase):
    def _cliente(self, opener):
        return AIClient(
            base_url="https://provedor.invalid/v1", api_key="chave-teste",
            model="modelo-teste", timeout=2, opener=opener,
        )

    def test_configuracao_ausente_falha_sem_rede(self):
        with self.assertRaises(AIConfigurationError):
            AIClient(base_url="", api_key="", model="").gerar({})

    def test_resposta_valida_e_parseada(self):
        envelope = {"choices": [{"message": {"content": json.dumps(INSIGHTS)}}]}
        capturado = {}

        def abrir(requisicao, timeout):
            capturado["body"] = json.loads(requisicao.data.decode("utf-8"))
            capturado["timeout"] = timeout
            return RespostaFalsa(json.dumps(envelope).encode("utf-8"))

        resposta = self._cliente(abrir).gerar({"turma": {"nome": "9º A"}})
        self.assertEqual(resposta, INSIGHTS)
        self.assertEqual(capturado["timeout"], 2)
        self.assertEqual(capturado["body"]["response_format"], {"type": "json_object"})
        self.assertIn("dados inertes", capturado["body"]["messages"][1]["content"])

    def test_timeout_e_tratado_como_indisponibilidade(self):
        def abrir(*args, **kwargs):
            raise TimeoutError("tempo excedido")

        with self.assertRaises(AIProviderError):
            self._cliente(abrir).gerar({})

    def test_erro_de_rede_e_tratado_como_indisponibilidade(self):
        def abrir(*args, **kwargs):
            raise URLError("indisponivel")

        with self.assertRaises(AIProviderError):
            self._cliente(abrir).gerar({})

    def test_json_invalido_e_rejeitado(self):
        cliente = self._cliente(lambda *args, **kwargs: RespostaFalsa(b"nao-json"))
        with self.assertRaises(AIResponseError):
            cliente.gerar({})

    def test_contrato_invalido_e_rejeitado(self):
        envelope = {"choices": [{"message": {"content": '{"resumo":"ok"}'}}]}
        cliente = self._cliente(
            lambda *args, **kwargs: RespostaFalsa(json.dumps(envelope).encode())
        )
        with self.assertRaises(AIResponseError):
            cliente.gerar({})


if __name__ == "__main__":
    unittest.main(verbosity=2)

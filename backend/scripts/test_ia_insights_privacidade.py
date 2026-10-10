"""Privacidade do 9A (M-09), sem banco e sem rede: python scripts/test_ia_insights_privacidade.py

O provedor externo nao pode receber nome, primeiro nome, sobrenome, matricula,
e-mail nem id de aluno. Os testes capturam o payload entregue ao AIClient e,
tambem, os BYTES que o AIClient real mandaria pela rede, e procuram os VALORES
reais do cenario (nao so as chaves).
"""

import io
import json
import os
import re
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from services.ia.client import MENSAGEM_INDISPONIVEL, AIClient, AIResponseError
from services.ia.gerar_insights_turma import (
    MAX_DETALHES_ALUNOS,
    GerarInsightsTurmaService,
)

# Valores reais do cenario, todos distintivos para a busca por valor.
ALUNOS = [
    {"id": 98123, "nome": "Ana Zelindovsky Prado", "matricula": "MAT-77-AZP",
     "email": "ana.zelindovsky@escola-teste.example"},
    {"id": 98124, "nome": "Bruno Quintanilha Reis", "matricula": "MAT-78-BQR",
     "email": "bruno.quintanilha@escola-teste.example"},
    {"id": 98125, "nome": "Carla Vasconcelos Dias", "matricula": "MAT-79-CVD",
     "email": "carla.vasconcelos@escola-teste.example"},
    {"id": 98126, "nome": "Davi Wanderley Souza", "matricula": "MAT-80-DWS",
     "email": "davi.wanderley@escola-teste.example"},
]

# aluno id -> (percentual, nota, situacao, completo)
RESULTADOS = {
    98123: (90, 9.0, "adequado", True),
    98124: (40, 4.0, "abaixo_do_minimo", True),
    98125: (None, None, "em_andamento", False),
    98126: (65, 6.5, "adequado", True),
}


def calculo(aluno_id, turma_id, etapa):
    percentual, nota, situacao, completo = RESULTADOS[aluno_id]
    avaliada = percentual is not None
    return {
        "percentual": percentual, "nota_calculada": nota, "situacao": situacao,
        "completo": completo,
        "atividades_avaliadas": 1 if avaliada else 0,
        "atividades_sem_nota": 0 if avaliada else 1,
        "criterios": [{
            "criterio": "Provas", "peso": 100,
            "desempenho_percentual": percentual, "completo": completo,
            "atividades_avaliadas": 1 if avaliada else 0, "total_atividades": 1,
        }],
    }


def insights(**campos):
    base = {
        "resumo": "Resumo geral da turma.",
        "pontosPositivos": ["Bom desempenho em Provas."],
        "pontosAtencao": [],
        "sugestoesGerais": ["Revisar os conteudos."],
    }
    base.update(campos)
    return base


class ClienteCapturador:
    """Duble do AIClient para o service: guarda o payload e devolve uma resposta."""
    model = "modelo-teste"

    def __init__(self, resposta=None):
        self.payload = None
        self.chamadas = 0
        self.resposta = resposta or insights()

    def gerar(self, payload):
        self.payload = payload
        self.chamadas += 1
        return self.resposta


class RespostaHttp:
    status = 200

    def __init__(self, dados):
        self._buffer = io.BytesIO(dados)

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False

    def read(self, tamanho):
        return self._buffer.read(tamanho)


def cenario(alunos, cliente, nomes_resultado=None):
    """Service com tudo que toca banco substituido."""
    service = GerarInsightsTurmaService(cliente)
    turma = {"id": 10, "coordenacao_id": 2, "nome": "9 Ano A", "ano_letivo": 2026}
    etapa = {"id": 4, "coordenacao_id": 2, "nome": "2 bimestre",
             "nota_minima": 6, "nota_maxima": 10}
    patches = (
        patch("services.ia.gerar_insights_turma.Turma.find_by_id_para_professor",
              return_value=turma),
        patch("services.ia.gerar_insights_turma.etapa_atual",
              return_value=(etapa, "maior_ordem_configurada")),
        patch("services.ia.gerar_insights_turma.Aluno.find_all_by_turma",
              return_value=alunos),
        patch("services.ia.gerar_insights_turma.calcular_desempenho_etapa",
              side_effect=nomes_resultado or calculo),
    )
    return service, patches


class _Base(unittest.TestCase):
    def rodar(self, alunos=ALUNOS, resposta=None, calculador=None):
        cliente = ClienteCapturador(resposta)
        service, patches = cenario(alunos, cliente, calculador)
        for p in patches:
            p.start()
            self.addCleanup(p.stop)
        saida = service.execute(10, 20, 2)
        return cliente, saida


class PayloadSemIdentificacaoTest(_Base):
    def test_o_payload_usa_referencias_neutras_e_nao_tem_chave_de_nome(self):
        cliente, _ = self.rodar()
        alunos = cliente.payload["alunos"]
        self.assertEqual([a["referencia"] for a in alunos],
                         ["Aluno 1", "Aluno 2", "Aluno 3", "Aluno 4"])
        for aluno in alunos:
            self.assertEqual(
                set(aluno),
                {"referencia", "percentual", "notaCalculada", "situacao", "completo",
                 "atividadesAvaliadas", "atividadesSemNota", "criterios"},
            )

    def test_nenhum_valor_identificavel_aparece_no_payload(self):
        cliente, _ = self.rodar()
        serializado = json.dumps(cliente.payload, ensure_ascii=False)
        proibidos = []
        for aluno in ALUNOS:
            proibidos += aluno["nome"].split()          # primeiro nome e sobrenomes
            proibidos += [aluno["nome"], aluno["matricula"], aluno["email"],
                          str(aluno["id"])]
        for valor in proibidos:
            self.assertNotIn(valor, serializado, valor)
        self.assertNotIn("@", serializado)
        self.assertNotIn("MAT-", serializado)
        self.assertIsNone(re.search(r"\b9812\d\b", serializado))
        for chave in ('"id"', '"nome":"Ana', '"matricula"', '"email"'):
            self.assertNotIn(chave, serializado.replace(" ", ""))

    def test_nenhum_valor_identificavel_sai_pela_rede(self):
        """Mesma checagem nos bytes que o AIClient real enviaria ao provedor."""
        enviados = []
        envelope = {"choices": [{"message": {"content": json.dumps(insights())}}]}

        def abrir(requisicao, timeout):
            enviados.append(requisicao.data)
            return RespostaHttp(json.dumps(envelope).encode("utf-8"))

        cliente_real = AIClient(base_url="https://provedor.invalid/v1", api_key="chave-teste",
                                model="modelo-teste", timeout=2, opener=abrir)
        service, patches = cenario(ALUNOS, cliente_real)
        for p in patches:
            p.start()
            self.addCleanup(p.stop)
        service.execute(10, 20, 2)

        self.assertEqual(len(enviados), 1)
        corpo = enviados[0].decode("utf-8")
        for aluno in ALUNOS:
            for parte in aluno["nome"].split():
                # palavra inteira: o prompt fixo tem "Analise", que contem "Ana"
                self.assertIsNone(re.search(r"\b%s\b" % re.escape(parte), corpo), parte)
            for valor in (aluno["matricula"], aluno["email"], str(aluno["id"])):
                self.assertNotIn(valor, corpo, valor)
        self.assertIn("Aluno 1", corpo)

    def test_dados_academicos_e_priorizacao_permanecem(self):
        cliente, _ = self.rodar()
        alunos = cliente.payload["alunos"]
        # abaixo do minimo, depois em andamento, depois adequados (menor % primeiro)
        self.assertEqual([a["situacao"] for a in alunos],
                         ["abaixo_do_minimo", "em_andamento", "adequado", "adequado"])
        self.assertEqual([a["percentual"] for a in alunos], [40, None, 65, 90])
        self.assertEqual([a["notaCalculada"] for a in alunos], [4.0, None, 6.5, 9.0])
        self.assertEqual(alunos[1]["atividadesSemNota"], 1)
        self.assertFalse(alunos[1]["completo"])
        self.assertEqual(alunos[0]["criterios"][0]["desempenhoPercentual"], 40)
        resumo = cliente.payload["resumoNumerico"]
        self.assertEqual((resumo["totalAlunos"], resumo["abaixoDoMinimo"],
                          resumo["adequados"], resumo["emAndamento"]), (4, 1, 2, 1))
        # o limite de detalhes nao vira sinal de nome
        self.assertFalse(cliente.payload["detalhesIndividuaisLimitados"])

    def test_limite_de_50_alunos_continua(self):
        muitos = [{"id": 5000 + n, "nome": "Pessoa%02d Sobrenome%02d" % (n, n),
                   "matricula": "M%d" % n, "email": "p%d@x.test" % n}
                  for n in range(1, 53)]
        resultados = {a["id"]: (50 + (a["id"] % 40), 5.0, "adequado", True) for a in muitos}
        cliente, _ = self.rodar(
            alunos=muitos,
            calculador=lambda aid, t, e: calculo_de(resultados, aid))
        self.assertEqual(len(cliente.payload["alunos"]), MAX_DETALHES_ALUNOS)
        self.assertTrue(cliente.payload["detalhesIndividuaisLimitados"])
        self.assertEqual(cliente.payload["alunos"][-1]["referencia"], "Aluno 50")
        self.assertEqual(cliente.payload["resumoNumerico"]["totalAlunos"], 52)
        self.assertNotIn("Sobrenome", json.dumps(cliente.payload))


def calculo_de(resultados, aluno_id):
    original = RESULTADOS.copy()
    RESULTADOS.update(resultados)
    try:
        return calculo(aluno_id, 0, None)
    finally:
        RESULTADOS.clear()
        RESULTADOS.update(original)


class RemapeamentoTest(_Base):
    def test_referencia_volta_como_o_nome_do_aluno(self):
        resposta = insights(
            resumo="O Aluno 1 ficou abaixo do minimo.",
            pontosAtencao=[{
                "titulo": "Aluno 1 precisa de apoio",
                "evidencia": "Aluno 1 tem 40% em Provas; aluno 2 tem atividade sem nota lancada.",
                "sugestao": "Conversar com o Aluno 1 e conferir o registro do Aluno 2.",
            }],
        )
        _, saida = self.rodar(resposta=resposta)
        texto = saida["insights"]
        self.assertEqual(texto["resumo"], "O Bruno ficou abaixo do minimo.")
        ponto = texto["pontosAtencao"][0]
        self.assertEqual(ponto["titulo"], "Bruno precisa de apoio")
        self.assertEqual(
            ponto["evidencia"],
            "Bruno tem 40% em Provas; Carla tem atividade sem nota lancada.")
        self.assertEqual(
            ponto["sugestao"], "Conversar com o Bruno e conferir o registro do Carla.")
        for campo in ("resumo",):
            self.assertNotRegex(texto[campo], r"(?i)\baluno\s+\d")
        self.assertNotRegex(json.dumps(texto), r"(?i)\bAluno\s+\d")

    def test_aluno_10_nao_vira_aluno_1_mais_zero(self):
        doze = [{"id": 7000 + n, "nome": "Nome%02d Sobre" % n, "matricula": "M", "email": "e@x.t"}
                for n in range(1, 13)]
        # todos adequados com percentuais crescentes: a referencia segue a ordem
        resultados = {7000 + n: (40 + n, 5.0, "adequado", True) for n in range(1, 13)}
        resposta = insights(resumo="Aluno 10 e Aluno 1 foram citados; Aluno 12 tambem.")
        _, saida = self.rodar(alunos=doze, resposta=resposta,
                              calculador=lambda aid, t, e: calculo_de(resultados, aid))
        # Aluno 1 = menor percentual = Nome01; Aluno 10 = Nome10; Aluno 12 = Nome12
        self.assertEqual(saida["insights"]["resumo"],
                         "Nome10 e Nome01 foram citados; Nome12 tambem.")

    def test_substituicao_exata_nao_mexe_em_outras_palavras(self):
        resposta = insights(resumo="Maluno 1 e Aluno 1a nao sao referencias. Aluno 1, sim.")
        _, saida = self.rodar(resposta=resposta)
        # "Maluno 1" nao casa (\b); "Aluno 1a" nao casa (\b depois do numero); o ultimo casa
        self.assertEqual(saida["insights"]["resumo"],
                         "Maluno 1 e Aluno 1a nao sao referencias. Bruno, sim.")

    def test_resposta_sem_mencao_individual_nao_quebra(self):
        _, saida = self.rodar(resposta=insights(resumo="Visao geral, sem citar ninguem."))
        self.assertEqual(saida["insights"], insights(resumo="Visao geral, sem citar ninguem."))

    def test_alunos_com_o_mesmo_primeiro_nome_ganham_inicial(self):
        iguais = [
            {"id": 1, "nome": "Ana Souza Lima", "matricula": "1", "email": "a@x.t"},
            {"id": 2, "nome": "Ana Pereira Alves", "matricula": "2", "email": "b@x.t"},
        ]
        resultados = {1: (30, 3.0, "abaixo_do_minimo", True), 2: (35, 3.5, "abaixo_do_minimo", True)}
        resposta = insights(resumo="Aluno 1 e Aluno 2 estao abaixo.")
        cliente, saida = self.rodar(alunos=iguais, resposta=resposta,
                                    calculador=lambda aid, t, e: calculo_de(resultados, aid))
        self.assertEqual(saida["insights"]["resumo"], "Ana L. e Ana A. estao abaixo.")
        self.assertNotIn("Ana", json.dumps(cliente.payload))

    def test_referencia_inexistente_ou_plural_invalida_a_resposta(self):
        for texto in ("O Aluno 99 foi bem.", "Alunos 1 e 2 estao abaixo.", "aluno 0 sumiu."):
            with self.subTest(texto):
                cliente = ClienteCapturador(insights(resumo=texto))
                service, patches = cenario(ALUNOS, cliente)
                for p in patches:
                    p.start()
                try:
                    with self.assertRaises(AIResponseError) as erro:
                        service.execute(10, 20, 2)
                    self.assertEqual(str(erro.exception), MENSAGEM_INDISPONIVEL)
                finally:
                    for p in patches:
                        p.stop()

    def test_referencia_alem_dos_50_enviados_e_invalida(self):
        muitos = [{"id": 5000 + n, "nome": "P%02d Sobre" % n, "matricula": "M", "email": "e@x.t"}
                  for n in range(1, 53)]
        resultados = {a["id"]: (60, 6.0, "adequado", True) for a in muitos}
        cliente = ClienteCapturador(insights(resumo="Aluno 51 se destacou."))
        service, patches = cenario(muitos, cliente, lambda aid, t, e: calculo_de(resultados, aid))
        for p in patches:
            p.start()
        try:
            with self.assertRaises(AIResponseError):
                service.execute(10, 20, 2)
        finally:
            for p in patches:
                p.stop()

    def test_o_mapa_de_nomes_nao_vai_para_o_provedor(self):
        cliente, saida = self.rodar()
        # o que o cliente recebe e so o payload: sem mapa, sem nomes
        self.assertNotIn("mapa", json.dumps(cliente.payload).lower())
        # e o retorno ao Flutter mantem o contrato de quatro secoes
        self.assertEqual(set(saida["insights"]),
                         {"resumo", "pontosPositivos", "pontosAtencao", "sugestoesGerais"})
        self.assertTrue(saida["geradoPorIA"])


class PromptEContratoTest(unittest.TestCase):
    def test_prompt_do_9a_pede_referencias_e_mantem_as_regras(self):
        from services.ia.client import SYSTEM_PROMPT
        self.assertIn('"Aluno 1"', SYSTEM_PROMPT)
        self.assertIn("campo referencia", SYSTEM_PROMPT)
        for regra in ("nunca use pendente", "nao infira esforco", "nao preveja",
                      "sem nota lancada"):
            self.assertIn(regra, SYSTEM_PROMPT.lower().replace("\n", " "))
        for chave in ("resumo", "pontosPositivos", "pontosAtencao", "sugestoesGerais"):
            self.assertIn(chave, SYSTEM_PROMPT)


if __name__ == "__main__":
    unittest.main()

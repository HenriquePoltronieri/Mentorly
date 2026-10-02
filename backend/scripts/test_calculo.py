"""Regressoes do Marco 2, sem acessar o banco: python scripts/test_calculo.py."""

import os
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from services.academico import calculo


class CalculoTest(unittest.TestCase):
    def setUp(self):
        self.etapa = {
            "id": 1, "coordenacao_id": 1, "nome": "Etapa 1", "ordem": 1,
            "nota_minima": 60, "nota_maxima": 100,
        }
        self.criterios = [{"id": 1, "nome": "Provas", "peso": 100}]
        self.atividades = {1: [{"id": 1, "nota_maxima": 10}]}
        self.notas = {}
        for alvo, metodo, resposta in (
            (calculo.Criterio, "find_all_by_etapa", lambda *args: self.criterios),
            (calculo.Atividade, "find_por_criterio", lambda t, e, c: self.atividades[c]),
            (calculo.Nota, "valores_por_atividade", lambda a, ids: {
                i: self.notas[i] for i in ids if i in self.notas
            }),
        ):
            mock = patch.object(alvo, metodo, side_effect=resposta)
            mock.start()
            self.addCleanup(mock.stop)

    def test_nota_ausente_nao_e_zero(self):
        resultado = calculo.calcular_desempenho_etapa(1, 1, self.etapa)
        self.assertEqual(resultado["situacao"], "em_andamento")
        self.assertIsNone(resultado["nota_calculada"])
        self.notas[1] = 0
        resultado = calculo.calcular_desempenho_etapa(1, 1, self.etapa)
        self.assertEqual(resultado["situacao"], "abaixo_do_minimo")
        self.assertEqual(resultado["nota_calculada"], 0)
        self.assertTrue(resultado["completo"])

    def test_peso_invalido_bloqueia_resultado(self):
        self.criterios[0]["peso"] = 80
        self.notas[1] = 10
        resultado = calculo.calcular_desempenho_etapa(1, 1, self.etapa)
        self.assertEqual(resultado["situacao"], "configuracao_invalida")
        self.assertIsNone(resultado["nota_calculada"])

    def test_ponderacao_e_normalizacao(self):
        self.criterios = [
            {"id": 1, "nome": "Provas", "peso": 70},
            {"id": 2, "nome": "Trabalhos", "peso": 30},
        ]
        self.atividades = {
            1: [{"id": 1, "nota_maxima": 20}, {"id": 2, "nota_maxima": 20}],
            2: [{"id": 3, "nota_maxima": 10}],
        }
        self.notas = {1: 18, 2: 16, 3: 9}
        resultado = calculo.calcular_desempenho_etapa(1, 1, self.etapa)
        self.assertEqual(resultado["nota_calculada"], 86.5)
        self.assertEqual(resultado["situacao"], "adequado")

    def test_soma_sem_arredondamento_intermediario(self):
        # Marco 4 / A02: dois criterios de 50%, cada um com desempenho
        # 1/3 = 33,333...%. Arredondar CADA contribuicao antes de somar
        # (33,33 + 33,33 = 66,66 -> /100 * 100 = 33,34 de nota) dava 33,34;
        # a soma exata (33,333...% + 33,333...% = 66,666...%) arredonda
        # corretamente para 33,33 no final. Com nota_minima 33,34, isso
        # muda a situacao de "adequado" (bug) para "abaixo_do_minimo" (certo).
        self.criterios = [
            {"id": 1, "nome": "Provas", "peso": 50},
            {"id": 2, "nome": "Trabalhos", "peso": 50},
        ]
        self.atividades = {
            1: [{"id": 1, "nota_maxima": 3}],
            2: [{"id": 2, "nota_maxima": 3}],
        }
        self.notas = {1: 1, 2: 1}
        self.etapa["nota_minima"] = 33.34
        resultado = calculo.calcular_desempenho_etapa(1, 1, self.etapa)
        self.assertEqual(resultado["nota_calculada"], 33.33)
        self.assertEqual(resultado["percentual"], 33.33)
        self.assertEqual(resultado["situacao"], "abaixo_do_minimo")

    def test_contribuicao_exibida_continua_arredondada_por_criterio(self):
        # O campo "contribuicao" de cada criterio (usado na tela de detalhe
        # do aluno) continua arredondado para exibicao; so a SOMA usada no
        # resultado final deixou de arredondar cada parcela antes.
        self.criterios = [
            {"id": 1, "nome": "Provas", "peso": 50},
            {"id": 2, "nome": "Trabalhos", "peso": 50},
        ]
        self.atividades = {
            1: [{"id": 1, "nota_maxima": 3}],
            2: [{"id": 2, "nota_maxima": 3}],
        }
        self.notas = {1: 1, 2: 1}
        resultado = calculo.calcular_desempenho_etapa(1, 1, self.etapa)
        contribuicoes = {c["criterio_id"]: c["contribuicao"] for c in resultado["criterios"]}
        self.assertEqual(contribuicoes[1], 16.67)
        self.assertEqual(contribuicoes[2], 16.67)

    def test_contagem_de_atividades_avaliadas(self):
        # Marco 3: o boletim precisa saber quantas atividades ja tem nota e
        # quantas ainda faltam, sem inventar - so contando o que o motor ja
        # calcula por criterio.
        self.atividades = {1: [{"id": 1, "nota_maxima": 10}, {"id": 2, "nota_maxima": 10}]}
        self.notas = {1: 8}
        resultado = calculo.calcular_desempenho_etapa(1, 1, self.etapa)
        self.assertEqual(resultado["total_atividades"], 2)
        self.assertEqual(resultado["atividades_avaliadas"], 1)
        self.assertEqual(resultado["atividades_sem_nota"], 1)
        self.assertFalse(resultado["fechada"])


class ConsolidadoGeralTest(unittest.TestCase):
    def _etapa(self, situacao, percentual, fechada=True, completo=True):
        return {
            "situacao": situacao, "percentual": percentual,
            "fechada": fechada, "completo": completo,
        }

    def test_sem_etapa_fechada_fica_em_andamento(self):
        etapas = [self._etapa("adequado", 90, fechada=False)]
        resultado = calculo.calcular_consolidado_geral(etapas)
        self.assertEqual(resultado["situacao"], "em_andamento")
        self.assertIsNone(resultado["percentual"])
        self.assertEqual(resultado["etapas_consideradas"], 0)

    def test_etapa_em_andamento_fechada_nao_entra(self):
        # fechada=True mas completo=False nao deveria existir na pratica
        # (fechar so congela o que ja foi calculado), mas a funcao precisa
        # ignorar mesmo assim - nunca tratar etapa incompleta como zero.
        etapas = [self._etapa("em_andamento", None, completo=False)]
        resultado = calculo.calcular_consolidado_geral(etapas)
        self.assertEqual(resultado["etapas_consideradas"], 0)

    def test_media_das_etapas_fechadas(self):
        etapas = [
            self._etapa("adequado", 90),
            self._etapa("adequado", 80),
            self._etapa("em_andamento", None, fechada=False, completo=False),
        ]
        resultado = calculo.calcular_consolidado_geral(etapas)
        self.assertEqual(resultado["situacao"], "adequado")
        self.assertEqual(resultado["percentual"], 85.0)
        self.assertEqual(resultado["etapas_consideradas"], 2)

    def test_uma_etapa_fechada_abaixo_do_minimo_derruba_o_consolidado(self):
        etapas = [self._etapa("adequado", 90), self._etapa("abaixo_do_minimo", 40)]
        resultado = calculo.calcular_consolidado_geral(etapas)
        self.assertEqual(resultado["situacao"], "abaixo_do_minimo")


class ContextoDeAnoTest(unittest.TestCase):
    """Marco 6: o motor nunca decide o ano; quem chama diz de qual ano fala."""

    def test_etapa_atual_exige_o_ano(self):
        with self.assertRaises(ValueError):
            calculo.etapa_atual(1, None)

    def test_calculo_de_todas_as_etapas_exige_o_ano(self):
        # Sem ano, Etapa.find_all_by_coordenacao devolveria etapas de TODOS
        # os anos e o boletim misturaria anos diferentes.
        with self.assertRaises(ValueError):
            calculo.calcular_todas_etapas(1, 1, 1, None)

    def test_etapa_atual_procura_so_no_ano_pedido(self):
        with patch.object(
            calculo.Etapa, "find_all_by_coordenacao", return_value=[]
        ) as busca:
            etapa, regra = calculo.etapa_atual(7, 2027)
        busca.assert_called_once_with(7, 2027)
        self.assertIsNone(etapa)
        self.assertEqual(regra, "sem_etapas_configuradas")


if __name__ == "__main__":
    unittest.main()

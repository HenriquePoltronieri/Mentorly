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


if __name__ == "__main__":
    unittest.main()

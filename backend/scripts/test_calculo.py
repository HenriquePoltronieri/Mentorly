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


if __name__ == "__main__":
    unittest.main()

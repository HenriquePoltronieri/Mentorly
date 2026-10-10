"""Limiter de requisicoes (M-08), sem banco: python scripts/test_rate_limit.py

Relogio injetado: nenhum teste espera os 15 minutos de verdade.
"""

import os
import sys
import threading
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from services import rate_limit
from services.rate_limit import LimiteExcedido, RateLimiter

LIMITES = {
    "teste": (3, 60),
    "outro": (2, 10),
}


class Relogio:
    def __init__(self):
        self.agora = 1000.0

    def __call__(self):
        return self.agora


def novo():
    relogio = Relogio()
    return RateLimiter(relogio), relogio


class JanelaDeslizanteTest(unittest.TestCase):
    def test_dentro_do_limite_passa_e_o_excedente_levanta(self):
        limiter, _ = novo()
        for _ in range(3):
            limiter.consumir("teste", "a", limites=LIMITES)
        with self.assertRaises(LimiteExcedido) as contexto:
            limiter.consumir("teste", "a", limites=LIMITES)
        self.assertEqual(contexto.exception.mensagem, rate_limit.MENSAGEM_PADRAO)

    def test_retry_after_e_o_tempo_ate_a_requisicao_mais_antiga_sair(self):
        limiter, relogio = novo()
        limiter.consumir("teste", "a", limites=LIMITES)      # t=1000
        relogio.agora += 10
        limiter.consumir("teste", "a", limites=LIMITES)      # t=1010
        limiter.consumir("teste", "a", limites=LIMITES)      # t=1010
        relogio.agora += 5                                    # t=1015
        with self.assertRaises(LimiteExcedido) as contexto:
            limiter.consumir("teste", "a", limites=LIMITES)
        # a mais antiga (1000) sai da janela de 60 s em 1060: faltam 45 s
        self.assertEqual(contexto.exception.retry_after, 45)

    def test_apos_a_janela_volta_a_permitir(self):
        limiter, relogio = novo()
        for _ in range(3):
            limiter.consumir("teste", "a", limites=LIMITES)
        relogio.agora += 59
        with self.assertRaises(LimiteExcedido):
            limiter.consumir("teste", "a", limites=LIMITES)
        relogio.agora += 2
        limiter.consumir("teste", "a", limites=LIMITES)  # nao levanta

    def test_a_requisicao_recusada_nao_e_registrada_nem_estende_o_bloqueio(self):
        limiter, relogio = novo()
        for _ in range(3):
            limiter.consumir("teste", "a", limites=LIMITES)
        for _ in range(20):
            with self.assertRaises(LimiteExcedido):
                limiter.consumir("teste", "a", limites=LIMITES)
        relogio.agora += 61
        for _ in range(3):  # os 20 recusados nao ocuparam vaga
            limiter.consumir("teste", "a", limites=LIMITES)

    def test_chaves_e_escopos_sao_independentes(self):
        limiter, _ = novo()
        for _ in range(3):
            limiter.consumir("teste", "a", limites=LIMITES)
        limiter.consumir("teste", "b", limites=LIMITES)    # outra chave
        limiter.consumir("outro", "a", limites=LIMITES)    # outro escopo
        with self.assertRaises(LimiteExcedido):
            limiter.consumir("teste", "a", limites=LIMITES)

    def test_retry_after_nunca_e_menor_que_um(self):
        erro = LimiteExcedido("x", 0)
        self.assertEqual(erro.retry_after, 1)

    def test_reset_zera_tudo(self):
        limiter, _ = novo()
        for _ in range(3):
            limiter.consumir("teste", "a", limites=LIMITES)
        limiter.reset()
        limiter.consumir("teste", "a", limites=LIMITES)
        self.assertEqual(limiter.total_de_chaves(), 1)


class LimpezaDeMemoriaTest(unittest.TestCase):
    def test_chaves_vencidas_sao_descartadas_oportunisticamente(self):
        limiter, relogio = novo()
        for i in range(500):
            limiter.consumir("teste", "chave-%d" % i, limites=LIMITES)
        self.assertEqual(limiter.total_de_chaves(), 500)
        # passa a janela e o intervalo de limpeza; uma consulta qualquer limpa
        relogio.agora += 120
        limiter.consumir("teste", "nova", limites=LIMITES)
        self.assertEqual(limiter.total_de_chaves(), 1)

    def test_chave_ainda_dentro_da_janela_nao_e_descartada(self):
        limiter, relogio = novo()
        limites = {"longo": (3, 600)}
        limiter.consumir("longo", "ativa", limites=limites)
        relogio.agora += 120   # passa o intervalo de limpeza, mas nao a janela
        limiter.consumir("longo", "outra", limites=limites)
        self.assertEqual(limiter.total_de_chaves(), 2)

    def test_sem_limpeza_antes_do_intervalo(self):
        limiter, relogio = novo()
        limiter.consumir("teste", "a", limites=LIMITES)
        relogio.agora += 30
        limiter.consumir("teste", "b", limites=LIMITES)
        self.assertEqual(limiter.total_de_chaves(), 2)


class ConcorrenciaTest(unittest.TestCase):
    def test_threads_simultaneas_nunca_passam_do_limite(self):
        limiter = RateLimiter()   # relogio real
        limites = {"corrida": (10, 600)}
        permitidas = []
        barradas = []
        largada = threading.Barrier(64)

        def tentar():
            largada.wait()
            try:
                limiter.consumir("corrida", "mesma-chave", limites=limites)
                permitidas.append(1)
            except LimiteExcedido:
                barradas.append(1)

        threads = [threading.Thread(target=tentar) for _ in range(64)]
        for t in threads:
            t.start()
        for t in threads:
            t.join()
        self.assertEqual(len(permitidas), 10)
        self.assertEqual(len(barradas), 54)


class ChavesTest(unittest.TestCase):
    def setUp(self):
        self.original = rate_limit.limiter
        rate_limit.limiter = RateLimiter(Relogio())
        self.addCleanup(setattr, rate_limit, "limiter", self.original)

    def test_login_usa_ip_mais_identificador_normalizado(self):
        for _ in range(rate_limit.LIMITES["login"][0]):
            rate_limit.limitar_por_origem("login", "10.0.0.1", "Ana@Escola.com ")
        with self.assertRaises(LimiteExcedido):
            rate_limit.limitar_por_origem("login", "10.0.0.1", " ana@escola.COM")
        # outro IP, ou outro identificador, nao herda
        rate_limit.limitar_por_origem("login", "10.0.0.2", "ana@escola.com")
        rate_limit.limitar_por_origem("login", "10.0.0.1", "bia@escola.com")

    def test_identificador_de_tipo_estranho_nao_quebra(self):
        for estranho in (None, 123, ["a"], {"a": 1}):
            rate_limit.limitar_por_origem("login", "10.0.0.1", estranho)

    def test_ia_tem_limite_unico_por_professor_para_as_quatro_funcoes(self):
        maximo = rate_limit.LIMITES["ia"][0]
        for _ in range(maximo):
            rate_limit.limitar_ia(7)
        with self.assertRaises(LimiteExcedido) as contexto:
            rate_limit.limitar_ia(7)
        self.assertEqual(contexto.exception.mensagem, rate_limit.MENSAGEM_IA)
        rate_limit.limitar_ia(8)  # outro professor tem o proprio limite

    def test_padroes_do_mvp(self):
        self.assertEqual(rate_limit.LIMITES["login"], (10, 900))
        self.assertEqual(rate_limit.LIMITES["codigo_confirmar"], (6, 900))
        self.assertEqual(rate_limit.LIMITES["codigo_enviar"], (5, 900))
        self.assertEqual(rate_limit.LIMITES["convite_reenviar"], (5, 900))
        self.assertEqual(rate_limit.LIMITES["ia"], (20, 900))


if __name__ == "__main__":
    unittest.main()

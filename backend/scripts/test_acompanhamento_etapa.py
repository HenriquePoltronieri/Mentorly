"""Regressões de alertas tardios e orientação individual, sem banco/provedor."""
import sys
from pathlib import Path
from datetime import date
from unittest import TestCase, main
from unittest.mock import MagicMock
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from services.professor.estatisticas_turma import resumir
from services.ia.chat_professor import renderizar, ChatProfessorService
from services.rate_limit import limiter
from erros import RecursoNaoEncontrado


def dados(hoje=date(2026, 8, 2), notas=None, atividades=None, etapas=None, criterios=None, atual=1, etapa_id=None):
    return resumir({"id": 7, "nome": "7A"}, etapas if etapas is not None else [
        {"id": 1, "nome": "Etapa 1", "nota_minima": 6, "nota_maxima": 10,
         "data_inicio": "2026-08-01", "data_fim": "2026-11-09"}], atual,
        atividades if atividades is not None else [
            {"id": 8, "titulo": "Trabalho de frações", "etapa_id": 1, "criterio_id": 1, "nota_maxima": 2}],
        [{"id": 2, "nome": "Lucas"}, {"id": 3, "nome": "Mariana"}],
        notas if notas is not None else [{"aluno_id": 2, "atividade_id": 8, "valor": 2},
                                       {"aluno_id": 3, "atividade_id": 8, "valor": 1}],
        etapa_id=etapa_id, hoje=hoje, criterios=criterios if criterios is not None else [{"id": 1, "etapa_id": 1, "peso": 100}])


def mariana(d):
    return next(a for a in d["alunos"] if a["id"] == 3)


class AcompanhamentoTest(TestCase):
    def test_trabalho_de_dois_pontos_no_inicio_nao_alerta(self):
        d = dados()
        self.assertEqual(d["alunos_em_risco"], 0)
        self.assertEqual(d["distribuicao_risco"]["Em andamento"], 2)
        self.assertEqual(mariana(d)["pontos_obtidos"], 1)
        self.assertEqual(mariana(d)["pontos_avaliados"], 2)

    def test_alerta_so_nos_ultimos_vinte_por_cento(self):
        self.assertEqual(mariana(dados(hoje=date(2026, 10, 19)))["risco"], "Em andamento")
        self.assertEqual(mariana(dados(hoje=date(2026, 10, 20)))["risco"], "Alto")
        self.assertEqual(dados(hoje=date(2026, 10, 20))["alunos_em_risco"], 1)

    def test_sem_datas_nao_adivinha_fim_com_uma_avaliacao(self):
        etapa = {"id": 1, "nome": "Etapa", "nota_minima": 6, "nota_maxima": 10}
        self.assertEqual(mariana(dados(etapas=[etapa]))["risco"], "Em andamento")
        self.assertEqual(mariana(dados(etapas=[{**etapa, "fechada": True}]))["risco"], "Alto")

    def test_sem_notas_ou_lancamentos_vencidos_nao_viram_zero(self):
        d = dados(hoje=date(2026, 11, 1), notas=[], atividades=[
            {"id": 8, "titulo": "Prova", "etapa_id": 1, "criterio_id": 1, "nota_maxima": 10, "data_entrega": "2026-10-01"}])
        a = mariana(d)
        self.assertEqual(a["risco"], "Sem dados")
        self.assertIsNone(a["media"])
        self.assertIsNone(a["pontos_obtidos"])
        self.assertEqual(a["acompanhamento"]["pontos_restantes"], 10)
        self.assertEqual(d["alunos_em_risco"], 0)

    def test_pontos_futuros_evitar_alerta_alto_e_recalcular(self):
        atividades = [{"id": 8, "titulo": "Trabalho", "etapa_id": 1, "criterio_id": 1, "nota_maxima": 2},
                      {"id": 9, "titulo": "Prova", "etapa_id": 1, "criterio_id": 1, "nota_maxima": 8}]
        d = dados(hoje=date(2026, 11, 1), atividades=atividades)
        a = mariana(d)
        self.assertEqual(a["risco"], "Em andamento")
        self.assertEqual(a["acompanhamento"]["pontos_ponderados"], 1)
        self.assertEqual(a["acompanhamento"]["pontos_restantes"], 8)
        d = dados(hoje=date(2026, 11, 1), atividades=atividades, notas=[
            {"aluno_id": 3, "atividade_id": 8, "valor": 1}, {"aluno_id": 3, "atividade_id": 9, "valor": 6}])
        self.assertEqual(mariana(d)["risco"], "Baixo")

    def test_alerta_medio_com_pontos_ainda_suficientes(self):
        a = mariana(dados(hoje=date(2026, 11, 1), atividades=[
            {"id": 8, "titulo": "Prova", "etapa_id": 1, "criterio_id": 1, "nota_maxima": 8},
            {"id": 9, "titulo": "Trabalho", "etapa_id": 1, "criterio_id": 1, "nota_maxima": 2}],
            notas=[{"aluno_id": 3, "atividade_id": 8, "valor": 4}]))
        self.assertEqual(a["risco"], "Médio")
        self.assertEqual(a["acompanhamento"]["pontos_restantes"], 2)

    def test_criterios_pesados_sem_misturar_soma_bruta(self):
        a = mariana(dados(hoje=date(2026, 11, 1), criterios=[
            {"id": 1, "etapa_id": 1, "peso": 20}, {"id": 2, "etapa_id": 1, "peso": 80}],
            atividades=[{"id": 8, "titulo": "Trabalho", "etapa_id": 1, "criterio_id": 1, "nota_maxima": 2},
                        {"id": 9, "titulo": "Prova", "etapa_id": 1, "criterio_id": 2, "nota_maxima": 20}],
            notas=[{"aluno_id": 3, "atividade_id": 8, "valor": 2}, {"aluno_id": 3, "atividade_id": 9, "valor": 8}]))
        self.assertEqual(a["pontos_obtidos"], 10)
        self.assertEqual(a["acompanhamento"]["pontos_ponderados"], 5.2)
        self.assertEqual(a["risco"], "Alto")

    def test_criterio_sem_atividades_mantem_pontos_disponiveis(self):
        a = mariana(dados(hoje=date(2026, 11, 1), criterios=[
            {"id": 1, "etapa_id": 1, "peso": 20}, {"id": 2, "etapa_id": 1, "peso": 80}]))
        self.assertEqual(a["acompanhamento"]["pontos_restantes"], 8)
        self.assertEqual(a["risco"], "Em andamento")

    def test_configuracao_invalida_nao_alerta(self):
        self.assertEqual(mariana(dados(hoje=date(2026, 11, 1), criterios=[]))["risco"], "Sem dados")

    def test_etapa_anterior_nao_contamina_alerta_atual(self):
        etapas = [{"id": 1, "nome": "Anterior", "nota_minima": 6, "nota_maxima": 10, "fechada": True},
                  {"id": 2, "nome": "Atual", "nota_minima": 6, "nota_maxima": 10}]
        atividades = [{"id": 8, "titulo": "Antiga", "etapa_id": 1, "criterio_id": 1, "nota_maxima": 2},
                      {"id": 9, "titulo": "Nova", "etapa_id": 2, "criterio_id": 2, "nota_maxima": 2}]
        criterios = [{"id": 1, "etapa_id": 1, "peso": 100}, {"id": 2, "etapa_id": 2, "peso": 100}]
        notas = [{"aluno_id": 3, "atividade_id": 8, "valor": 0}, {"aluno_id": 3, "atividade_id": 9, "valor": 2}]
        kwargs = dict(etapas=etapas, atividades=atividades, criterios=criterios, notas=notas, atual=2)
        self.assertEqual(mariana(dados(**kwargs))["risco"], "Em andamento")
        self.assertEqual(mariana(dados(**kwargs))["pontos_obtidos"], 2)
        self.assertEqual(mariana(dados(**kwargs, etapa_id=1))["risco"], "Alto")


class OrientacaoIndividualTest(TestCase):
    def setUp(self):
        limiter.reset()

    def test_pergunta_sobre_pontos_mostra_valor_real_sem_normalizar(self):
        r = renderizar({"fatos": [{"turma_id": 7, "aluno_id": 3, "metrica": "pontuacao"}], "medidas": []}, [dados()])
        self.assertIn("1 de 2 pontos", r["resposta"])
        self.assertIn("Em andamento", r["resposta"])
        self.assertNotIn("5/10", r["resposta"])

    def test_menor_nota_do_aluno_nao_menor_media_da_turma(self):
        d = dados(atividades=[
            {"id": 8, "titulo": "Frações", "etapa_id": 1, "criterio_id": 1, "nota_maxima": 2},
            {"id": 9, "titulo": "Geometria", "etapa_id": 1, "criterio_id": 1, "nota_maxima": 8}], notas=[
                {"aluno_id": 3, "atividade_id": 8, "valor": 0}, {"aluno_id": 3, "atividade_id": 9, "valor": 7},
                {"aluno_id": 2, "atividade_id": 8, "valor": 2}, {"aluno_id": 2, "atividade_id": 9, "valor": 0}])
        self.assertEqual(d["pior_atividade"]["titulo"], "Geometria")
        r = renderizar({"fatos": [{"turma_id": 7, "aluno_id": 3, "metrica": "dificuldade"}], "medidas": ["reforco", "recuperacao"]}, [d])
        self.assertIn("menores desempenhos registrados em Frações (0 de 2 pontos)", r["resposta"])
        self.assertIn("Para Mariana, em Frações (0/2 pontos)", r["resposta"])
        self.assertIn("nova avaliação dos mesmos objetivos", r["resposta"])

    def test_sem_notas_nao_inventa_dificuldade(self):
        r = renderizar({"fatos": [{"turma_id": 7, "aluno_id": 3, "metrica": "dificuldade"}], "medidas": ["reforco"]}, [dados(notas=[])])
        self.assertIn("ainda não há avaliações lançadas", r["resposta"])
        self.assertNotIn("Para Mariana, em", r["resposta"])

    def test_contexto_individual_e_aluno_de_outra_turma_bloqueado(self):
        client, stats = MagicMock(), MagicMock()
        stats.execute.return_value = dados()
        client.gerar.return_value = {"fatos": [], "medidas": []}
        s = ChatProfessorService(client, stats)
        s.execute(1, 1, {"turma_id": 7, "aluno_id": 3, "mensagem": "Como melhorar?"})
        contexto = client.gerar.call_args.args[0]["turmas"][0]["alunos"]
        self.assertEqual([a["id"] for a in contexto], [3])
        self.assertIn("acompanhamento", contexto[0])
        client.reset_mock()
        with self.assertRaises(RecursoNaoEncontrado):
            s.execute(1, 1, {"turma_id": 7, "aluno_id": 999, "mensagem": "Como melhorar?"})
        client.gerar.assert_not_called()


if __name__ == "__main__":
    main()

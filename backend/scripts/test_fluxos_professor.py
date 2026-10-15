"""Regressões A–E sem MySQL/Groq: fixtures somente em memória."""
import sys
from pathlib import Path
from datetime import date
from unittest import TestCase, main
from unittest.mock import patch, MagicMock
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app import create_app
from auth.jwt_utils import gerar_token
from erros import AcessoNegado
from services.professor.estatisticas_turma import resumir, EstatisticasTurmaService
from services.ia.chat_professor import ChatProfessorService, renderizar, _validar
from services.ia.client import AIResponseError
from services.rate_limit import limiter, LimiteExcedido
from services.coordenacao.cadastrar_professor import CadastrarProfessorService
from services.activity.create_activity import CreateActivityService
from services.professor.notas import LancarNotasService


def fixture():
    return resumir({"id": 7, "nome": "Turma teste"},
        [{"id": 1, "nome": "Etapa", "nota_minima": 6, "nota_maxima": 10,
          "data_inicio": "2026-08-01", "data_fim": "2026-10-15"}], 1,
        [{"id": 8, "titulo": "A", "etapa_id": 1, "criterio_id": 1, "nota_maxima": 20, "data_entrega": "2026-01-01"},
         {"id": 9, "titulo": "B", "etapa_id": 1, "criterio_id": 1, "nota_maxima": 10, "data_entrega": "2026-02-01"}],
        [{"id": 2, "nome": "Ana teste"}, {"id": 3, "nome": "Bia teste"}],
        [{"aluno_id": 2, "atividade_id": 8, "valor": 18},
         {"aluno_id": 2, "atividade_id": 9, "valor": 4},
         {"aluno_id": 3, "atividade_id": 8, "valor": 0, "observacao": "Não entregou"}], hoje=date(2026, 10, 12),
        criterios=[{"id": 1, "etapa_id": 1, "peso": 100}])


class MetricasTest(TestCase):
    def test_escala_risco_tendencia_e_entregas(self):
        d = fixture()
        a = {a["id"]: a for a in d["alunos"]}
        self.assertEqual(a[2]["media"], 7.33)  # 22/30 pontos, sem dar o mesmo peso a 10 e 20
        self.assertEqual(a[2]["tendencia"], "caindo")
        self.assertEqual(a[2]["risco"], "Baixo")
        self.assertEqual(a[3]["risco"], "Alto")
        self.assertEqual(a[3]["sem_nota"], 1)
        self.assertEqual(d["percentual_entregas"], 50)
        self.assertEqual(d["pior_atividade"]["id"], 9)
        self.assertEqual(d["alunos"][0]["id"], 3)

    def test_sem_notas_nao_inventa_media(self):
        d = resumir({"id": 7, "nome": "Turma"}, [], None, [], [{"id": 2, "nome": "Ana"}], [])
        self.assertIsNone(d["media"])
        self.assertIsNone(d["alunos"][0]["media"])
        self.assertEqual(d["alunos"][0]["tendencia"], "sem dados")
        self.assertIsNone(d["pior_atividade"])

    def test_filtro_nao_mistura_etapas(self):
        d = resumir({"id": 7, "nome": "Turma"}, [], None,
          [{"id": 1, "titulo": "E1", "etapa_id": 1, "nota_maxima": 10}, {"id": 2, "titulo": "E2", "etapa_id": 2, "nota_maxima": 10}],
          [{"id": 3, "nome": "Ana"}], [{"aluno_id": 3, "atividade_id": 1, "valor": 2}, {"aluno_id": 3, "atividade_id": 2, "valor": 10}], etapa_id=1)
        self.assertEqual(d["media"], 2)
        self.assertEqual(len(d["atividades"]), 1)

    @patch("services.professor.estatisticas_turma.ProfessorTurma.professor_leciona_na_turma", return_value=False)
    def test_ownership_bloqueia_antes_de_consultar(self, _vinculo):
        with patch("services.professor.estatisticas_turma.query_all") as banco:
            with self.assertRaises(AcessoNegado): EstatisticasTurmaService().execute(1, 1, 99)
            banco.assert_not_called()


class ChatTest(TestCase):
    def setUp(self): limiter.reset()

    def test_numeros_e_nomes_sao_do_backend(self):
        r = renderizar({"fatos": [{"turma_id": 7, "aluno_id": 3, "metrica": "risco"}], "medidas": ["conversa"]}, [fixture()])
        self.assertIn("Bia teste", r["resposta"])
        self.assertIn("Etapa: Alto", r["resposta"])
        self.assertIn("0 de 20 pontos", r["resposta"])
        self.assertEqual(r["atalhos"][0]["aluno_id"], 3)

    def test_id_inventado_nao_e_exibido(self):
        for f in [{"turma_id": 999, "metrica": "resumo"}, {"turma_id": 7, "aluno_id": 999, "metrica": "risco"}]:
            with self.assertRaises(AIResponseError): renderizar({"fatos": [f], "medidas": []}, [fixture()])

    def test_contrato_invalido_nao_e_exibido(self):
        with self.assertRaises(AIResponseError): _validar({"fatos": [], "medidas": ["inventado"]})

    def test_contexto_minimo_historico_e_mensagem(self):
        client, stats = MagicMock(), MagicMock()
        stats.execute.return_value = fixture()
        client.gerar.return_value = {"fatos": [{"turma_id": 7, "metrica": "resumo"}], "medidas": []}
        ChatProfessorService(client, stats).execute(1, 1, {"turma_id": 7, "mensagem": "Resumo", "historico": [{"role": "user", "content": "Oi"}]})
        payload = client.gerar.call_args.args[0]
        self.assertEqual(payload["historico"][0]["content"], "Oi")
        self.assertNotIn("email", str(payload))
        self.assertNotIn("matricula", str(payload))
        self.assertNotIn("telefone", str(payload))
        stats.execute.assert_called_once_with(1, 1, 7)

    def test_limite_mensagem_e_historico(self):
        s = ChatProfessorService(MagicMock(), MagicMock())
        for body in [{"mensagem": "x" * 1001}, {"mensagem": "Oi", "historico": [{"role": "system", "content": "x"}]}]:
            with self.assertRaises(ValueError): s.execute(1, 1, body)
        s.client.gerar.assert_not_called()

    def test_rate_limit_por_professor(self):
        client, stats = MagicMock(), MagicMock()
        stats.execute.return_value = fixture()
        client.gerar.return_value = {"fatos": [], "medidas": []}
        s = ChatProfessorService(client, stats)
        for _ in range(20): s.execute(1, 1, {"mensagem": "Oi", "turma_id": 7})
        with self.assertRaises(LimiteExcedido): s.execute(1, 1, {"mensagem": "Oi", "turma_id": 7})
        self.assertEqual(client.gerar.call_count, 20)

    def test_turma_alheia_nao_chega_ao_provedor(self):
        client, stats = MagicMock(), MagicMock()
        stats.execute.side_effect = AcessoNegado("Sem vínculo")
        with self.assertRaises(AcessoNegado): ChatProfessorService(client, stats).execute(1, 1, {"mensagem": "Oi", "turma_id": 999})
        client.gerar.assert_not_called()


class PermissoesTest(TestCase):
    def setUp(self):
        self.client = create_app().test_client()
        self.prof = {"Authorization": "Bearer " + gerar_token(1, "professor", 1)}
        self.coord = {"Authorization": "Bearer " + gerar_token(1, "coordenacao", 1)}
        self.auth = patch("auth.decorators._professor_habilitado", return_value=True)
        self.auth.start()
        self.addCleanup(self.auth.stop)
        acesso = patch('auth.decorators._conferir_acesso', return_value=None)
        acesso.start()
        self.addCleanup(acesso.stop)
        limiter.reset()

    def test_professor_nao_gerencia_alunos(self):
        rotas = [("post", "/api/professor/turmas/7/alunos"), ("post", "/api/professor/turmas/7/alunos/importar"),
                 ("put", "/api/professor/alunos/2"), ("delete", "/api/professor/alunos/2"),
                 ("post", "/api/coordenacao/turmas/7/alunos"), ("post", "/api/coordenacao/turmas/7/alunos/importar"),
                 ("put", "/api/coordenacao/alunos/2"), ("delete", "/api/coordenacao/alunos/2")]
        for verbo, url in rotas:
            with self.subTest(url=url): self.assertEqual(getattr(self.client, verbo)(url, headers=self.prof).status_code, 403)

    def test_coordenacao_nao_cria_atividade_ou_chat(self):
        for url in ["/api/activities", "/api/professor/ia/chat"]:
            self.assertEqual(self.client.post(url, headers=self.coord, json={"mensagem": "Oi"}).status_code, 403)

    def test_estatisticas_sem_vinculo_403(self):
        with patch("services.professor.estatisticas_turma.ProfessorTurma.professor_leciona_na_turma", return_value=False):
            for url in ["/api/professor/turmas/99/estatisticas", "/api/professor/turmas/99/alunos/2/estatisticas"]:
                self.assertEqual(self.client.get(url, headers=self.prof).status_code, 403)

    def test_chat_sem_chave_503_amigavel(self):
        from services.ia.client import AIConfigurationError
        with patch("services.ia.chat_professor.ChatProfessorService.execute", side_effect=AIConfigurationError("segredo técnico")):
            r = self.client.post("/api/professor/ia/chat", headers=self.prof, json={"mensagem": "Oi"})
        self.assertEqual(r.status_code, 503)
        self.assertNotIn("segredo", r.json["error"])

    def test_chat_aluno_inexistente_retorna_404(self):
        from erros import RecursoNaoEncontrado
        with patch("services.ia.chat_professor.ChatProfessorService.execute",
                   side_effect=RecursoNaoEncontrado("Aluno não encontrado nesta turma.")):
            r = self.client.post("/api/professor/ia/chat", headers=self.prof,
                                 json={"mensagem": "Como ajudar?", "turma_id": 7, "aluno_id": 999})
        self.assertEqual(r.status_code, 404)
        self.assertEqual(r.json["error"], "Aluno não encontrado nesta turma.")

    def test_criacao_atividade_sem_vinculo_403(self):
        with patch("services.activity.create_activity.ProfessorTurma.professor_leciona_na_turma", return_value=False):
            r = self.client.post("/api/activities", headers=self.prof, json={"title": "Prova", "class_id": 999})
        self.assertEqual(r.status_code, 403)

    def test_professor_email_invalido_nao_grava(self):
        with patch("services.coordenacao.cadastrar_professor.transacao") as gravar:
            with self.assertRaises(ValueError): CadastrarProfessorService().execute(1, "Ana", "invalido")
            gravar.assert_not_called()

    def test_professor_turma_alheia_nao_grava(self):
        with patch("services.coordenacao.cadastrar_professor.Turma.find_by_id", return_value=None), patch("services.coordenacao.cadastrar_professor.transacao") as gravar:
            with self.assertRaises(ValueError): CadastrarProfessorService().execute(1, "Ana", "a@example.invalid", turma_ids=[999])
            gravar.assert_not_called()

if __name__ == "__main__": main()

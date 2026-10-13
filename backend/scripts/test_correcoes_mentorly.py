"""Regressões reais em banco isolado; nenhum e-mail é enviado."""
import os
import sys
import unittest
import uuid
from urllib.parse import parse_qs, urlparse
from unittest.mock import patch

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
# Não usa nem limpa a base pessoal do desenvolvedor.
os.environ["DB_NAME"] = "mentorly_correcao_regressao"
os.environ["DEV_EXPOSE_AUTH_CODES"] = "false"

from app import create_app
from database.connection import execute, insert, init_database, install_schema, install_procedures, query_one
from models.professor_model import hash_convite
from services import email_service, rate_limit


class CorrecoesTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        init_database()
        install_schema()
        install_procedures()

    def setUp(self):
        rate_limit.limiter.reset()
        self.client = create_app().test_client()
        self.email = "teste-%s@escola.invalid" % uuid.uuid4().hex
        resposta = self.client.post("/api/auth/cadastro-coordenacao", json={
            "nome": "Escola de teste", "email": self.email, "senha": "senha123", "telefone": "11999999999"})
        self.assertEqual(resposta.status_code, 201, resposta.json)
        self.escola = resposta.json["usuario"]["id"]
        self.coord = {"Authorization": "Bearer " + resposta.json["token"]}
        self.client.post("/api/config/anos-letivos", headers=self.coord, json={"ano": 2026, "status": "atual"})
        self.smtp = patch("services.coordenacao.cadastrar_professor.enviar_convite_professor", return_value=False)
        self.smtp.start()
        self.reenvio = patch("services.coordenacao.gerenciar_professor.enviar_convite_professor", return_value=False)
        self.reenvio.start()

    def tearDown(self):
        self.smtp.stop()
        self.reenvio.stop()
        for tabela in ("atividade", "professor_turma", "turma", "criterio", "etapa", "professor", "ano_letivo", "coordenacao"):
            coluna = "id" if tabela == "coordenacao" else "coordenacao_id"
            execute("DELETE FROM " + tabela + " WHERE " + coluna + "=%s", (self.escola,))

    def configurar(self, quantidade=3, criterios=None, headers=None):
        return self.client.put("/api/config/anos-letivos/2026/configuracao", headers=headers or self.coord, json={
            "etapas": [{"nome": "Etapa %d" % i, "nota_minima": 6, "nota_maxima": 10} for i in range(1, quantidade + 1)],
            "criterios": criterios if criterios is not None else [{"nome": "Provas", "peso": 50}, {"nome": "Trabalhos", "peso": 50}],
        })

    def convite(self):
        resposta = self.client.post("/api/coordenacao/professores", headers=self.coord, json={
            "nome": "Ana", "email": "ana-" + self.email, "disciplina": "Matemática"})
        self.assertEqual(resposta.status_code, 201, resposta.json)
        self.assertFalse(resposta.json["conviteEnviado"])
        self.assertNotIn("conviteToken", resposta.json)
        token = parse_qs(urlparse(urlparse(resposta.json["conviteLink"]).fragment).query)["token"][0]
        return resposta.json, token

    def professor(self):
        dados, token = self.convite()
        resposta = self.client.post("/api/auth/criar-senha-professor", json={"token": token, "senha": "senha123"})
        self.assertEqual(resposta.status_code, 200, resposta.json)
        return dados, {"Authorization": "Bearer " + resposta.json["token"]}

    def test_1_2_3_4_personalizado_e_reabertura(self):
        for quantidade in (1, 2, 3, 4, 7, 12):
            with self.subTest(quantidade=quantidade):
                resposta = self.configurar(quantidade)
                self.assertEqual(resposta.status_code, 200, resposta.json)
                salvo = self.client.get("/api/config/etapas?ano_letivo=2026", headers=self.coord)
                self.assertEqual(len(salvo.json), quantidade)
                for etapa in salvo.json:
                    self.assertEqual(etapa["nota_minima"], 6)
                    self.assertEqual(etapa["nota_maxima"], 10)
                    self.assertTrue(etapa["pesoValido"])
                    self.assertEqual(etapa["pesoTotal"], 100)

    def test_validacao_sem_gravacao_parcial(self):
        self.configurar(2)
        anterior = self.client.get("/api/config/etapas", headers=self.coord).json
        for pesos in ([{"nome": "Provas", "peso": 90}], [{"nome": "Provas", "peso": -10}, {"nome": "Trabalhos", "peso": 110}],
                      [{"nome": "Provas", "peso": 33.333}, {"nome": "Trabalhos", "peso": 66.667}]):
            self.assertEqual(self.configurar(4, pesos).status_code, 400)
            self.assertEqual(self.client.get("/api/config/etapas", headers=self.coord).json, anterior)
        invalido = self.client.put("/api/config/anos-letivos/2026/configuracao", headers=self.coord, json={
            "etapas": [{"nota_minima": 10, "nota_maxima": 10}], "criterios": [{"nome": "Provas", "peso": 100}]})
        self.assertEqual(invalido.status_code, 400)

    def test_consulta_convite_recusa_ausente_invalido_e_desativado(self):
        dados, token = self.convite()
        for corpo, status in (({}, 400), ({'token': 'inexistente'}, 403)):
            resposta = self.client.post('/api/auth/consultar-convite', json=corpo)
            self.assertEqual(resposta.status_code, status)
            self.assertNotIn('email', resposta.json)
        execute('UPDATE professor SET habilitado=0 WHERE id=%s', (dados['id'],))
        resposta = self.client.post('/api/auth/consultar-convite', json={'token': token})
        self.assertEqual(resposta.status_code, 403)
        self.assertNotIn('email', resposta.json)

    def test_convite_hash_uso_unico_e_login(self):
        dados, token = self.convite()
        banco = query_one("SELECT convite_token FROM professor WHERE id=%s", (dados["id"],))
        self.assertEqual(banco["convite_token"], hash_convite(token))
        self.assertNotEqual(banco["convite_token"], token)
        consulta = self.client.post('/api/auth/consultar-convite', json={'token': token})
        self.assertEqual(consulta.status_code, 200)
        self.assertEqual(consulta.json, {'email': dados['email']})
        self.assertEqual(query_one('SELECT convite_token FROM professor WHERE id=%s', (dados['id'],))['convite_token'], banco['convite_token'])
        resposta = self.client.post("/api/auth/criar-senha-professor", json={"token": token, "senha": "senha123"})
        self.assertEqual(resposta.status_code, 200, resposta.json)
        self.assertEqual(self.client.post('/api/auth/consultar-convite', json={'token': token}).status_code, 403)
        self.assertEqual(self.client.post("/api/auth/criar-senha-professor", json={"token": token, "senha": "senha123"}).status_code, 403)
        self.assertEqual(self.client.post("/api/auth/login-professor", json={"email": dados["email"], "senha": "senha123"}).status_code, 200)
        lista = self.client.get("/api/coordenacao/professores", headers=self.coord)
        self.assertEqual(lista.status_code, 200)
        self.assertEqual(lista.json[0]["status"], "ativo")
        self.assertNotIn("conviteLink", lista.json[0])

    def test_expiracao_renovacao_e_lista_apos_falha_smtp(self):
        dados, token = self.convite()
        execute("UPDATE professor SET convite_expira_em=DATE_SUB(NOW(), INTERVAL 1 HOUR) WHERE id=%s", (dados["id"],))
        self.assertEqual(self.client.post('/api/auth/consultar-convite', json={'token': token}).status_code, 403)
        resposta = self.client.post("/api/auth/criar-senha-professor", json={"token": token, "senha": "senha123"})
        self.assertEqual(resposta.status_code, 403)
        self.assertIn("expirado", resposta.json["error"])
        novo = self.client.post("/api/coordenacao/professores/%d/link-convite" % dados["id"], headers=self.coord)
        self.assertEqual(novo.status_code, 200)
        self.assertIn("conviteLink", novo.json)
        self.assertEqual(self.client.get("/api/coordenacao/professores", headers=self.coord).json[0]["status"], "convite_pendente")

    def test_coordenacao_recebe_403_em_toda_area_academica(self):
        for metodo, rota in (("get", "/api/activities"), ("get", "/api/activities/buscar"), ("get", "/api/activities/1"),
                             ("get", "/api/classes/relatorio/atividades"), ("get", "/api/coordenacao/turmas/1/boletim"),
                             ("get", "/api/professor/turmas/1/boletim"), ("get", "/api/professor/alunos/1/estatisticas"),
                             ("get", "/api/professor/dashboard"), ("post", "/api/config/etapas/1/fechar"),
                             ("post", "/api/config/etapas/1/reabrir"), ("get", "/api/atividades/1/notas")):
            with self.subTest(rota=rota):
                self.assertEqual(getattr(self.client, metodo)(rota, headers=self.coord).status_code, 403)
        self.assertNotIn("total_atividades", self.client.get("/api/dashboard/resumo", headers=self.coord).json)

    def test_professor_fecha_apenas_ano_vinculado(self):
        etapas = self.configurar(1).json
        dados, professor = self.professor()
        rota = "/api/config/etapas/%d/fechar" % etapas[0]["id"]
        self.assertEqual(self.client.post(rota, headers=professor).status_code, 404)
        turma = self.client.post("/api/classes", headers=self.coord, json={"nome": "Turma A", "ano_letivo": 2026}).json
        self.client.post("/api/coordenacao/professores/%d/turmas" % dados["id"], headers=self.coord, json={"turma_ids": [turma["id"]]})
        self.assertEqual(self.client.post(rota, headers=professor).status_code, 200)
        self.assertEqual(self.configurar(2).status_code, 400)
        self.assertEqual(self.client.post(rota.replace("fechar", "reabrir"), headers=professor).status_code, 200)
        self.assertEqual(self.client.get("/api/professor/turmas/%d/boletim" % turma["id"], headers=professor).status_code, 200)
        self.assertEqual(self.configurar(headers=professor).status_code, 403)

    def test_smtp_starttls_timeout_e_template_sem_segredos(self):
        with patch.dict(email_service.SMTP_CONFIG, {"host": "smtp.gmail.com", "port": 587, "usar_tls": True,
                                                  "user": "conta@example.test", "password": "senha-de-app", "timeout": 3}), \
             patch("services.email_service.smtplib.SMTP") as smtp:
            self.assertTrue(email_service.enviar_convite_professor("Ana", "ana@example.test", "token", "Escola"))
            self.assertEqual(smtp.call_args.kwargs["timeout"], 3)
            cliente = smtp.return_value.__enter__.return_value
            cliente.starttls.assert_called_once()
            mensagem = cliente.send_message.call_args.args[0]
            self.assertTrue(mensagem.is_multipart())
            self.assertIn("Criar minha senha", mensagem.get_body(preferencelist=("html",)).get_content())
            self.assertNotIn("senha-de-app", mensagem.as_string())

    def test_configuracao_rollback_preserva_criterios_usados(self):
        etapa = self.configurar(1).json[0]
        dados, _professor = self.professor()
        turma = self.client.post("/api/classes", headers=self.coord, json={"nome": "Turma A", "ano_letivo": 2026}).json
        insert("INSERT INTO atividade (coordenacao_id,turma_id,professor_id,etapa_id,criterio_id,titulo,nota_maxima) VALUES (%s,%s,%s,%s,%s,%s,10)",
               (self.escola, turma["id"], dados["id"], etapa["id"], etapa["criterios"][1]["id"], "Trabalho existente"))
        anterior = self.client.get("/api/config/etapas", headers=self.coord).json
        resposta = self.configurar(2, [{"nome": "Provas", "peso": 100}])
        self.assertEqual(resposta.status_code, 409, resposta.json)
        self.assertIn("atividades vinculadas", resposta.json["error"])
        self.assertEqual(self.client.get("/api/config/etapas", headers=self.coord).json, anterior)

    def test_calculo_em_lote_equivalente_e_consultas_constantes(self):
        from models.dados_academicos_model import carregar_dados_turma
        from services.academico.calculo import calcular_todas_etapas
        etapas = self.configurar(2).json
        dados_prof, professor = self.professor()
        turma = self.client.post("/api/classes", headers=self.coord, json={"nome": "Turma A", "ano_letivo": 2026}).json
        self.client.post("/api/coordenacao/professores/%d/turmas" % dados_prof["id"], headers=self.coord, json={"turma_ids": [turma["id"]]})
        aluno = insert("INSERT INTO aluno(turma_id,nome) VALUES (%s,%s)", (turma["id"], "Aluno de teste"))
        for etapa in etapas:
            for criterio in etapa["criterios"]:
                atividade = insert("INSERT INTO atividade (coordenacao_id,turma_id,professor_id,etapa_id,criterio_id,titulo,nota_maxima) VALUES (%s,%s,%s,%s,%s,%s,10)",
                    (self.escola, turma["id"], dados_prof["id"], etapa["id"], criterio["id"], "Avaliação"))
                insert("INSERT INTO nota(atividade_id,aluno_id,valor) VALUES (%s,%s,6.67)", (atividade, aluno))
        lote = carregar_dados_turma(turma["id"], self.escola, 2026)
        self.assertEqual(calcular_todas_etapas(aluno, turma["id"], self.escola, 2026),
                         calcular_todas_etapas(aluno, turma["id"], self.escola, 2026, lote))
        rota = "/api/professor/turmas/%d/boletim" % turma["id"]
        primeiro = self.client.get(rota, headers=professor)
        for i in range(40):
            insert("INSERT INTO aluno(turma_id,nome) VALUES (%s,%s)", (turma["id"], "Aluno %d" % i))
        maior = self.client.get(rota, headers=professor)
        self.assertEqual(maior.status_code, 200)
        self.assertEqual(len(maior.json["alunos"]), 41)
        self.assertEqual(primeiro.headers["Server-Timing"].split("db;")[1], maior.headers["Server-Timing"].split("db;")[1])


if __name__ == "__main__":
    unittest.main()

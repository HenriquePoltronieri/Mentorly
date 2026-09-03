"""Teste de ponta a ponta da API, via test_client do Flask.

Cobre o que as Etapas 2 a 7 prometem:
  - login e cadastro devolvem {token, usuario};
  - rota protegida sem token responde 401;
  - a escola A nao enxerga NADA da escola B;
  - o professor so ve as turmas que a Coordenacao vinculou a ele;
  - a Coordenacao NAO cria atividade nem lanca nota (403);
  - a configuracao de ano letivo e padrao da escola (nao duplica);
  - a importacao por planilha funciona para os dois papeis e reporta erros.

Uso (a partir da pasta backend):
    python scripts/smoke_api.py
"""

import io
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import app as app_module
from database.connection import execute, query_all

SUFIXO = "smoke-api@mentorly.local"

falhas = []
_passos = [0]


def checar(condicao, descricao):
    _passos[0] += 1
    if condicao:
        print("    ok   %s" % descricao)
    else:
        print("    FALHA %s" % descricao)
        falhas.append(descricao)


def limpar():
    escolas = query_all(
        "SELECT id FROM coordenacao WHERE email LIKE %s", ("%" + SUFIXO,)
    )
    for escola in escolas:
        cid = escola["id"]
        execute(
            "DELETE FROM nota WHERE atividade_id IN (SELECT a.id FROM atividade a "
            "INNER JOIN turma t ON t.id = a.turma_id WHERE t.coordenacao_id = %s)",
            (cid,),
        )
        execute(
            "DELETE FROM atividade WHERE turma_id IN "
            "(SELECT id FROM turma WHERE coordenacao_id = %s)", (cid,)
        )
        execute("DELETE FROM professor_turma WHERE coordenacao_id = %s", (cid,))
        execute(
            "DELETE FROM aluno WHERE turma_id IN "
            "(SELECT id FROM turma WHERE coordenacao_id = %s)", (cid,)
        )
        execute("DELETE FROM criterio WHERE coordenacao_id = %s", (cid,))
        execute("DELETE FROM etapa WHERE coordenacao_id = %s", (cid,))
        execute("DELETE FROM turma WHERE coordenacao_id = %s", (cid,))
        execute("DELETE FROM professor WHERE coordenacao_id = %s", (cid,))
        execute("DELETE FROM coordenacao WHERE id = %s", (cid,))


class Cliente:
    """Envolve o test_client guardando o token, como o ApiService do Flutter."""

    def __init__(self, cliente):
        self._cliente = cliente
        self.token = None

    def _cabecalhos(self):
        return {"Authorization": "Bearer %s" % self.token} if self.token else {}

    def get(self, url):
        return self._cliente.get(url, headers=self._cabecalhos())

    def post(self, url, corpo=None):
        return self._cliente.post(url, json=corpo or {}, headers=self._cabecalhos())

    def put(self, url, corpo=None):
        return self._cliente.put(url, json=corpo or {}, headers=self._cabecalhos())

    def delete(self, url):
        return self._cliente.delete(url, headers=self._cabecalhos())

    def upload(self, url, nome_arquivo, conteudo):
        return self._cliente.post(
            url,
            data={"arquivo": (io.BytesIO(conteudo), nome_arquivo)},
            content_type="multipart/form-data",
            headers=self._cabecalhos(),
        )


def montar_escola(cliente_flask, rotulo):
    """Cadastra coordenacao, turma e professor. Devolve os clientes e ids."""
    coord = Cliente(cliente_flask)
    resposta = coord.post("/api/auth/cadastro-coordenacao", {
        "nome": "Escola %s" % rotulo,
        "email": "%s.%s" % (rotulo.lower(), SUFIXO),
        "senha": "senha123",
        "telefone": "31999990000",
    })
    assert resposta.status_code == 201, resposta.get_json()
    coord.token = resposta.get_json()["token"]

    turma = coord.post("/api/classes", {
        "name": "9 Ano %s" % rotulo, "description": "Turma de teste"
    }).get_json()

    professor = coord.post("/api/coordenacao/professores", {
        "nome": "Professor %s" % rotulo,
        "email": "prof.%s.%s" % (rotulo.lower(), SUFIXO),
        "disciplina": "Matematica",
    }).get_json()

    return coord, turma, professor


def main():
    aplicacao = app_module.create_app()
    aplicacao.config["TESTING"] = True

    with aplicacao.test_client() as cliente_flask:
        print("Limpando restos de execucoes anteriores...")
        limpar()

        # ---------------------------------------------------------
        print("\n[1] Autenticacao")
        coord_a, turma_a, prof_a = montar_escola(cliente_flask, "A")
        coord_b, turma_b, prof_b = montar_escola(cliente_flask, "B")
        checar(coord_a.token and coord_b.token, "cadastro devolve token")

        anonimo = Cliente(cliente_flask)
        checar(anonimo.get("/api/classes").status_code == 401,
               "rota protegida sem token responde 401")

        login = coord_a._cliente.post("/api/auth/login-coordenacao", json={
            "email": "a.%s" % SUFIXO, "senha": "senha123"
        })
        checar(login.status_code == 200 and login.get_json()["usuario"]["tipo"]
               == "coordenacao", "login da coordenacao funciona")

        checar(coord_a._cliente.post("/api/auth/login-coordenacao", json={
            "email": "a.%s" % SUFIXO, "senha": "errada"
        }).status_code == 401, "senha errada responde 401")

        # ---------------------------------------------------------
        print("\n[2] Isolamento entre escolas")
        turmas_a = coord_a.get("/api/classes").get_json()
        checar(all(t["id"] != turma_b["id"] for t in turmas_a),
               "GET /api/classes da escola A nao traz turma da B")

        profs_a = coord_a.get("/api/coordenacao/professores").get_json()
        checar(len(profs_a) == 1 and profs_a[0]["id"] == prof_a["id"],
               "GET /api/coordenacao/professores traz so o professor da escola")

        checar(coord_a.get("/api/classes/%d" % turma_b["id"]).status_code == 404,
               "buscar turma da outra escola responde 404")

        checar(coord_a.put("/api/classes/%d" % turma_b["id"],
                           {"name": "invadida"}).status_code == 404,
               "editar turma da outra escola responde 404")

        checar(coord_a.delete("/api/classes/%d" % turma_b["id"]).status_code == 404,
               "excluir turma da outra escola responde 404")

        checar(coord_a.get(
            "/api/coordenacao/turmas/%d/alunos" % turma_b["id"]
        ).status_code == 404, "listar alunos de turma de outra escola responde 404")

        vinculo_cruzado = coord_a.post(
            "/api/coordenacao/professores/%d/turmas" % prof_a["id"],
            {"turma_ids": [turma_b["id"]]},
        )
        checar(vinculo_cruzado.status_code == 404,
               "vincular professor de A a turma de B e recusado")

        checar(coord_a.post(
            "/api/coordenacao/professores/%d/turmas" % prof_b["id"],
            {"turma_ids": [turma_a["id"]]},
        ).status_code == 404, "vincular professor de B pelo token de A e recusado")

        relatorio_a = coord_a.get("/api/classes/relatorio/atividades").get_json()
        checar(all(l["id"] != turma_b["id"] for l in relatorio_a),
               "relatorio da escola A nao inclui turma da B")

        # ---------------------------------------------------------
        print("\n[3] Professor ve so as turmas vinculadas")
        # Segunda turma na escola A, de proposito NAO vinculada ao professor.
        turma_a2 = coord_a.post("/api/classes", {"name": "8 Ano A"}).get_json()

        vinculo = coord_a.post(
            "/api/coordenacao/professores/%d/turmas" % prof_a["id"],
            {"turma_ids": [turma_a["id"]]},
        )
        checar(vinculo.status_code == 201, "vinculo dentro da mesma escola funciona")

        token_convite = prof_a.get("conviteToken")
        checar(bool(token_convite), "cadastro do professor gera convite")

        ativacao = cliente_flask.post("/api/auth/criar-senha-professor", json={
            "email": prof_a["email"], "senha": "senha123", "token": token_convite,
        })
        checar(ativacao.status_code == 200, "professor cria a senha pelo convite")

        professor_a = Cliente(cliente_flask)
        login_prof = cliente_flask.post("/api/auth/login-professor", json={
            "email": prof_a["email"], "senha": "senha123",
        })
        checar(login_prof.status_code == 200, "login do professor funciona")
        professor_a.token = login_prof.get_json()["token"]

        turmas_prof = professor_a.get("/api/professor/turmas").get_json()
        checar(len(turmas_prof) == 1 and turmas_prof[0]["id"] == turma_a["id"],
               "professor ve so a turma vinculada, nao as outras da escola")

        checar(professor_a.get(
            "/api/professor/turmas/%d/alunos" % turma_a2["id"]
        ).status_code == 404, "professor nao acessa turma nao vinculada da escola")

        checar(professor_a.get(
            "/api/professor/turmas/%d/alunos" % turma_b["id"]
        ).status_code == 404, "professor nao acessa turma de outra escola")

        checar(cliente_flask.post("/api/auth/criar-senha-professor", json={
            "email": prof_a["email"], "senha": "outra123", "token": token_convite,
        }).status_code == 403, "convite nao pode ser usado duas vezes")

        # ---------------------------------------------------------
        print("\n[4] Papeis: quem pode criar atividade e lancar nota")
        tentativa = coord_a.post("/api/activities", {
            "title": "Prova da coordenacao", "class_id": turma_a["id"],
        })
        checar(tentativa.status_code == 403,
               "COORDENACAO recebe 403 ao criar atividade")

        atividade = professor_a.post("/api/activities", {
            "title": "Prova 1", "class_id": turma_a["id"],
            "description": "Conteudo da etapa 1", "due_date": "",
        })
        checar(atividade.status_code == 201, "PROFESSOR cria atividade (201)")
        atividade = atividade.get_json()

        checar(coord_a.put("/api/activities/%d" % atividade["id"],
                           {"title": "x"}).status_code == 403,
               "COORDENACAO recebe 403 ao editar atividade")
        checar(coord_a.delete(
            "/api/activities/%d" % atividade["id"]
        ).status_code == 403, "COORDENACAO recebe 403 ao excluir atividade")

        checar(coord_a.post("/api/atividades/%d/notas" % atividade["id"],
                            {"notas": []}).status_code == 403,
               "COORDENACAO recebe 403 ao lancar nota")

        checar(professor_a.post("/api/activities", {
            "title": "Nao permitida", "class_id": turma_a2["id"],
        }).status_code == 404, "professor nao cria atividade em turma nao vinculada")

        checar(coord_a.post("/api/config/etapas", {
            "nome": "1 Etapa", "ordem": 1, "ano_letivo": 2026,
        }).status_code == 201, "COORDENACAO configura etapa")

        checar(professor_a.post("/api/config/etapas", {
            "nome": "Hack", "ordem": 9, "ano_letivo": 2026,
        }).status_code == 403, "PROFESSOR recebe 403 ao configurar etapa")

        # ---------------------------------------------------------
        print("\n[5] Configuracao do ano letivo e padrao da escola")
        etapa = coord_a.post("/api/config/etapas", {
            "nome": "1 Etapa", "ordem": 1, "ano_letivo": 2026,
        }).get_json()
        etapas = coord_a.get("/api/config/etapas?ano_letivo=2026").get_json()
        checar(len(etapas) == 1,
               "repetir o fluxo nao duplica a etapa (upsert por ordem/ano)")

        notas = coord_a.post("/api/config/etapas/%d/notas" % etapa["id"], {
            "nota_minima": 6, "nota_maxima": 10,
        })
        checar(notas.status_code == 200
               and notas.get_json()["nota_minima"] == 6.0,
               "nota minima e maxima da etapa sao gravadas")

        coord_a.post("/api/config/etapas", {
            "nome": "1 Etapa renomeada", "ordem": 1, "ano_letivo": 2026,
        })
        depois = coord_a.get("/api/config/etapas/%d" % etapa["id"]).get_json()
        checar(depois["nota_minima"] == 6.0,
               "reconfigurar a etapa nao apaga as notas ja definidas")

        criterio = coord_a.post("/api/config/criterios/etapa/%d" % etapa["id"],
                                {"nome": "Provas", "peso": 5})
        checar(criterio.status_code == 201, "criterio e criado na etapa")
        coord_a.post("/api/config/criterios/etapa/%d" % etapa["id"],
                     {"nome": "Provas", "peso": 7})
        criterios = coord_a.get(
            "/api/config/criterios/etapa/%d" % etapa["id"]
        ).get_json()
        checar(len(criterios) == 1, "criterio repetido nao duplica")

        checar(coord_b.get(
            "/api/config/etapas/%d" % etapa["id"]
        ).status_code == 404, "escola B nao acessa a etapa da escola A")

        # ---------------------------------------------------------
        print("\n[6] Alunos: cadastro manual e importacao por planilha")
        aluno = coord_a.post("/api/coordenacao/turmas/%d/alunos" % turma_a["id"], {
            "nome": "Maria Silva Santos", "matricula": "2026001",
        })
        checar(aluno.status_code == 201, "coordenacao cadastra aluno")

        incompleto = coord_a.post(
            "/api/coordenacao/turmas/%d/alunos" % turma_a["id"],
            {"nome": "Joao", "matricula": "2026002"},
        )
        checar(incompleto.status_code == 400,
               "nome sem sobrenome e recusado (nome completo obrigatorio)")

        csv_bytes = (
            "nome;matricula;email\n"
            "Ana Paula Lima;2026003;ana@escola.com\n"
            "Bruno;2026004;\n"
            "Carlos Eduardo Souza;2026005;\n"
            "Duplicada Matricula;2026001;\n"
        ).encode("utf-8")

        importacao = coord_a.upload(
            "/api/coordenacao/turmas/%d/alunos/importar" % turma_a["id"],
            "alunos.csv", csv_bytes,
        )
        dados = importacao.get_json()
        checar(importacao.status_code == 201 and dados["adicionados"] == 2,
               "importacao adiciona as linhas validas (2 de 4)")
        checar(dados["comErro"] == 2, "importacao reporta as 2 linhas com erro")
        motivos = " | ".join(e["motivo"] for e in dados["erros"])
        checar("incompleto" in motivos and "matricula" in motivos,
               "erros trazem linha e motivo: %s" % motivos)

        prof_importacao = professor_a.upload(
            "/api/professor/turmas/%d/alunos/importar" % turma_a["id"],
            "alunos.csv",
            "nome;matricula\nPedro Henrique Alves;2026006\n".encode("utf-8"),
        )
        checar(prof_importacao.status_code == 201
               and prof_importacao.get_json()["adicionados"] == 1,
               "PROFESSOR tambem importa alunos na turma dele")

        checar(professor_a.upload(
            "/api/professor/turmas/%d/alunos/importar" % turma_a2["id"],
            "alunos.csv", "nome\nZe da Silva\n".encode("utf-8"),
        ).status_code == 404, "professor nao importa em turma nao vinculada")

        modelo = coord_a.get(
            "/api/coordenacao/turmas/%d/alunos/modelo-planilha" % turma_a["id"]
        )
        checar(modelo.status_code == 200 and len(modelo.data) > 1000,
               "modelo de planilha de alunos e gerado")

        # ---------------------------------------------------------
        print("\n[7] Notas")
        alunos_turma = professor_a.get(
            "/api/professor/turmas/%d/alunos" % turma_a["id"]
        ).get_json()
        checar(len(alunos_turma) == 4, "turma tem os 4 alunos importados/cadastrados")

        lancamento = professor_a.post(
            "/api/atividades/%d/notas" % atividade["id"],
            {"notas": [
                {"aluno_id": alunos_turma[0]["id"], "valor": 9.5},
                {"aluno_id": alunos_turma[1]["id"], "valor": 3.0},
            ]},
        )
        checar(lancamento.status_code == 201
               and lancamento.get_json()["lancadas"] == 2,
               "professor lanca notas")

        listagem = professor_a.get(
            "/api/atividades/%d/notas" % atividade["id"]
        ).get_json()
        checar(len(listagem["notas"]) == 4,
               "listagem de notas traz a turma inteira, com e sem nota")

        estatisticas = professor_a.get(
            "/api/professor/alunos/%d/estatisticas" % alunos_turma[0]["id"]
        )
        checar(estatisticas.status_code == 200
               and estatisticas.get_json()["media"] == 9.5,
               "estatisticas do aluno trazem a media")

        painel = professor_a.get("/api/professor/dashboard").get_json()
        checar(painel["totalTurmas"] == 1 and painel["totalAlunos"] == 4,
               "dashboard do professor conta so as turmas dele")
        em_risco = [a["nome"] for a in painel["alunosEmRisco"]]
        checar(len(em_risco) == 1,
               "dashboard aponta o aluno abaixo da nota minima: %s" % em_risco)

        checar(coord_b.get(
            "/api/professor/dashboard"
        ).status_code == 403, "coordenacao nao acessa o dashboard do professor")

        # ---------------------------------------------------------
        print("\n[8] Busca e resumo, filtrados por escola")
        busca_b = coord_b.get(
            "/api/activities/buscar?termo=Prova&ordenar_por=title&direcao=ASC"
        ).get_json()
        checar(busca_b == [], "escola B nao encontra a atividade da escola A")

        busca_a = coord_a.get(
            "/api/activities/buscar?termo=Prova&ordenar_por=title&direcao=ASC"
        ).get_json()
        checar(len(busca_a) == 1, "escola A encontra a propria atividade")

        resumo = coord_a.get("/api/dashboard/resumo").get_json()
        checar(resumo["total_turmas"] == 2 and resumo["total_atividades"] == 1,
               "resumo conta so a escola A: %s" % resumo)

        print("\nLimpando os dados de teste...")
        limpar()

    print("\n" + "=" * 62)
    print("%d verificacoes, %d falha(s)" % (_passos[0], len(falhas)))
    if falhas:
        print("SMOKE API FALHOU:")
        for f in falhas:
            print("  - %s" % f)
        sys.exit(1)
    print("SMOKE API OK")


if __name__ == "__main__":
    main()

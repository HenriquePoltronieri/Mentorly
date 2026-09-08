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
from database.connection import execute, query_all, query_one

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
    """Cadastra coordenacao, turma, professor e a configuracao academica.

    A etapa e o criterio nascem aqui porque, desde o Marco 1, atividade sem
    eles nao existe: o backend recusa. Cada escola recebe os seus, e sao
    justamente esses ids que os testes de isolamento tentam cruzar.
    """
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

    # Configuracao academica: duas etapas, para dar como testar criterio
    # apontando para a etapa errada.
    etapa = coord.post("/api/config/etapas", {
        "nome": "1 Etapa", "ordem": 1, "ano_letivo": 2026,
    }).get_json()
    coord.post("/api/config/etapas/%d/notas" % etapa["id"], {
        "nota_minima": 6, "nota_maxima": 10,
    })
    etapa2 = coord.post("/api/config/etapas", {
        "nome": "2 Etapa", "ordem": 2, "ano_letivo": 2026,
    }).get_json()

    # peso 100: cada etapa aqui tem UM criterio so, entao 100% e o peso
    # valido natural (Marco 2 exige que os pesos ativos de uma etapa somem
    # 100 para ela poder ser calculada - ver services/academico/calculo.py).
    criterio = coord.post(
        "/api/config/criterios/etapa/%d" % etapa["id"],
        {"nome": "Provas", "peso": 100},
    ).get_json()
    criterio2 = coord.post(
        "/api/config/criterios/etapa/%d" % etapa2["id"],
        {"nome": "Trabalho", "peso": 100},
    ).get_json()

    config = {
        "etapa": etapa, "etapa2": etapa2,
        "criterio": criterio, "criterio2": criterio2,
    }
    return coord, turma, professor, config


def main():
    aplicacao = app_module.create_app()
    aplicacao.config["TESTING"] = True

    with aplicacao.test_client() as cliente_flask:
        print("Limpando restos de execucoes anteriores...")
        limpar()

        # ---------------------------------------------------------
        print("\n[1] Autenticacao")
        coord_a, turma_a, prof_a, config_a = montar_escola(cliente_flask, "A")
        coord_b, turma_b, prof_b, config_b = montar_escola(cliente_flask, "B")
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
            "etapa_id": config_a["etapa"]["id"],
            "criterio_id": config_a["criterio"]["id"],
            "nota_maxima": 10,
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
            "etapa_id": config_a["etapa"]["id"],
            "criterio_id": config_a["criterio"]["id"],
            "nota_maxima": 10,
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
        checar(len(etapas) == 2 and etapa["id"] == config_a["etapa"]["id"],
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
        checar(isinstance(painel["alunosEmRisco"], list),
               "dashboard responde alunosEmRisco sem quebrar (escola com "
               "duas etapas ativas - qual e 'a atual' e ambiguo sem "
               "datas; a cobertura de 'aluno em risco' de verdade fica "
               "na secao [10], com uma unica etapa, sem ambiguidade)")

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

        # ---------------------------------------------------------
        print("\n[9] Marco 1 - avaliacao academica (etapa, criterio, valor)")

        etapa_a = config_a["etapa"]["id"]
        etapa_a2 = config_a["etapa2"]["id"]
        criterio_a = config_a["criterio"]["id"]
        criterio_a2 = config_a["criterio2"]["id"]
        etapa_b = config_b["etapa"]["id"]
        criterio_b = config_b["criterio"]["id"]

        def criar(**extra):
            """Atividade valida da escola A; cada teste troca um campo so."""
            corpo = {
                "title": "Atividade de teste",
                "class_id": turma_a["id"],
                "etapa_id": etapa_a,
                "criterio_id": criterio_a,
                "nota_maxima": 20,
            }
            corpo.update(extra)
            return professor_a.post("/api/activities", corpo)

        # TESTE 1 - criacao valida
        valida = criar(title="Prova de Matematica", nota_maxima=20)
        checar(valida.status_code == 201, "T1: atividade valida responde 201")
        criada = valida.get_json()
        checar(criada["etapa_id"] == etapa_a
               and criada["criterio_id"] == criterio_a
               and criada["nota_maxima"] == 20.0,
               "T1: etapa, criterio e valor voltam persistidos")
        # A secao [5] ja renomeou a etapa ("1 Etapa" -> "1 Etapa renomeada")
        # para testar o upsert, entao o nome exato nao e o que importa aqui -
        # e que a atividade reflita o nome ATUAL da etapa/criterio, e nao um
        # nome congelado no momento da criacao.
        checar(bool(criada["etapa_nome"]) and criada["criterio_nome"] == "Provas",
               "T1: a resposta traz o nome da etapa e do criterio")

        # TESTES 2 e 3 - valor invalido
        checar(criar(nota_maxima=0).status_code == 400,
               "T2: nota_maxima = 0 responde 400")
        checar(criar(nota_maxima=-5).status_code == 400,
               "T3: nota_maxima = -5 responde 400")
        checar(criar(nota_maxima="vinte").status_code == 400,
               "T3b: nota_maxima em texto responde 400")
        checar(criar(nota_maxima="").status_code == 400,
               "T3c: nota_maxima vazia responde 400")

        # TESTES 4 e 5 - etapa/criterio de outra escola
        checar(criar(etapa_id=etapa_b).status_code == 404,
               "T4: etapa da escola B responde 404")
        checar(criar(criterio_id=criterio_b).status_code == 404,
               "T5: criterio da escola B responde 404")
        checar(criar(etapa_id=etapa_b, criterio_id=criterio_b).status_code == 404,
               "T5b: etapa E criterio da escola B respondem 404")
        checar(criar(criterio_id=criterio_a2).status_code == 404,
               "T5c: criterio de outra etapa da propria escola responde 404")
        checar(criar(etapa_id=None, criterio_id=None).status_code == 400,
               "T5d: atividade sem etapa e sem criterio responde 400")

        # TESTE 6 - turma de outro professor / de outra escola
        checar(criar(class_id=turma_a2["id"]).status_code == 404,
               "T6: turma nao vinculada ao professor responde 404")
        checar(professor_a.post("/api/activities", {
            "title": "Invasao", "class_id": turma_b["id"],
            "etapa_id": etapa_b, "criterio_id": criterio_b, "nota_maxima": 10,
        }).status_code == 404, "T6b: turma de outra escola responde 404")

        # TESTE 7 - Coordenacao nao cria atividade
        checar(coord_a.post("/api/activities", {
            "title": "Da coordenacao", "class_id": turma_a["id"],
            "etapa_id": etapa_a, "criterio_id": criterio_a, "nota_maxima": 20,
        }).status_code == 403, "T7: COORDENACAO recebe 403 em POST /activities")

        # TESTES 8, 9 e 10 - lancamento respeita o valor da atividade
        nova = criada["id"]
        aluno_da_turma = alunos_turma[0]["id"]

        ok = professor_a.post("/api/atividades/%d/notas" % nova, {
            "notas": [{"aluno_id": aluno_da_turma, "valor": 18}]})
        checar(ok.status_code == 201 and ok.get_json()["lancadas"] == 1,
               "T8: nota 18 em atividade de 20 e aceita")

        checar(professor_a.post("/api/atividades/%d/notas" % nova, {
            "notas": [{"aluno_id": aluno_da_turma, "valor": 21}]
        }).status_code == 400, "T9: nota 21 em atividade de 20 responde 400")
        checar(professor_a.post("/api/atividades/%d/notas" % nova, {
            "notas": [{"aluno_id": aluno_da_turma, "valor": 20.1}]
        }).status_code == 400, "T9b: nota 20.1 responde 400")
        checar(professor_a.post("/api/atividades/%d/notas" % nova, {
            "notas": [{"aluno_id": aluno_da_turma, "valor": 20}]
        }).status_code == 201, "T9c: nota exatamente 20 e aceita")
        checar(professor_a.post("/api/atividades/%d/notas" % nova, {
            "notas": [{"aluno_id": aluno_da_turma, "valor": -1}]
        }).status_code == 400, "T10: nota -1 responde 400")

        # TESTE 11 - aluno que nao pertence a turma da atividade
        aluno_de_fora = coord_a.post(
            "/api/coordenacao/turmas/%d/alunos" % turma_a2["id"],
            {"nome": "Fora Da Turma"},
        ).get_json()
        checar(professor_a.post("/api/atividades/%d/notas" % nova, {
            "notas": [{"aluno_id": aluno_de_fora["id"], "valor": 10}]
        }).status_code == 404, "T11: aluno de outra turma responde 404")

        aluno_b = coord_b.post(
            "/api/coordenacao/turmas/%d/alunos" % turma_b["id"],
            {"nome": "Aluno Da Escola B"},
        ).get_json()
        checar(professor_a.post("/api/atividades/%d/notas" % nova, {
            "notas": [{"aluno_id": aluno_b["id"], "valor": 10}]
        }).status_code == 404, "T11b: aluno de outra escola responde 404")

        # A recusa e total: nenhuma nota do lote entra.
        notas_apos = professor_a.get(
            "/api/atividades/%d/notas" % nova).get_json()["notas"]
        com_nota = [n for n in notas_apos if n["valor"] is not None]
        checar(len(com_nota) == 1, "T11c: lote recusado nao grava nada")

        # TESTE 12 - persistencia depois de reler
        outra = criar(title="Trabalho de Historia", etapa_id=etapa_a2,
                      criterio_id=criterio_a2, nota_maxima=15).get_json()
        relida = professor_a.get("/api/activities/%d" % outra["id"]).get_json()
        checar(relida["etapa_id"] == etapa_a2
               and relida["criterio_id"] == criterio_a2
               and relida["nota_maxima"] == 15.0,
               "T12: etapa, criterio e valor sobrevivem ao reload")

        # Edicao: revalida tudo, e protege nota ja lancada
        checar(professor_a.put("/api/activities/%d" % nova, {
            "etapa_id": etapa_b, "criterio_id": criterio_b,
        }).status_code == 404, "T13: editar com etapa de outra escola da 404")

        checar(professor_a.put("/api/activities/%d" % nova, {
            "nota_maxima": 0}).status_code == 400,
               "T14: editar para valor 0 responde 400")

        reduzir = professor_a.put("/api/activities/%d" % nova,
                                  {"nota_maxima": 15})
        checar(reduzir.status_code == 400
               and "20" in reduzir.get_json()["error"],
               "T15: reduzir o valor abaixo de nota ja lancada responde 400")

        checar(professor_a.put("/api/activities/%d" % nova,
                               {"nota_maxima": 25}).status_code == 200,
               "T16: aumentar o valor e permitido")

        checar(coord_b.get("/api/activities/%d" % nova).status_code == 404,
               "T17: escola B nao acessa a atividade da escola A")

        # ---------------------------------------------------------
        print("\n[10] Marco 2 - calculo academico por etapa e criterios")

        def ativar_professor(prof_dict, senha="senha123"):
            """Repete o fluxo de convite ja validado em [3], para um
            professor novo. Devolve o Cliente ja logado."""
            cliente_flask.post("/api/auth/criar-senha-professor", json={
                "email": prof_dict["email"], "senha": senha,
                "token": prof_dict["conviteToken"],
            })
            login = cliente_flask.post("/api/auth/login-professor", json={
                "email": prof_dict["email"], "senha": senha,
            })
            cli = Cliente(cliente_flask)
            cli.token = login.get_json()["token"]
            return cli

        def criar_etapa(cliente, nome, ordem, nota_minima=None, nota_maxima=None):
            etapa = cliente.post("/api/config/etapas", {
                "nome": nome, "ordem": ordem, "ano_letivo": 2026,
            }).get_json()
            if nota_minima is not None:
                cliente.post("/api/config/etapas/%d/notas" % etapa["id"], {
                    "nota_minima": nota_minima, "nota_maxima": nota_maxima,
                })
            return etapa

        def criar_criterio(cliente, etapa_id, nome, peso):
            return cliente.post(
                "/api/config/criterios/etapa/%d" % etapa_id,
                {"nome": nome, "peso": peso},
            ).get_json()

        def criar_atividade(cliente, turma_id, etapa_id, criterio_id,
                            nota_maxima, titulo="Atividade"):
            return cliente.post("/api/activities", {
                "title": titulo, "class_id": turma_id,
                "etapa_id": etapa_id, "criterio_id": criterio_id,
                "nota_maxima": nota_maxima,
            }).get_json()

        def lancar(cliente, atividade_id, aluno_id, valor):
            return cliente.post("/api/atividades/%d/notas" % atividade_id, {
                "notas": [{"aluno_id": aluno_id, "valor": valor}]})

        def criterios_por_nome(etapa_calculada):
            return {c["criterio"]: c for c in etapa_calculada["criterios"]}

        def etapa_por_id(dados_estatisticas, etapa_id):
            for etapa in dados_estatisticas["etapas"]:
                if etapa["etapa_id"] == etapa_id:
                    return etapa
            return None

        def estatisticas_de(cliente, aluno_id):
            resposta = cliente.get(
                "/api/professor/alunos/%d/estatisticas" % aluno_id)
            checar(resposta.status_code == 200,
                   "GET estatisticas do aluno %s responde 200" % aluno_id)
            return resposta.get_json()

        # Turma e alunos dedicados, isolados dos dados usados nas secoes
        # anteriores (que ja tem atividades sem nota "sujando" os
        # criterios de etapa_a/etapa_a2).
        turma_c = coord_a.post(
            "/api/classes", {"name": "Turma Calculo"}
        ).get_json()
        coord_a.post(
            "/api/coordenacao/professores/%d/turmas" % prof_a["id"],
            {"turma_ids": [turma_a["id"], turma_c["id"]]},
        )

        aluno_joao = coord_a.post(
            "/api/coordenacao/turmas/%d/alunos" % turma_c["id"],
            {"nome": "Joao Calculo Silva"},
        ).get_json()
        aluno_zero = coord_a.post(
            "/api/coordenacao/turmas/%d/alunos" % turma_c["id"],
            {"nome": "Zero Notas Real"},
        ).get_json()
        aluno_parcial = coord_a.post(
            "/api/coordenacao/turmas/%d/alunos" % turma_c["id"],
            {"nome": "Parcial Sem Todas As Notas"},
        ).get_json()
        aluno_sem_nota = coord_a.post(
            "/api/coordenacao/turmas/%d/alunos" % turma_c["id"],
            {"nome": "Nunca Avaliado Ainda"},
        ).get_json()

        # --- T1/T3/T5/T6: tres criterios ponderados (60/30/10), o exemplo
        # do pedido: Provas 18/20+16/20, Trabalho 9/10, Participacao 8/10.
        etapa_c = criar_etapa(coord_a, "Etapa Calculo", 50, 15, 25)
        crit_provas = criar_criterio(coord_a, etapa_c["id"], "Provas", 60)
        crit_trabalhos = criar_criterio(coord_a, etapa_c["id"], "Trabalhos", 30)
        crit_participacao = criar_criterio(coord_a, etapa_c["id"], "Participacao", 10)

        prova1 = criar_atividade(professor_a, turma_c["id"], etapa_c["id"],
                                 crit_provas["id"], 20, "Prova 1")
        prova2 = criar_atividade(professor_a, turma_c["id"], etapa_c["id"],
                                 crit_provas["id"], 20, "Prova 2")
        trabalho1 = criar_atividade(professor_a, turma_c["id"], etapa_c["id"],
                                    crit_trabalhos["id"], 10, "Trabalho 1")
        participacao1 = criar_atividade(professor_a, turma_c["id"], etapa_c["id"],
                                        crit_participacao["id"], 10, "Participacao")

        lancar(professor_a, prova1["id"], aluno_joao["id"], 18)
        lancar(professor_a, prova2["id"], aluno_joao["id"], 16)
        lancar(professor_a, trabalho1["id"], aluno_joao["id"], 9)
        lancar(professor_a, participacao1["id"], aluno_joao["id"], 8)

        # T5: nota zero e uma nota REAL, participa do calculo como zero.
        lancar(professor_a, prova1["id"], aluno_zero["id"], 0)
        lancar(professor_a, prova2["id"], aluno_zero["id"], 0)
        lancar(professor_a, trabalho1["id"], aluno_zero["id"], 0)
        lancar(professor_a, participacao1["id"], aluno_zero["id"], 0)

        # T6: nota ausente. So a Prova 1 foi lancada - o criterio Provas
        # fica incompleto (falta a Prova 2), entao a etapa nao pode ser
        # calculada ainda, e isso NAO pode dar erro nem 500.
        lancar(professor_a, prova1["id"], aluno_parcial["id"], 18)

        est_joao = estatisticas_de(professor_a, aluno_joao["id"])
        calc_joao = etapa_por_id(est_joao, etapa_c["id"])
        crit_joao = criterios_por_nome(calc_joao)

        checar(crit_joao["Provas"]["pontos_obtidos"] == 34
               and crit_joao["Provas"]["pontos_possiveis"] == 40
               and crit_joao["Provas"]["desempenho_percentual"] == 85.0,
               "T1: criterio Provas = 34/40 = 85%")
        checar(crit_joao["Trabalhos"]["desempenho_percentual"] == 90.0
               and crit_joao["Participacao"]["desempenho_percentual"] == 80.0,
               "T3: Trabalhos 90%% e Participacao 80%% calculados")
        checar(crit_joao["Provas"]["contribuicao"] == 51.0
               and crit_joao["Trabalhos"]["contribuicao"] == 27.0
               and crit_joao["Participacao"]["contribuicao"] == 8.0,
               "T3: contribuicao de cada criterio (peso x desempenho)")
        checar(calc_joao["completo"] and calc_joao["percentual"] == 86.0,
               "T3: soma das contribuicoes = 86%")
        checar(calc_joao["nota_calculada"] == 21.5,
               "T3: nota da etapa = 0,86 x 25 = 21,5")
        checar(calc_joao["situacao"] == "adequado",
               "T3: 21,5 >= nota minima 15 -> adequado")

        est_zero = estatisticas_de(professor_a, aluno_zero["id"])
        calc_zero = etapa_por_id(est_zero, etapa_c["id"])
        checar(calc_zero["completo"] and calc_zero["nota_calculada"] == 0.0,
               "T5: nota 0 e real (avaliado, tirou zero) - entra no calculo")
        checar(calc_zero["situacao"] == "abaixo_do_minimo",
               "T5: 0 < nota minima 15 -> abaixo_do_minimo")

        est_parcial = estatisticas_de(professor_a, aluno_parcial["id"])
        calc_parcial = etapa_por_id(est_parcial, etapa_c["id"])
        crit_parcial = criterios_por_nome(calc_parcial)
        checar(crit_parcial["Provas"]["completo"] is False,
               "T6: criterio com 1 de 2 atividades sem nota fica incompleto")
        checar(calc_parcial["completo"] is False
               and calc_parcial["situacao"] == "em_andamento"
               and calc_parcial["nota_calculada"] is None,
               "T6: nota ausente nao vira zero - etapa fica em_andamento")

        est_sem_nota = estatisticas_de(professor_a, aluno_sem_nota["id"])
        calc_sem_nota = etapa_por_id(est_sem_nota, etapa_c["id"])
        checar(calc_sem_nota["situacao"] == "em_andamento"
               and calc_sem_nota["nota_calculada"] is None,
               "T15: aluno sem nenhuma nota fica em_andamento, nao abaixo_do_minimo")

        # --- T2: dois criterios (Prova 70% + Trabalho 30%).
        etapa_dois = criar_etapa(coord_a, "Etapa Dois Criterios", 51, 6, 10)
        crit_prova_2c = criar_criterio(coord_a, etapa_dois["id"], "Prova", 70)
        crit_trab_2c = criar_criterio(coord_a, etapa_dois["id"], "Trabalho", 30)
        prova_2c = criar_atividade(professor_a, turma_c["id"], etapa_dois["id"],
                                   crit_prova_2c["id"], 10, "Prova")
        trab_2c = criar_atividade(professor_a, turma_c["id"], etapa_dois["id"],
                                  crit_trab_2c["id"], 10, "Trabalho")
        lancar(professor_a, prova_2c["id"], aluno_joao["id"], 8)
        lancar(professor_a, trab_2c["id"], aluno_joao["id"], 10)

        est_joao = estatisticas_de(professor_a, aluno_joao["id"])
        calc_dois = etapa_por_id(est_joao, etapa_dois["id"])
        checar(calc_dois["percentual"] == 86.0 and calc_dois["nota_calculada"] == 8.6,
               "T2: 0,8x0,7 + 1,0x0,3 = 0,86 (nota_maxima 10 -> 8,6)")

        # --- T4: pesos que nao somam 100 (60 + 20 = 80).
        etapa_invalida = criar_etapa(coord_a, "Etapa Peso Invalido", 52, 6, 10)
        crit_inv_a = criar_criterio(coord_a, etapa_invalida["id"], "Prova A", 60)
        criar_criterio(coord_a, etapa_invalida["id"], "Prova B", 20)
        ativ_invalida = criar_atividade(professor_a, turma_c["id"],
                                        etapa_invalida["id"], crit_inv_a["id"],
                                        10, "Prova A")
        lancar(professor_a, ativ_invalida["id"], aluno_joao["id"], 10)

        est_joao = estatisticas_de(professor_a, aluno_joao["id"])
        calc_invalida = etapa_por_id(est_joao, etapa_invalida["id"])
        checar(calc_invalida["situacao"] == "configuracao_invalida"
               and calc_invalida["nota_calculada"] is None,
               "T4: pesos somando 80%% nao sao calculados silenciosamente")
        checar(bool(calc_invalida.get("mensagem")),
               "T4: a resposta explica o motivo (%s)" % calc_invalida.get("mensagem"))

        etapas_config_a = coord_a.get(
            "/api/config/etapas?ano_letivo=2026"
        ).get_json()
        etapa_invalida_cfg = next(
            e for e in etapas_config_a if e["id"] == etapa_invalida["id"]
        )
        checar(etapa_invalida_cfg["pesoValido"] is False,
               "T4b: GET /config/etapas ja sinaliza pesoValido=false pra Coordenacao")

        # --- T7: criterio configurado mas sem nenhuma atividade ainda.
        etapa_orfa = criar_etapa(coord_a, "Etapa Criterio Orfao", 53, 6, 10)
        criar_criterio(coord_a, etapa_orfa["id"], "Prova Futura", 100)

        est_joao = estatisticas_de(professor_a, aluno_joao["id"])
        calc_orfa = etapa_por_id(est_joao, etapa_orfa["id"])
        checar(calc_orfa["situacao"] == "em_andamento"
               and calc_orfa["criterios"][0]["tem_atividade"] is False,
               "T7: criterio sem atividade nao quebra (sem divisao por zero)")

        # --- T8: atividade legada (sem etapa/criterio). Inserida direto no
        # banco porque a API ja exige etapa/criterio em atividade nova
        # desde o Marco 1 - nao ha como criar uma assim pela API de proposito.
        coordenacao_id_a = query_one(
            "SELECT coordenacao_id FROM turma WHERE id = %s", (turma_c["id"],)
        )["coordenacao_id"]
        execute(
            "INSERT INTO atividade "
            "(coordenacao_id, turma_id, professor_id, titulo) "
            "VALUES (%s, %s, %s, %s)",
            (coordenacao_id_a, turma_c["id"], prof_a["id"], "Atividade Legada"),
        )
        est_joao = estatisticas_de(professor_a, aluno_joao["id"])
        calc_joao_depois = etapa_por_id(est_joao, etapa_c["id"])
        checar(calc_joao_depois["nota_calculada"] == 21.5,
               "T8: atividade legada nao entra no calculo (etapa C continua 21,5)")

        # --- T9: etapa correta - abaixo do minimo na Etapa Baixa, mas
        # acima do minimo na Etapa Calculo, ambas com nota_minima=15.
        etapa_baixa = criar_etapa(coord_a, "Etapa Baixa", 54, 15, 25)
        crit_baixa = criar_criterio(coord_a, etapa_baixa["id"], "Prova", 100)
        ativ_baixa = criar_atividade(professor_a, turma_c["id"], etapa_baixa["id"],
                                     crit_baixa["id"], 25, "Prova Unica")
        lancar(professor_a, ativ_baixa["id"], aluno_joao["id"], 5)

        est_joao = estatisticas_de(professor_a, aluno_joao["id"])
        calc_c_de_novo = etapa_por_id(est_joao, etapa_c["id"])
        calc_baixa = etapa_por_id(est_joao, etapa_baixa["id"])
        checar(calc_c_de_novo["situacao"] == "adequado"
               and calc_baixa["situacao"] == "abaixo_do_minimo",
               "T9: cada etapa usa a propria nota minima, sem misturar "
               "(Calculo=%s, Baixa=%s)"
               % (calc_c_de_novo["situacao"], calc_baixa["situacao"]))

        # --- T10: isolamento entre escolas.
        professor_b = ativar_professor(prof_b)
        checar(professor_b.get(
            "/api/professor/alunos/%d/estatisticas" % aluno_joao["id"]
        ).status_code == 404,
               "T10: professor de outra escola nao acessa o aluno")

        # --- T11: professor da MESMA escola, mas sem vinculo com a turma.
        prof_a2 = coord_a.post("/api/coordenacao/professores", {
            "nome": "Professor A Sem Vinculo",
            "email": "prof.a2.calculo.%s" % SUFIXO,
            "disciplina": "Historia",
        }).get_json()
        professor_a2 = ativar_professor(prof_a2)
        checar(professor_a2.get(
            "/api/professor/alunos/%d/estatisticas" % aluno_joao["id"]
        ).status_code == 404,
               "T11: professor da mesma escola sem vinculo a turma nao acessa")

        # --- T12: arredondamento so na saida, nao durante o calculo.
        # 3/9 = 0,3333... - se arredondasse cedo o resultado final mudaria.
        etapa_arred = criar_etapa(coord_a, "Etapa Arredondamento", 55, 6, 25)
        crit_arred = criar_criterio(coord_a, etapa_arred["id"], "Prova", 100)
        a1 = criar_atividade(professor_a, turma_c["id"], etapa_arred["id"],
                             crit_arred["id"], 3, "P1")
        a2 = criar_atividade(professor_a, turma_c["id"], etapa_arred["id"],
                             crit_arred["id"], 3, "P2")
        a3 = criar_atividade(professor_a, turma_c["id"], etapa_arred["id"],
                             crit_arred["id"], 3, "P3")
        lancar(professor_a, a1["id"], aluno_joao["id"], 1)
        lancar(professor_a, a2["id"], aluno_joao["id"], 1)
        lancar(professor_a, a3["id"], aluno_joao["id"], 1)

        est_joao = estatisticas_de(professor_a, aluno_joao["id"])
        calc_arred = etapa_por_id(est_joao, etapa_arred["id"])
        checar(calc_arred["criterios"][0]["desempenho_percentual"] == 33.33,
               "T12: 3/9 arredondado pra 33,33%% so na saida")
        checar(calc_arred["nota_calculada"] == 8.33,
               "T12: nota da etapa = 0,3333... x 25 = 8,33 (nao 8,25 nem 8,3)")

        # --- T13/T14/T15: dashboard, aluno em risco, isolamento entre
        # professores. Ordem 56 e a maior da escola A - vira "etapa atual".
        etapa_risco = criar_etapa(coord_a, "Etapa Risco Dashboard", 56, 15, 25)
        crit_risco = criar_criterio(coord_a, etapa_risco["id"], "Prova", 100)
        ativ_risco = criar_atividade(professor_a, turma_c["id"], etapa_risco["id"],
                                     crit_risco["id"], 25, "Prova Risco")

        aluno_14 = coord_a.post(
            "/api/coordenacao/turmas/%d/alunos" % turma_c["id"],
            {"nome": "Catorze Abaixo Minimo"},
        ).get_json()
        aluno_16 = coord_a.post(
            "/api/coordenacao/turmas/%d/alunos" % turma_c["id"],
            {"nome": "Dezesseis Adequado"},
        ).get_json()
        lancar(professor_a, ativ_risco["id"], aluno_14["id"], 14)
        lancar(professor_a, ativ_risco["id"], aluno_16["id"], 16)
        # aluno_joao/zero/parcial/sem_nota nao tem nota nesta atividade:
        # ficam em_andamento na Etapa Risco, entao nao contam como risco.

        painel_a = professor_a.get("/api/professor/dashboard").get_json()
        nomes_risco_a = [a["nome"] for a in painel_a["alunosEmRisco"]]
        checar(aluno_14["nome"] in nomes_risco_a,
               "T14: nota 14 (< minimo 15) aparece em alunosEmRisco")
        checar(aluno_16["nome"] not in nomes_risco_a,
               "T14: nota 16 (>= minimo 15) NAO aparece em alunosEmRisco")
        checar(aluno_sem_nota["nome"] not in nomes_risco_a,
               "T15: aluno sem nenhuma nota nesta etapa nao aparece como risco")

        coord_b.post(
            "/api/coordenacao/professores/%d/turmas" % prof_b["id"],
            {"turma_ids": [turma_b["id"]]},
        )
        etapa_b_risco = criar_etapa(coord_b, "Etapa Risco B", 50, 15, 25)
        crit_b_risco = criar_criterio(coord_b, etapa_b_risco["id"], "Prova", 100)
        ativ_b_risco = criar_atividade(professor_b, turma_b["id"],
                                       etapa_b_risco["id"], crit_b_risco["id"],
                                       25, "Prova B")
        aluno_b_risco = coord_b.post(
            "/api/coordenacao/turmas/%d/alunos" % turma_b["id"],
            {"nome": "Risco Escola B"},
        ).get_json()
        lancar(professor_b, ativ_b_risco["id"], aluno_b_risco["id"], 5)

        painel_b = professor_b.get("/api/professor/dashboard").get_json()
        nomes_risco_b = [a["nome"] for a in painel_b["alunosEmRisco"]]
        checar("Risco Escola B" in nomes_risco_b,
               "T13: dashboard da escola B mostra o proprio aluno em risco")

        painel_a_de_novo = professor_a.get("/api/professor/dashboard").get_json()
        nomes_a_de_novo = [a["nome"] for a in painel_a_de_novo["alunosEmRisco"]]
        checar("Risco Escola B" not in nomes_a_de_novo,
               "T13: dashboard da escola A nao ve o aluno em risco da escola B")

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

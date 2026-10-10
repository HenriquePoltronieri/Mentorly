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
import json
import os
import sys
from unittest.mock import patch

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# O smoke precisa do codigo e do convite na resposta (nao ha SMTP aqui): liga o
# interruptor de desenvolvimento ANTES de importar a config. O padrao real e
# desligado; a secao [M-06] testa os dois lados.
os.environ["DEV_EXPOSE_AUTH_CODES"] = "true"

import app as app_module
from database.connection import execute, insert, query_all, query_one

SUFIXO = "smoke-api@mentorly.local"

# Ano letivo dos testes. Fixo de proposito: antes do Marco 6 os testes so
# passavam porque o relogio da maquina estava em 2026.
ANO = 2026

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
        execute("DELETE FROM ano_letivo WHERE coordenacao_id = %s", (cid,))
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

    # Marco 6: a escola cadastra o ano letivo atual antes de criar turma ou
    # etapa. O ano e fixo (ANO): nenhum teste depende do relogio da maquina.
    ano = coord.post("/api/config/anos-letivos", {"ano": ANO, "status": "atual"})
    assert ano.status_code == 201, ano.get_json()

    # A turma nasce SEM informar o ano: ela herda o ano atual da escola.
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
               and "notas" in reduzir.get_json()["error"].lower(),
               "T15: reduzir o valor de atividade com nota lancada responde 400")

        # M-03: com nota lancada o valor maximo fica congelado (antes, T16
        # permitia aumentar e o percentual mudava sem relancar a nota).
        checar(professor_a.put("/api/activities/%d" % nova,
                               {"nota_maxima": 25}).status_code == 400,
               "T16: aumentar o valor de atividade com nota lancada responde 400 (M-03)")

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

        # ---------------------------------------------------------
        print("\n[11] Marco 3 - boletim e fechamento de etapa")

        boletim_prof = professor_a.get(
            "/api/professor/turmas/%d/boletim" % turma_c["id"]
        )
        checar(boletim_prof.status_code == 200,
               "professor consulta o boletim da turma")
        boletim_dados = boletim_prof.get_json()
        boletim_joao = next(
            a for a in boletim_dados["alunos"] if a["aluno_id"] == aluno_joao["id"]
        )
        etapa_c_no_boletim = next(
            e for e in boletim_joao["etapas"] if e["etapa_id"] == etapa_c["id"]
        )
        checar(etapa_c_no_boletim["nota_calculada"] == 21.5,
               "boletim da turma usa o mesmo motor de calculo (21,5)")
        checar(etapa_c_no_boletim["fechada"] is False, "etapa comeca aberta")
        checar(etapa_c_no_boletim["atividades_avaliadas"] == 4
               and etapa_c_no_boletim["atividades_sem_nota"] == 0,
               "boletim conta atividades avaliadas/sem nota da etapa")

        checar(coord_a.get(
            "/api/coordenacao/turmas/%d/boletim" % turma_c["id"]
        ).status_code == 200, "coordenacao tambem consulta o boletim")

        checar(professor_a.get(
            "/api/professor/turmas/%d/boletim" % turma_b["id"]
        ).status_code == 404, "professor nao ve boletim de turma de outra escola")
        checar(coord_b.get(
            "/api/coordenacao/turmas/%d/boletim" % turma_c["id"]
        ).status_code == 404, "coordenacao B nao ve boletim de turma da escola A")

        est_joao_antes = estatisticas_de(professor_a, aluno_joao["id"])
        checar(est_joao_antes["consolidado"]["situacao"] == "em_andamento",
               "consolidado sem nenhuma etapa fechada fica em_andamento")

        checar(professor_a.post(
            "/api/config/etapas/%d/fechar" % etapa_c["id"]
        ).status_code == 403, "PROFESSOR recebe 403 ao fechar etapa")

        fechar = coord_a.post("/api/config/etapas/%d/fechar" % etapa_c["id"])
        checar(fechar.status_code == 200 and fechar.get_json()["fechada"] is True,
               "COORDENACAO fecha a etapa")
        checar(coord_a.post(
            "/api/config/etapas/%d/fechar" % etapa_c["id"]
        ).status_code == 400, "fechar etapa ja fechada responde 400")

        checar(professor_a.post("/api/atividades/%d/notas" % prova1["id"], {
            "notas": [{"aluno_id": aluno_joao["id"], "valor": 5}]
        }).status_code == 400, "lancar nota em etapa fechada responde 400")

        checar(professor_a.post("/api/activities", {
            "title": "Nova na etapa fechada", "class_id": turma_c["id"],
            "etapa_id": etapa_c["id"], "criterio_id": crit_provas["id"],
            "nota_maxima": 10,
        }).status_code == 400, "criar atividade em etapa fechada responde 400")

        checar(professor_a.put("/api/activities/%d" % prova1["id"], {
            "nota_maxima": 30,
        }).status_code == 400, "editar atividade de etapa fechada responde 400")

        checar(professor_a.delete(
            "/api/activities/%d" % participacao1["id"]
        ).status_code == 400, "excluir atividade de etapa fechada responde 400")

        est_joao_fechada = estatisticas_de(professor_a, aluno_joao["id"])
        etapa_c_fechada = etapa_por_id(est_joao_fechada, etapa_c["id"])
        checar(etapa_c_fechada["fechada"] is True
               and etapa_c_fechada["nota_calculada"] == 21.5,
               "etapa fechada continua com o resultado ja calculado")
        checar(est_joao_fechada["consolidado"]["situacao"] == "adequado"
               and est_joao_fechada["consolidado"]["etapas_consideradas"] == 1,
               "consolidado passa a considerar a etapa fechada")

        checar(professor_a.post(
            "/api/config/etapas/%d/reabrir" % etapa_c["id"]
        ).status_code == 403, "PROFESSOR recebe 403 ao reabrir etapa")

        reabrir = coord_a.post("/api/config/etapas/%d/reabrir" % etapa_c["id"])
        checar(reabrir.status_code == 200 and reabrir.get_json()["fechada"] is False,
               "COORDENACAO reabre a etapa")
        checar(coord_a.post(
            "/api/config/etapas/%d/reabrir" % etapa_c["id"]
        ).status_code == 400, "reabrir etapa ja aberta responde 400")

        relancar = professor_a.post("/api/atividades/%d/notas" % prova1["id"], {
            "notas": [{"aluno_id": aluno_joao["id"], "valor": 20}]
        })
        checar(relancar.status_code == 201,
               "apos reabrir, professor altera nota normalmente")

        est_joao_reaberta = estatisticas_de(professor_a, aluno_joao["id"])
        etapa_c_reaberta = etapa_por_id(est_joao_reaberta, etapa_c["id"])
        checar(etapa_c_reaberta["nota_calculada"] != 21.5,
               "nota da etapa reflete a nota alterada apos a reabertura")

        checar(coord_a.post(
            "/api/config/etapas/%d/fechar" % etapa_b_risco["id"]
        ).status_code == 404, "fechar etapa de outra escola responde 404")

        # ---------------------------------------------------------
        print("\n[12] Marco 4 - A04: importacao de nota nao escolhe aluno errado")

        etapa_import = criar_etapa(coord_a, "Etapa Importacao Notas", 60, 6, 10)
        crit_import = criar_criterio(coord_a, etapa_import["id"], "Prova", 100)
        ativ_import = criar_atividade(professor_a, turma_c["id"], etapa_import["id"],
                                      crit_import["id"], 10, "Prova Importacao")

        aluno_unico = coord_a.post(
            "/api/coordenacao/turmas/%d/alunos" % turma_c["id"],
            {"nome": "Fulano Unico Nome", "matricula": "IMP-UNICO"},
        ).get_json()
        aluno_dup1 = coord_a.post(
            "/api/coordenacao/turmas/%d/alunos" % turma_c["id"],
            {"nome": "Fulano Duplicado Nome", "matricula": "IMP-DUP1"},
        ).get_json()
        aluno_dup2 = coord_a.post(
            "/api/coordenacao/turmas/%d/alunos" % turma_c["id"],
            {"nome": "Fulano Duplicado Nome", "matricula": "IMP-DUP2"},
        ).get_json()

        csv_import = (
            "aluno;matricula;nota\n"
            # a) nome unico, sem matricula -> resolve certo pelo nome
            "Fulano Unico Nome;;8\n"
            # b) nome duplicado, sem matricula -> nao pode adivinhar
            "Fulano Duplicado Nome;;7\n"
            # c) matricula correta identifica exatamente qual duplicado
            "Fulano Duplicado Nome;IMP-DUP2;9\n"
            # d) matricula errada NAO pode cair para o nome (que e valido)
            "Fulano Unico Nome;MATRICULA-NAO-EXISTE;6\n"
            # e) aluno que nao existe nesta turma, nem por nome nem matricula
            "Pessoa Que Nao Existe;;5\n"
        ).encode("utf-8")

        resultado_import = professor_a.upload(
            "/api/atividades/%d/notas/importar" % ativ_import["id"],
            "notas.csv", csv_import,
        )
        dados_import = resultado_import.get_json()
        checar(resultado_import.status_code == 201, "importacao de notas responde 201")
        checar(dados_import["adicionados"] == 2,
               "so as 2 linhas seguras (nome unico + matricula correta) entram: %s"
               % dados_import)
        checar(dados_import["comErro"] == 3,
               "as outras 3 linhas viram erro, nenhuma nota arriscada: %s" % dados_import)

        motivos_por_linha = {e["linha"]: e["motivo"] for e in dados_import["erros"]}
        checar("duplicado" in motivos_por_linha.get(3, ""),
               "nome duplicado sem matricula vira erro claro (linha 3): %s"
               % motivos_por_linha.get(3))
        checar("matricula" in motivos_por_linha.get(5, ""),
               "matricula errada vira erro e NAO cai para o nome (linha 5): %s"
               % motivos_por_linha.get(5))
        checar("nao encontrado" in motivos_por_linha.get(6, ""),
               "aluno inexistente vira erro (linha 6): %s" % motivos_por_linha.get(6))

        notas_import = professor_a.get(
            "/api/atividades/%d/notas" % ativ_import["id"]
        ).get_json()["notas"]
        por_aluno_import = {n["alunoId"]: n["valor"] for n in notas_import}
        checar(por_aluno_import.get(aluno_unico["id"]) == 8.0,
               "T-a: nome unico recebeu a nota certa (8)")
        checar(por_aluno_import.get(aluno_dup2["id"]) == 9.0,
               "T-c: matricula IMP-DUP2 recebeu a nota certa (9), nao o outro duplicado")
        checar(por_aluno_import.get(aluno_dup1["id"]) is None,
               "T-b: o OUTRO duplicado (IMP-DUP1) nao recebeu nota nenhuma por engano")

        # ---------------------------------------------------------
        print("\n[13] Marco 4 - aviso de alunos incompletos ao fechar etapa")

        # Turma propria, so com os 2 alunos deste teste - turma_c ja
        # acumulou muitos alunos nas secoes anteriores, e todos eles
        # tambem "veem" qualquer atividade nova criada nela (mesma turma =
        # mesma lista de atividades por criterio), o que contaria como
        # incompleto para todo mundo e junte esse teste especifico.
        turma_fechamento = coord_a.post(
            "/api/classes", {"name": "Turma Fechamento Incompletos"}
        ).get_json()
        coord_a.post(
            "/api/coordenacao/professores/%d/turmas" % prof_a["id"],
            {"turma_ids": [turma_a["id"], turma_c["id"], turma_fechamento["id"]]},
        )

        aluno_completo = coord_a.post(
            "/api/coordenacao/turmas/%d/alunos" % turma_fechamento["id"],
            {"nome": "Aluno Ficara Completo"},
        ).get_json()
        aluno_incompleto = coord_a.post(
            "/api/coordenacao/turmas/%d/alunos" % turma_fechamento["id"],
            {"nome": "Aluno Ficara Incompleto"},
        ).get_json()

        # Etapa onde TODOS os alunos com atividade ficam completos.
        etapa_zero_incompletos = criar_etapa(coord_a, "Etapa Zero Incompletos", 57, 6, 10)
        crit_zero_incompletos = criar_criterio(
            coord_a, etapa_zero_incompletos["id"], "Prova", 100
        )
        ativ_zero_incompletos = criar_atividade(
            professor_a, turma_fechamento["id"], etapa_zero_incompletos["id"],
            crit_zero_incompletos["id"], 10, "Prova Zero Incompletos",
        )
        # Os DOIS alunos da turma recebem nota aqui - ninguem fica pendente.
        lancar(professor_a, ativ_zero_incompletos["id"], aluno_completo["id"], 7)
        lancar(professor_a, ativ_zero_incompletos["id"], aluno_incompleto["id"], 9)

        fechar_zero = coord_a.post(
            "/api/config/etapas/%d/fechar" % etapa_zero_incompletos["id"]
        )
        checar(fechar_zero.status_code == 200, "fecha etapa sem alunos incompletos")
        checar(fechar_zero.get_json()["alunosIncompletos"] == 0,
               "resposta informa 0 alunos incompletos: %s" % fechar_zero.get_json())

        # Etapa onde um aluno fica com atividade sem nota no momento do
        # fechamento - o fechamento continua permitido mesmo assim.
        etapa_com_incompletos = criar_etapa(coord_a, "Etapa Com Incompletos", 58, 6, 10)
        crit_incompletos = criar_criterio(
            coord_a, etapa_com_incompletos["id"], "Prova", 100
        )
        ativ_incompletos = criar_atividade(
            professor_a, turma_fechamento["id"], etapa_com_incompletos["id"],
            crit_incompletos["id"], 10, "Prova Com Incompletos",
        )
        lancar(professor_a, ativ_incompletos["id"], aluno_completo["id"], 8)
        # aluno_incompleto NAO recebe nota nesta atividade de proposito.

        fechar_com_incompletos = coord_a.post(
            "/api/config/etapas/%d/fechar" % etapa_com_incompletos["id"]
        )
        checar(fechar_com_incompletos.status_code == 200,
               "etapa com aluno incompleto AINDA ASSIM pode ser fechada (nao bloqueia)")
        checar(fechar_com_incompletos.get_json()["alunosIncompletos"] == 1,
               "resposta informa exatamente 1 aluno incompleto: %s"
               % fechar_com_incompletos.get_json())
        checar(fechar_com_incompletos.get_json()["fechada"] is True,
               "etapa realmente fica fechada mesmo com aluno incompleto")

        # ---------------------------------------------------------
        print("\n[14] Marco 4 - edicao e exclusao de aluno")

        aluno_editar = coord_a.post(
            "/api/coordenacao/turmas/%d/alunos" % turma_a["id"],
            {"nome": "Nome Original Editavel", "matricula": "EDIT-001"},
        ).get_json()
        aluno_turma_nao_vinculada = coord_a.post(
            "/api/coordenacao/turmas/%d/alunos" % turma_a2["id"],
            {"nome": "Aluno Turma Nao Vinculada"},
        ).get_json()
        aluno_escola_b = coord_b.post(
            "/api/coordenacao/turmas/%d/alunos" % turma_b["id"],
            {"nome": "Aluno Da Escola B Edicao"},
        ).get_json()

        # 1. Coordenacao edita aluno da propria escola.
        editado = coord_a.put("/api/coordenacao/alunos/%d" % aluno_editar["id"], {
            "nome": "Nome Editado Pela Coordenacao",
        })
        checar(editado.status_code == 200
               and editado.get_json()["nome"] == "Nome Editado Pela Coordenacao",
               "1: Coordenacao edita aluno da propria escola")
        checar(editado.get_json()["matricula"] == "EDIT-001",
               "1b: campo nao enviado (matricula) preserva o valor atual")

        # 2. Coordenacao tenta editar aluno de outra escola.
        checar(coord_a.put(
            "/api/coordenacao/alunos/%d" % aluno_escola_b["id"],
            {"nome": "Tentativa De Invasao Aqui"},
        ).status_code == 404, "2: Coordenacao nao edita aluno de outra escola")

        # 3. Professor edita aluno de turma vinculada a ele.
        editado_prof = professor_a.put(
            "/api/professor/alunos/%d" % aluno_editar["id"],
            {"matricula": "EDIT-002"},
        )
        checar(editado_prof.status_code == 200
               and editado_prof.get_json()["matricula"] == "EDIT-002",
               "3: Professor edita aluno de turma vinculada a ele")

        # 4. Professor tenta editar aluno de turma NAO vinculada a ele
        #    (mesma escola - turma_a2 nunca foi vinculada a professor_a).
        checar(professor_a.put(
            "/api/professor/alunos/%d" % aluno_turma_nao_vinculada["id"],
            {"nome": "Tentativa Sem Vinculo Aqui"},
        ).status_code == 404,
               "4: Professor nao edita aluno de turma nao vinculada a ele")

        # Validacoes continuam as mesmas do cadastro (nao inventa regra nova).
        checar(coord_a.put(
            "/api/coordenacao/alunos/%d" % aluno_editar["id"], {"nome": "Sonome"}
        ).status_code == 400, "nome incompleto na edicao responde 400")

        outro_aluno = coord_a.post(
            "/api/coordenacao/turmas/%d/alunos" % turma_a["id"],
            {"nome": "Outro Aluno Matricula", "matricula": "EDIT-002"},
        )
        checar(outro_aluno.status_code == 400,
               "matricula duplicada ja e recusada no cadastro (contexto do teste de edicao)")

        # 5. Coordenacao exclui aluno permitido.
        excluido = coord_a.delete("/api/coordenacao/alunos/%d" % aluno_editar["id"])
        checar(excluido.status_code == 204, "5: Coordenacao exclui aluno da propria escola")

        alunos_turma_a_depois = coord_a.get(
            "/api/coordenacao/turmas/%d/alunos" % turma_a["id"]
        ).get_json()
        checar(all(a["id"] != aluno_editar["id"] for a in alunos_turma_a_depois),
               "5b: aluno excluido realmente some da listagem da turma")

        # 6. Usuario tenta excluir aluno de outra escola.
        checar(coord_a.delete(
            "/api/coordenacao/alunos/%d" % aluno_escola_b["id"]
        ).status_code == 404, "6: Coordenacao nao exclui aluno de outra escola")
        checar(coord_b.get(
            "/api/coordenacao/turmas/%d/alunos" % turma_b["id"]
        ).get_json() != [], "6b: aluno da escola B continua existindo depois da tentativa")

        # 7. Professor tenta excluir aluno de turma nao vinculada.
        checar(professor_a.delete(
            "/api/professor/alunos/%d" % aluno_turma_nao_vinculada["id"]
        ).status_code == 404,
               "7: Professor nao exclui aluno de turma nao vinculada a ele")
        checar(coord_a.get(
            "/api/coordenacao/turmas/%d/alunos" % turma_a2["id"]
        ).get_json() != [],
               "7b: aluno de turma nao vinculada continua existindo depois da tentativa")

        # ---------------------------------------------------------
        print("\n[15] Marco 5 - exclusao de nota")

        etapa_del_nota = criar_etapa(coord_a, "Etapa Exclusao Nota", 61, 6, 10)
        crit_del_nota = criar_criterio(coord_a, etapa_del_nota["id"], "Prova", 100)
        ativ_del_nota = criar_atividade(
            professor_a, turma_c["id"], etapa_del_nota["id"],
            crit_del_nota["id"], 10, "Prova Exclusao Nota",
        )
        lancar(professor_a, ativ_del_nota["id"], aluno_joao["id"], 7)

        def _nota_do_joao(atividade_id):
            notas = professor_a.get(
                "/api/atividades/%d/notas" % atividade_id
            ).get_json()["notas"]
            return next(
                (n for n in notas if n["alunoId"] == aluno_joao["id"]), None
            )

        nota_joao = _nota_do_joao(ativ_del_nota["id"])
        checar(nota_joao is not None and nota_joao["valor"] == 7.0,
               "nota lancada aparece na listagem antes de excluir")

        # --- Seguranca ---
        sem_token = Cliente(cliente_flask)
        checar(sem_token.delete(
            "/api/professor/notas/%d" % nota_joao["id"]
        ).status_code == 401, "excluir nota sem autenticacao responde 401")

        checar(coord_a.delete(
            "/api/professor/notas/%d" % nota_joao["id"]
        ).status_code == 403,
               "COORDENACAO recebe 403 na rota de excluir nota do Professor")

        checar(professor_b.delete(
            "/api/professor/notas/%d" % nota_joao["id"]
        ).status_code == 404, "professor de outra escola nao exclui a nota")

        checar(professor_a2.delete(
            "/api/professor/notas/%d" % nota_joao["id"]
        ).status_code == 404,
               "professor da mesma escola sem vinculo com a turma nao exclui a nota")

        checar(professor_a.delete(
            "/api/professor/notas/999999999"
        ).status_code == 404, "excluir nota inexistente responde 404")

        # A nota nao pode ter sido afetada por nenhuma das tentativas acima.
        checar(_nota_do_joao(ativ_del_nota["id"])["valor"] == 7.0,
               "nota continua intacta depois das tentativas recusadas")

        # --- Etapa fechada bloqueia a exclusao ---
        coord_a.post("/api/config/etapas/%d/fechar" % etapa_del_nota["id"])
        bloqueado = professor_a.delete("/api/professor/notas/%d" % nota_joao["id"])
        checar(bloqueado.status_code == 400,
               "excluir nota de etapa fechada responde 400")
        checar(_nota_do_joao(ativ_del_nota["id"])["valor"] == 7.0,
               "nota continua existindo depois da tentativa bloqueada por etapa fechada")
        coord_a.post("/api/config/etapas/%d/reabrir" % etapa_del_nota["id"])

        # --- Funcionamento: professor exclui a propria nota, etapa aberta ---
        excluida = professor_a.delete("/api/professor/notas/%d" % nota_joao["id"])
        checar(excluida.status_code == 204,
               "professor exclui nota propria com a etapa aberta")

        checar(_nota_do_joao(ativ_del_nota["id"]) is None
               or _nota_do_joao(ativ_del_nota["id"])["valor"] is None,
               "nota realmente desaparece depois de excluida")

        est_joao_sem_nota = estatisticas_de(professor_a, aluno_joao["id"])
        etapa_sem_nota = etapa_por_id(est_joao_sem_nota, etapa_del_nota["id"])
        checar(etapa_sem_nota["situacao"] == "em_andamento"
               and etapa_sem_nota["atividades_sem_nota"] == 1,
               "o calculo existente trata a nota excluida como ausente, "
               "nao como zero (etapa volta a em_andamento)")

        # ---------------------------------------------------------
        print("\n[16] Marco 6 - ano letivo como cadastro da escola")

        def anos_de(cliente):
            resposta = cliente.get("/api/config/anos-letivos")
            assert resposta.status_code == 200, resposta.get_json()
            return resposta.get_json()

        def ano_por_numero(cliente, ano):
            return next((a for a in anos_de(cliente) if a["ano"] == ano), None)

        def anos_atuais(cliente):
            return [a["ano"] for a in anos_de(cliente) if a["status"] == "atual"]

        def virar_para(cliente, ano_id, status, encerrar_atual=False):
            corpo = {"status": status}
            if encerrar_atual:
                corpo["encerrar_atual"] = True
            return cliente.put("/api/config/anos-letivos/%d" % ano_id, corpo)

        # --- cadastro, isolamento e papeis
        lista_a = anos_de(coord_a)
        ano_a_2026 = next((a for a in lista_a if a["ano"] == ANO), None)
        checar(ano_a_2026 is not None and ano_a_2026["status"] == "atual"
               and ano_a_2026["totalTurmas"] >= 1
               and ano_a_2026["totalEtapas"] >= 1,
               "M6-1: a escola A lista 2026 como ano atual, com turmas e etapas")
        checar(not ({a["id"] for a in anos_de(coord_b)}
                    & {a["id"] for a in lista_a}),
               "M6-2: escolas A e B nao compartilham registro de ano (as duas tem 2026)")
        checar(Cliente(cliente_flask).get("/api/config/anos-letivos")
               .status_code == 401,
               "M6-3: sem token, a lista de anos responde 401")
        checar(professor_a.get("/api/config/anos-letivos").status_code == 403,
               "M6-4: Professor nao lista anos letivos (403)")
        checar(professor_a.post("/api/config/anos-letivos",
                                {"ano": 2040}).status_code == 403
               and virar_para(professor_a, ano_a_2026["id"],
                              "encerrado").status_code == 403
               and professor_a.delete(
                   "/api/config/anos-letivos/%d" % ano_a_2026["id"]
               ).status_code == 403,
               "M6-5: Professor nao cria, altera nem exclui ano letivo (403)")
        checar(ano_por_numero(coord_a, ANO)["status"] == "atual"
               and ano_por_numero(coord_a, 2040) is None,
               "M6-6: as tentativas do Professor nao mudaram nada")

        # --- criar
        resposta = coord_a.post("/api/config/anos-letivos", {"ano": 2027})
        ano_2027 = resposta.get_json()
        checar(resposta.status_code == 201 and ano_2027["ano"] == 2027
               and ano_2027["status"] == "planejamento",
               "M6-7: criar 2027 sem status nasce em planejamento")
        checar(coord_a.post("/api/config/anos-letivos",
                            {"ano": 2027}).status_code == 409,
               "M6-8: a mesma escola nao repete o ano (409)")
        resposta = coord_b.post("/api/config/anos-letivos", {"ano": 2027})
        ano_b_2027 = resposta.get_json()
        checar(resposta.status_code == 201 and ano_b_2027["id"] != ano_2027["id"],
               "M6-9: outra escola pode ter o mesmo ano 2027")
        for corpo, motivo in (({"ano": "abc"}, "texto"),
                              ({"ano": 1999}, "antes de 2000"),
                              ({"ano": 2101}, "depois de 2100"),
                              ({}, "ausente")):
            checar(coord_a.post("/api/config/anos-letivos",
                                corpo).status_code == 400,
                   "M6-10: ano invalido (%s) responde 400" % motivo)
        checar(coord_a.post("/api/config/anos-letivos",
                            {"ano": 2041, "status": "qualquer"}
                            ).status_code == 400,
               "M6-11: status invalido responde 400")

        # --- um unico ano atual por escola
        resposta = coord_a.post("/api/config/anos-letivos",
                                {"ano": 2042, "status": "atual"})
        checar(resposta.status_code == 409 and "2026" in resposta.get_json()["error"],
               "M6-12: criar um segundo ano atual responde 409 e diz qual e o atual")
        checar(virar_para(coord_a, ano_2027["id"], "atual").status_code == 409,
               "M6-13: marcar 2027 como atual com 2026 atual responde 409")
        checar(anos_atuais(coord_a) == [ANO],
               "M6-14: depois das tentativas, so 2026 continua atual")
        resposta = virar_para(coord_a, ano_2027["id"], "atual", encerrar_atual=True)
        checar(resposta.status_code == 200 and anos_atuais(coord_a) == [2027]
               and ano_por_numero(coord_a, ANO)["status"] == "encerrado",
               "M6-15: confirmando a troca, 2027 vira atual e 2026 encerra, juntos")
        virar_para(coord_a, ano_a_2026["id"], "atual", encerrar_atual=True)
        virar_para(coord_a, ano_2027["id"], "planejamento")
        checar(anos_atuais(coord_a) == [ANO]
               and ano_por_numero(coord_a, 2027)["status"] == "planejamento",
               "M6-16: a troca e reversivel (2026 atual, 2027 em planejamento)")

        # --- outra escola, ids inexistentes e valores invalidos
        checar(virar_para(coord_a, ano_b_2027["id"], "encerrado").status_code == 404
               and coord_a.delete(
                   "/api/config/anos-letivos/%d" % ano_b_2027["id"]
               ).status_code == 404
               and ano_por_numero(coord_b, 2027)["status"] == "planejamento",
               "M6-17: A nao altera nem exclui o ano da escola B (404) e o ano de B segue igual")
        checar(virar_para(coord_a, 999999, "atual").status_code == 404,
               "M6-18: ano inexistente responde 404")
        checar(virar_para(coord_a, ano_2027["id"], "invalido").status_code == 400,
               "M6-19: status invalido na atualizacao responde 400")

        # --- excluir e encerrar
        ano_2050 = coord_a.post("/api/config/anos-letivos", {"ano": 2050}).get_json()
        checar(coord_a.delete("/api/config/anos-letivos/%d" % ano_2050["id"]
                              ).status_code == 204
               and ano_por_numero(coord_a, 2050) is None,
               "M6-20: ano sem turma nem etapa pode ser excluido")
        resposta = coord_a.delete("/api/config/anos-letivos/%d" % ano_a_2026["id"])
        checar(resposta.status_code == 409 and ano_por_numero(coord_a, ANO),
               "M6-21: ano com turmas e etapas nao e excluido (409)")
        coord_a.post("/api/config/anos-letivos", {"ano": 2025, "status": "encerrado"})
        checar(coord_a.post("/api/classes", {
            "name": "Turma em ano encerrado", "ano_letivo": 2025
        }).status_code == 409,
               "M6-22: turma nova em ano encerrado responde 409")
        checar(coord_a.post("/api/config/etapas", {
            "nome": "Etapa 2025", "ordem": 1, "ano_letivo": 2025
        }).status_code == 400,
               "M6-23: etapa nova em ano encerrado responde 400")

        # --- turma pertence a um ano da propria escola
        checar(coord_a.get("/api/classes/%d" % turma_a["id"]).get_json()["anoLetivo"]
               == ANO,
               "M6-24: turma criada sem informar o ano herdou o ano atual (2026)")
        resposta = coord_a.post("/api/classes",
                                {"name": "Turma 2027 Plano", "ano_letivo": 2027})
        turma_2027 = resposta.get_json()
        checar(resposta.status_code == 201 and turma_2027["anoLetivo"] == 2027,
               "M6-25: turma criada em ano em planejamento")
        checar(coord_a.post("/api/classes", {
            "name": "Turma ano inexistente", "ano_letivo": 2035
        }).status_code == 404,
               "M6-26: turma em ano que a escola nao cadastrou responde 404")
        coord_b.post("/api/config/anos-letivos", {"ano": 2029})
        checar(coord_a.post("/api/classes", {
            "name": "Turma no ano da escola B", "ano_letivo": 2029
        }).status_code == 404,
               "M6-27: A nao cria turma em ano que so a escola B tem")
        checar(coord_b.post("/api/classes", {
            "name": "Turma B 2029", "ano_letivo": 2029
        }).status_code == 201,
               "M6-28: a escola B cria turma no ano dela")

        mover = coord_a.post("/api/classes", {"name": "Turma Mover Ano"}).get_json()
        resposta = coord_a.put("/api/classes/%d" % mover["id"], {"ano_letivo": 2027})
        checar(resposta.status_code == 200 and resposta.get_json()["anoLetivo"] == 2027,
               "M6-29: turma sem atividades pode mudar de ano")
        resposta = coord_a.put("/api/classes/%d" % turma_c["id"], {"ano_letivo": 2027})
        checar(resposta.status_code == 400 and "atividades" in resposta.get_json()["error"],
               "M6-30: turma com atividades nao muda de ano (400)")
        checar(coord_a.put("/api/classes/%d" % mover["id"],
                           {"ano_letivo": 2029}).status_code == 404,
               "M6-31: mudar a turma para o ano que so a B tem responde 404")
        checar(coord_a.put("/api/classes/%d" % turma_a["id"],
                           {"name": "9 Ano A", "ano_letivo": ANO}).status_code == 200,
               "M6-32: reenviar o mesmo ano ao editar a turma nao falha")
        ids_2027 = {t["id"] for t in
                    coord_a.get("/api/classes?ano_letivo=2027").get_json()}
        checar({turma_2027["id"], mover["id"]} <= ids_2027
               and turma_a["id"] not in ids_2027,
               "M6-33: GET /api/classes?ano_letivo=2027 traz so as turmas desse ano")

        # --- etapa pertence a um ano
        def etapa_no_ano(cliente, nome, ordem, ano):
            resposta = cliente.post("/api/config/etapas",
                                    {"nome": nome, "ordem": ordem, "ano_letivo": ano})
            etapa = resposta.get_json()
            if resposta.status_code == 201:
                cliente.post("/api/config/etapas/%d/notas" % etapa["id"],
                             {"nota_minima": 6, "nota_maxima": 10})
            return resposta, etapa

        resposta, etapa_27 = etapa_no_ano(coord_a, "Etapa 2027", 1, 2027)
        checar(resposta.status_code == 201 and etapa_27["anoLetivo"] == 2027,
               "M6-34: etapa criada em 2027 pertence a 2027")
        resposta = coord_a.post("/api/config/etapas", {"nome": "Etapa sem ano", "ordem": 77})
        checar(resposta.status_code == 201 and resposta.get_json()["anoLetivo"] == ANO,
               "M6-35: etapa criada sem informar o ano usa o ano atual (2026)")
        etapas_padrao = coord_a.get("/api/config/etapas").get_json()
        checar(etapas_padrao and all(e["anoLetivo"] == ANO for e in etapas_padrao),
               "M6-36: GET /api/config/etapas sem ano traz so as do ano atual")
        checar([e["id"] for e in
                coord_a.get("/api/config/etapas?ano_letivo=2027").get_json()]
               == [etapa_27["id"]],
               "M6-37: GET /api/config/etapas?ano_letivo=2027 traz so as de 2027")
        checar(coord_a.post("/api/config/etapas", {
            "nome": "Etapa X", "ordem": 1, "ano_letivo": 2035
        }).status_code == 404,
               "M6-38: etapa em ano que a escola nao cadastrou responde 404")
        checar(coord_a.post("/api/config/etapas", {
            "nome": "Etapa X", "ordem": 1, "ano_letivo": 2029
        }).status_code == 404,
               "M6-39: A nao cria etapa em ano que so a escola B tem")

        # --- atividade: turma e etapa do MESMO ano
        prof6 = coord_a.post("/api/coordenacao/professores", {
            "nome": "Professor Ano", "email": "prof.ano.%s" % SUFIXO,
            "disciplina": "Historia",
        }).get_json()
        professor_6 = ativar_professor(prof6)
        t26 = coord_a.post("/api/classes", {"name": "T6 2026"}).get_json()
        t27 = coord_a.post("/api/classes",
                           {"name": "T6 2027", "ano_letivo": 2027}).get_json()
        coord_a.post("/api/coordenacao/professores/%d/turmas" % prof6["id"],
                     {"turma_ids": [t26["id"], t27["id"]]})
        etapa_26 = criar_etapa(coord_a, "E26 Contexto", 95, 6, 10)
        crit_26 = criar_criterio(coord_a, etapa_26["id"], "Provas", 100)
        crit_27 = criar_criterio(coord_a, etapa_27["id"], "Provas", 100)

        def nova_atividade(cliente, turma_id, etapa_id, criterio_id, titulo):
            return cliente.post("/api/activities", {
                "title": titulo, "class_id": turma_id, "etapa_id": etapa_id,
                "criterio_id": criterio_id, "nota_maxima": 10,
            })

        resposta = nova_atividade(professor_6, t26["id"], etapa_27["id"],
                                  crit_27["id"], "Turma 2026 com etapa 2027")
        checar(resposta.status_code == 400
               and "ano letivo" in resposta.get_json()["error"],
               "M6-40: atividade de turma 2026 com etapa de 2027 responde 400")
        checar(nova_atividade(professor_6, t27["id"], etapa_26["id"],
                              crit_26["id"], "Turma 2027 com etapa 2026"
                              ).status_code == 400,
               "M6-41: atividade de turma 2027 com etapa de 2026 responde 400")
        resposta = nova_atividade(professor_6, t26["id"], etapa_26["id"],
                                  crit_26["id"], "Prova 2026")
        ativ_26 = resposta.get_json()
        checar(resposta.status_code == 201,
               "M6-42: turma e etapa de 2026 formam uma atividade valida")
        resposta = nova_atividade(professor_6, t27["id"], etapa_27["id"],
                                  crit_27["id"], "Prova 2027")
        ativ_27 = resposta.get_json()
        checar(resposta.status_code == 201,
               "M6-43: turma e etapa de 2027 formam uma atividade valida")
        etapa_b_2029 = etapa_no_ano(coord_b, "Etapa B 2029", 1, 2029)[1]
        crit_b_2029 = criar_criterio(coord_b, etapa_b_2029["id"], "Provas", 100)
        checar(nova_atividade(professor_6, t27["id"], etapa_b_2029["id"],
                              crit_b_2029["id"], "Etapa da escola B"
                              ).status_code == 404,
               "M6-44: atividade nao usa a etapa de outra escola, mesmo de outro ano (404)")
        checar(professor_6.put("/api/activities/%d" % ativ_26["id"], {
            "etapa_id": etapa_27["id"], "criterio_id": crit_27["id"]
        }).status_code == 400,
               "M6-45: editar a atividade para uma etapa de outro ano responde 400")
        checar(professor_6.put("/api/activities/%d" % ativ_26["id"],
                               {"class_id": t27["id"]}).status_code == 400,
               "M6-46: mover a atividade para turma de outro ano, mantendo a etapa, responde 400")
        checar(professor_6.put("/api/activities/%d" % ativ_26["id"],
                               {"title": "Prova 2026 renomeada"}).status_code == 200,
               "M6-47: editar a atividade sem tocar em turma ou etapa continua permitido")

        # --- dashboard, estatisticas e boletim respeitam o ano
        al_26 = coord_a.post("/api/coordenacao/turmas/%d/alunos" % t26["id"],
                             {"nome": "Aluno Risco 2026"}).get_json()
        al_27 = coord_a.post("/api/coordenacao/turmas/%d/alunos" % t27["id"],
                             {"nome": "Aluno Risco 2027"}).get_json()
        lancar(professor_6, ativ_26["id"], al_26["id"], 2)
        lancar(professor_6, ativ_27["id"], al_27["id"], 3)

        def nomes_em_risco(painel):
            return [a["nome"] for a in painel["alunosEmRisco"]]

        painel = professor_6.get("/api/professor/dashboard").get_json()
        checar(painel["anoLetivo"] == ANO and painel["anoLetivoStatus"] == "atual"
               and painel["totalTurmas"] == 1 and painel["totalAlunos"] == 1
               and nomes_em_risco(painel) == ["Aluno Risco 2026"],
               "M6-48: o dashboard usa so o ano atual: a turma 2027 (planejamento) nao entra")
        painel_27 = professor_6.get("/api/professor/dashboard?ano_letivo=2027").get_json()
        checar(painel_27["anoLetivo"] == 2027 and painel_27["totalTurmas"] == 1
               and nomes_em_risco(painel_27) == ["Aluno Risco 2027"],
               "M6-49: pedindo o ano 2027, o dashboard mostra so a turma e o risco de 2027")
        checar(professor_6.get("/api/professor/dashboard?ano_letivo=2035"
                               ).status_code == 404,
               "M6-50: dashboard de um ano que a escola nao tem responde 404")
        virar_para(coord_a, ano_2027["id"], "atual", encerrar_atual=True)
        painel = professor_6.get("/api/professor/dashboard").get_json()
        checar(painel["anoLetivo"] == 2027 and painel["totalTurmas"] == 1
               and nomes_em_risco(painel) == ["Aluno Risco 2027"],
               "M6-51: na virada do ano o dashboard passa para 2027, sem misturar os dois")
        virar_para(coord_a, ano_a_2026["id"], "atual", encerrar_atual=True)

        ids_26 = {e["id"] for e in
                  coord_a.get("/api/config/etapas?ano_letivo=2026").get_json()}
        ids_27 = {e["id"] for e in
                  coord_a.get("/api/config/etapas?ano_letivo=2027").get_json()}
        checar(ids_26 and ids_27 and not ids_26 & ids_27,
               "M6-52: as etapas de 2026 e de 2027 sao conjuntos separados")

        est_26 = professor_6.get(
            "/api/professor/alunos/%d/estatisticas" % al_26["id"]).get_json()
        est_27 = professor_6.get(
            "/api/professor/alunos/%d/estatisticas" % al_27["id"]).get_json()
        checar(est_26["anoLetivo"] == ANO
               and {e["etapa_id"] for e in est_26["etapas"]} == ids_26,
               "M6-53: o desempenho do aluno de 2026 traz so etapas de 2026")
        checar(est_27["anoLetivo"] == 2027
               and {e["etapa_id"] for e in est_27["etapas"]} == ids_27,
               "M6-54: o desempenho do aluno de 2027 traz so etapas de 2027")

        def etapas_do_boletim(boletim):
            return [{e["etapa_id"] for e in aluno["etapas"]}
                    for aluno in boletim["alunos"]]

        bol_26 = professor_6.get("/api/professor/turmas/%d/boletim" % t26["id"]).get_json()
        bol_27 = professor_6.get("/api/professor/turmas/%d/boletim" % t27["id"]).get_json()
        checar(bol_26["ano_letivo"] == ANO and etapas_do_boletim(bol_26) == [ids_26],
               "M6-55: o boletim da turma de 2026 traz so etapas de 2026")
        checar(bol_27["ano_letivo"] == 2027 and etapas_do_boletim(bol_27) == [ids_27],
               "M6-56: o boletim da turma de 2027 traz so etapas de 2027")
        bol_coord = coord_a.get("/api/coordenacao/turmas/%d/boletim" % t27["id"]).get_json()
        checar(bol_coord["ano_letivo"] == 2027 and etapas_do_boletim(bol_coord) == [ids_27],
               "M6-57: o boletim da Coordenacao tambem usa o ano da propria turma")

        media_26 = professor_6.get(
            "/api/professor/turmas/%d/alunos" % t26["id"]).get_json()
        media_27 = professor_6.get(
            "/api/professor/turmas/%d/alunos" % t27["id"]).get_json()
        checar(media_26[0]["media"] == 2.0 and media_27[0]["media"] == 3.0,
               "M6-58: a media de cada turma sai da etapa atual do ano da propria turma")

        # --- escola sem ano atual
        coord_e = Cliente(cliente_flask)
        resposta = coord_e.post("/api/auth/cadastro-coordenacao", {
            "nome": "Escola E", "email": "e.%s" % SUFIXO, "senha": "senha123",
        })
        coord_e.token = resposta.get_json()["token"]
        checar(anos_de(coord_e) == [],
               "M6-59: uma escola nova nao tem ano letivo nenhum")
        resposta = coord_e.post("/api/classes", {"name": "Turma sem ano"})
        checar(resposta.status_code == 409 and "ano letivo" in resposta.get_json()["error"],
               "M6-60: sem ano atual, criar turma sem informar o ano responde 409")
        checar(coord_e.get("/api/config/etapas").get_json() == []
               and coord_e.post("/api/config/etapas",
                                {"nome": "E", "ordem": 1}).status_code == 400,
               "M6-61: sem ano atual nao ha etapas, e criar etapa sem ano responde 400")
        ano_e = coord_e.post("/api/config/anos-letivos",
                             {"ano": ANO, "status": "atual"}).get_json()
        turma_e = coord_e.post("/api/classes", {"name": "Turma E"}).get_json()
        prof_e = coord_e.post("/api/coordenacao/professores", {
            "nome": "Professor E", "email": "prof.e.%s" % SUFIXO,
        }).get_json()
        coord_e.post("/api/coordenacao/professores/%d/turmas" % prof_e["id"],
                     {"turma_ids": [turma_e["id"]]})
        professor_e = ativar_professor(prof_e)
        painel_e = professor_e.get("/api/professor/dashboard").get_json()
        checar(painel_e["anoLetivo"] == ANO and painel_e["totalTurmas"] == 1,
               "M6-62: com o ano atual cadastrado, o dashboard da escola E funciona")
        virar_para(coord_e, ano_e["id"], "encerrado")
        painel_e = professor_e.get("/api/professor/dashboard").get_json()
        checar(painel_e["anoLetivo"] is None and painel_e["totalTurmas"] == 0
               and painel_e["alunosEmRisco"] == [],
               "M6-63: encerrado o ano e sem outro atual, o dashboard vem zerado, sem adivinhar ano")

        # ---------------------------------------------------------
        print("\n[16] Marco 7 - transferencia de aluno com historico")
        destino_transferencia = coord_a.post("/api/classes", {
            "name": "Turma Transferencia 2026", "ano_letivo": ANO,
        }).get_json()
        prof_origem = coord_a.post("/api/coordenacao/professores", {
            "nome": "Professor Origem", "email": "prof.origem.%s" % SUFIXO,
        }).get_json()
        prof_destino = coord_a.post("/api/coordenacao/professores", {
            "nome": "Professor Destino", "email": "prof.destino.%s" % SUFIXO,
        }).get_json()
        coord_a.post("/api/coordenacao/professores/%d/turmas" % prof_origem["id"],
                     {"turma_ids": [turma_a["id"]]})
        coord_a.post("/api/coordenacao/professores/%d/turmas" % prof_destino["id"],
                     {"turma_ids": [destino_transferencia["id"]]})
        professor_origem = ativar_professor(prof_origem)
        professor_destino = ativar_professor(prof_destino)
        atividade_origem = professor_origem.post("/api/activities", {
            "title": "Prova antes da transferencia", "class_id": turma_a["id"],
            "etapa_id": config_a["etapa"]["id"],
            "criterio_id": config_a["criterio"]["id"], "nota_maxima": 10,
        }).get_json()
        aluno_transferencia = coord_a.post(
            "/api/coordenacao/turmas/%d/alunos" % turma_a["id"],
            {"nome": "Aluno Transferido Silva", "matricula": "M7-001"},
        ).get_json()
        historico_inicial = coord_a.get(
            "/api/coordenacao/alunos/%d/historico" % aluno_transferencia["id"]
        )
        checar(historico_inicial.status_code == 200
               and len(historico_inicial.get_json()) == 1
               and historico_inicial.get_json()[0]["atual"] is True
               and historico_inicial.get_json()[0]["turmaId"] == turma_a["id"],
               "M7-1: cadastro manual cria vinculo historico inicial aberto")
        checar(query_one(
            "SELECT COUNT(*) AS n FROM aluno_turma_historico h "
            "INNER JOIN aluno al ON al.id = h.aluno_id WHERE al.matricula = %s",
            ("2026003",),
        )["n"] == 1, "M7-2: importacao de aluno tambem cria historico inicial")
        lancamento_antigo = professor_origem.post(
            "/api/atividades/%d/notas" % atividade_origem["id"],
            {"aluno_id": aluno_transferencia["id"], "valor": 7},
        )
        checar(lancamento_antigo.status_code == 201,
               "M7-3: professor da origem lanca nota antes da transferencia")
        transferencia = coord_a.post(
            "/api/coordenacao/alunos/%d/transferir" % aluno_transferencia["id"],
            {"turma_id": destino_transferencia["id"], "motivo": "Mudanca de turma"},
        )
        checar(transferencia.status_code == 200
               and transferencia.get_json()["turmaId"] == destino_transferencia["id"],
               "M7-4: transferencia atualiza a turma atual do aluno")
        historico = coord_a.get(
            "/api/coordenacao/alunos/%d/historico" % aluno_transferencia["id"]
        ).get_json()
        checar(len(historico) == 2 and historico[0]["turmaId"] == destino_transferencia["id"]
               and historico[0]["atual"] is True and historico[1]["turmaId"] == turma_a["id"]
               and historico[1]["dataFim"] is not None,
               "M7-5: historico ordena novo vinculo aberto e origem fechada")
        origem_atual = professor_origem.get(
            "/api/professor/turmas/%d/alunos" % turma_a["id"]
        ).get_json()
        destino_atual = professor_destino.get(
            "/api/professor/turmas/%d/alunos" % destino_transferencia["id"]
        ).get_json()
        checar(all(a["id"] != aluno_transferencia["id"] for a in origem_atual)
               and any(a["id"] == aluno_transferencia["id"] for a in destino_atual),
               "M7-6: aluno sai da turma e do professor antigos e entra nos novos")
        checar(query_one(
            "SELECT COUNT(*) AS n FROM nota WHERE atividade_id = %s AND aluno_id = %s",
            (atividade_origem["id"], aluno_transferencia["id"]),
        )["n"] == 1,
               "M7-7: nota antiga continua associada a atividade da turma original")
        checar(professor_origem.post(
            "/api/atividades/%d/notas" % atividade_origem["id"],
            {"aluno_id": aluno_transferencia["id"], "valor": 8},
        ).status_code == 404,
               "M7-8: professor antigo nao altera aluno transferido")
        atividade_destino = professor_destino.post("/api/activities", {
            "title": "Prova depois da transferencia", "class_id": destino_transferencia["id"],
            "etapa_id": config_a["etapa"]["id"],
            "criterio_id": config_a["criterio"]["id"], "nota_maxima": 10,
        }).get_json()
        checar(professor_destino.post(
            "/api/atividades/%d/notas" % atividade_destino["id"],
            {"aluno_id": aluno_transferencia["id"], "valor": 9},
        ).status_code == 201,
               "M7-9: professor novo pode lancar nota na turma nova")
        estatistica_nova = professor_destino.get(
            "/api/professor/alunos/%d/estatisticas" % aluno_transferencia["id"]
        ).get_json()
        checar(estatistica_nova["totalNotas"] == 1 and estatistica_nova["media"] == 9.0,
               "M7-10: desempenho atual nao mistura nota da turma antiga")
        checar(coord_a.post(
            "/api/coordenacao/alunos/%d/transferir" % aluno_transferencia["id"],
            {"turma_id": destino_transferencia["id"]},
        ).status_code == 400,
               "M7-11: transferencia para a mesma turma e recusada")
        checar(coord_a.post(
            "/api/coordenacao/alunos/%d/transferir" % aluno_transferencia["id"],
            {"turma_id": turma_b["id"]},
        ).status_code == 404
               and coord_b.post(
                   "/api/coordenacao/alunos/%d/transferir" % aluno_transferencia["id"],
                   {"turma_id": turma_b["id"]},
               ).status_code == 404,
               "M7-12: turma destino e coordenacao de outra escola sao bloqueadas")
        checar(professor_destino.post(
            "/api/coordenacao/alunos/%d/transferir" % aluno_transferencia["id"],
            {"turma_id": turma_a["id"]},
        ).status_code == 403,
               "M7-13: Professor nao usa endpoint administrativo de transferencia")
        checar(coord_a.post("/api/coordenacao/alunos/999999/transferir", {
            "turma_id": turma_a["id"],
        }).status_code == 404 and coord_a.post(
            "/api/coordenacao/alunos/%d/transferir" % aluno_transferencia["id"],
            {"turma_id": 999999},
        ).status_code == 404,
               "M7-14: aluno ou turma inexistente responde 404")
        aluno_futuro = coord_a.post(
            "/api/coordenacao/turmas/%d/alunos" % turma_a["id"],
            {"nome": "Aluno Proximo Ano", "matricula": "M7-002"},
        ).get_json()
        coord_a.post("/api/config/anos-letivos", {"ano": 2028})
        turma_2028 = coord_a.post("/api/classes", {
            "name": "Turma Transferencia 2028", "ano_letivo": 2028,
        }).get_json()
        checar(coord_a.post(
            "/api/coordenacao/alunos/%d/transferir" % aluno_futuro["id"],
            {"turma_id": turma_2028["id"]},
        ).status_code == 200,
               "M7-15: progressao para turma da mesma escola em ano planejamento e permitida")
        aluno_excluir = coord_a.post(
            "/api/coordenacao/turmas/%d/alunos" % turma_a["id"],
            {"nome": "Aluno Excluir Historico", "matricula": "M7-003"},
        ).get_json()
        coord_a.post("/api/coordenacao/alunos/%d/transferir" % aluno_excluir["id"],
                     {"turma_id": destino_transferencia["id"]})
        coord_a.delete("/api/coordenacao/alunos/%d" % aluno_excluir["id"])
        checar(query_one(
            "SELECT COUNT(*) AS n FROM aluno_turma_historico WHERE aluno_id = %s",
            (aluno_excluir["id"],),
        )["n"] == 0, "M7-16: excluir aluno remove historico por cascade")

        # ---------------------------------------------------------
        print("\n[14] Marco 8 - gestao administrativa de professores")
        prof8 = coord_a.post("/api/coordenacao/professores", {
            "nome": "Professor Gestao", "email": "prof.gestao.%s" % SUFIXO,
            "disciplina": "Geografia",
        }).get_json()
        lista8 = coord_a.get("/api/coordenacao/professores").get_json()
        pendente8 = next(p for p in lista8 if p["id"] == prof8["id"])
        checar(pendente8["status"] == "convite_pendente"
               and pendente8["habilitado"] is True
               and pendente8["senhaConfigurada"] is False,
               "M8-01: professor novo fica com convite pendente")

        convite_original = prof8["conviteToken"]
        reenvio = coord_a.post(
            "/api/coordenacao/professores/%d/reenviar-convite" % prof8["id"]
        )
        checar(reenvio.status_code == 200
               and reenvio.get_json().get("conviteToken") != convite_original,
               "M8-02: reenvio substitui convite pendente")
        checar(cliente_flask.post("/api/auth/criar-senha-professor", json={
            "email": prof8["email"], "senha": "senha123",
            "token": convite_original,
        }).status_code == 403, "M8-03: convite anterior deixa de valer")

        editado8 = coord_a.put(
            "/api/coordenacao/professores/%d" % prof8["id"], {
                "nome": "Professor Gestao Editado",
                "email": "prof.gestao.editado.%s" % SUFIXO,
            },
        )
        checar(editado8.status_code == 200
               and editado8.get_json()["nome"] == "Professor Gestao Editado"
               and editado8.get_json()["email"] == "prof.gestao.editado.%s" % SUFIXO,
               "M8-04: Coordenacao edita nome e email do professor")
        convite_editado = editado8.get_json().get("conviteToken")
        checar(bool(convite_editado) and convite_editado != reenvio.get_json().get("conviteToken"),
               "M8-05: editar email pendente renova o convite")
        checar(coord_a.put(
            "/api/coordenacao/professores/%d" % prof8["id"],
            {"email": prof_a["email"]},
        ).status_code == 409, "M8-06: conflito de email e recusado")
        checar(cliente_flask.post("/api/auth/criar-senha-professor", json={
            "email": "prof.gestao.editado.%s" % SUFIXO,
            "senha": "senha123", "token": convite_editado,
        }).status_code == 200, "M8-07: convite editado ativa professor")

        login8 = cliente_flask.post("/api/auth/login-professor", json={
            "email": "prof.gestao.editado.%s" % SUFIXO, "senha": "senha123",
        })
        professor8 = Cliente(cliente_flask)
        professor8.token = login8.get_json()["token"]
        checar(login8.status_code == 200, "M8-08: professor ativo faz login")
        checar(coord_a.post(
            "/api/coordenacao/professores/%d/reenviar-convite" % prof8["id"]
        ).status_code == 400, "M8-09: conta ativa nao recebe convite de primeiro acesso")
        checar(professor8.put(
            "/api/coordenacao/professores/%d" % prof8["id"], {"nome": "Invalido"}
        ).status_code == 403, "M8-10: Professor nao acessa administracao de professores")

        vinculo8 = coord_a.post(
            "/api/coordenacao/professores/%d/turmas" % prof8["id"],
            {"turma_ids": [turma_a["id"], turma_a["id"]]},
        )
        turmas8 = coord_a.get(
            "/api/coordenacao/professores/%d/turmas" % prof8["id"]
        ).get_json()
        checar(vinculo8.status_code == 201 and len(turmas8) == 1,
               "M8-11: vinculo duplicado nao e criado")
        atividades_antes = query_one("SELECT COUNT(*) AS n FROM atividade")["n"]
        checar(coord_a.delete(
            "/api/coordenacao/professores/%d/turmas/%d" % (prof8["id"], turma_a["id"])
        ).status_code == 204, "M8-12: Coordenacao desvincula uma turma")
        checar(professor8.get(
            "/api/professor/turmas/%d/alunos" % turma_a["id"]
        ).status_code == 404, "M8-13: professor desvinculado perde acesso a turma")
        checar(query_one("SELECT COUNT(*) AS n FROM atividade")["n"] == atividades_antes,
               "M8-14: desvinculo nao apaga atividades")
        coord_a.post("/api/coordenacao/professores/%d/turmas" % prof8["id"],
                     {"turma_ids": [turma_a2["id"]]})

        desativado8 = coord_a.post(
            "/api/coordenacao/professores/%d/desativar" % prof8["id"]
        )
        checar(desativado8.status_code == 200
               and desativado8.get_json()["status"] == "desativado",
               "M8-15: desativacao usa status administrativo persistido")
        checar(cliente_flask.post("/api/auth/login-professor", json={
            "email": "prof.gestao.editado.%s" % SUFIXO, "senha": "senha123",
        }).status_code == 401, "M8-16: professor desativado nao recebe JWT")
        checar(professor8.get("/api/professor/turmas").status_code == 403,
               "M8-17: JWT emitido antes da desativacao perde acesso")
        checar(professor8.get("/api/classes").status_code == 403,
               "M8-17b: JWT antigo tambem perde acesso a leitura compartilhada")
        for url in ("/api/professor/turmas", "/api/classes"):
            corpo403 = professor8.get(url).get_json()
            checar(corpo403.get("code") == "professor_desativado",
                   "M5F-01: 403 do professor desativado traz code=professor_desativado (%s)" % url)
        checar("code" not in (coord_a.post("/api/activities", {"title": "x"}).get_json()),
               "M5F-02: 403 comum (papel errado) NAO traz esse code")
        checar(coord_a.post(
            "/api/coordenacao/professores/%d/reenviar-convite" % prof8["id"]
        ).status_code == 400, "M8-18: professor desativado nao recebe convite")
        checar(coord_a.post(
            "/api/coordenacao/professores/%d/reativar" % prof8["id"]
        ).status_code == 200, "M8-19: Coordenacao reativa professor")
        login8_reaberto = cliente_flask.post("/api/auth/login-professor", json={
            "email": "prof.gestao.editado.%s" % SUFIXO, "senha": "senha123",
        })
        professor8.token = login8_reaberto.get_json()["token"]
        checar(login8_reaberto.status_code == 200
               and any(t["id"] == turma_a2["id"]
                       for t in professor8.get("/api/professor/turmas").get_json()),
               "M8-20: reativacao preserva vinculo restante e acesso")

        checar(coord_a.put("/api/coordenacao/professores/%d" % prof_b["id"], {
            "nome": "Outra escola",
        }).status_code == 404, "M8-21: Coordenacao nao edita professor de outra escola")
        checar(coord_a.post(
            "/api/coordenacao/professores/%d/desativar" % prof_b["id"]
        ).status_code == 404, "M8-22: Coordenacao nao desativa professor de outra escola")
        checar(coord_a.post(
            "/api/coordenacao/professores/%d/reativar" % prof_b["id"]
        ).status_code == 404, "M8-23: Coordenacao nao reativa professor de outra escola")
        checar(coord_a.post(
            "/api/coordenacao/professores/%d/reenviar-convite" % prof_b["id"]
        ).status_code == 404, "M8-24: Coordenacao nao reenvia convite de outra escola")
        checar(coord_a.delete(
            "/api/coordenacao/professores/%d/turmas/%d" % (prof_b["id"], turma_b["id"])
        ).status_code == 404, "M8-25: Coordenacao nao desvincula professor de outra escola")

        # ---------------------------------------------------------
        print("\n[15] Marco 9 - insights academicos explicaveis")

        class ClienteIaFalso:
            model = "modelo-smoke"
            payload = None

            def gerar(self, payload):
                ClienteIaFalso.payload = payload
                return {
                    "resumo": "Os dados mostram resultado abaixo do minimo.",
                    "pontosPositivos": ["Ha registros completos na etapa."],
                    "pontosAtencao": [{
                        "titulo": "Desempenho da etapa",
                        "evidencia": "O percentual registrado e 20%.",
                        "sugestao": "Revisar o criterio com a turma.",
                    }],
                    "sugestoesGerais": ["Acompanhar os proximos registros."],
                }

        with patch(
            "services.ia.gerar_insights_turma.AIClient",
            return_value=ClienteIaFalso(),
        ):
            insights = professor_6.post(
                "/api/professor/turmas/%d/insights" % t26["id"], {}
            )
            checar(insights.status_code == 200
                   and insights.get_json()["geradoPorIA"] is True
                   and insights.get_json()["insights"]["pontosAtencao"],
                   "M9-01: Professor vinculado gera insights estruturados")
            payload_ia = ClienteIaFalso.payload
            payload_serializado = str(payload_ia)
            checar(payload_ia["turma"]["anoLetivo"] == 2026
                   and payload_ia["alunos"][0]["situacao"] == "abaixo_do_minimo"
                   and "matricula" not in payload_serializado.lower()
                   and "email" not in payload_serializado.lower(),
                   "M9-02: payload usa calculo oficial e omite matricula/email")
            checar(professor_a2.post(
                "/api/professor/turmas/%d/insights" % t26["id"], {}
            ).status_code == 404 and professor_b.post(
                "/api/professor/turmas/%d/insights" % t26["id"], {}
            ).status_code == 404,
                   "M9-03: turma sem vinculo ou de outra escola fica oculta")
            checar(coord_a.post(
                "/api/professor/turmas/%d/insights" % t26["id"], {}
            ).status_code == 403,
                   "M9-04: Coordenacao nao usa endpoint exclusivo do Professor")

        from services.ia.client import AIProviderError, MENSAGEM_INDISPONIVEL

        class ClienteIaIndisponivel:
            model = "modelo-smoke"

            def gerar(self, payload):
                raise AIProviderError(MENSAGEM_INDISPONIVEL)

        with patch(
            "services.ia.gerar_insights_turma.AIClient",
            return_value=ClienteIaIndisponivel(),
        ):
            indisponivel = professor_6.post(
                "/api/professor/turmas/%d/insights" % t26["id"], {}
            )
            checar(indisponivel.status_code == 503
                   and "Tente novamente" in indisponivel.get_json()["error"],
                   "M9-05: indisponibilidade externa retorna erro amigavel")

        # ---------------------------------------------------------
        print("\n[16] Marco 9B - geracao assistida de atividades (IA nunca grava)")

        from services.ia.client import AIResponseError

        class ClienteIaAtividade:
            """Imita o AIClient: aplica o validador do caso, como o real faz."""
            model = "modelo-smoke"
            chamadas = 0
            payload = None
            erro = None

            def gerar(self, payload, caso=None):
                ClienteIaAtividade.chamadas += 1
                ClienteIaAtividade.payload = payload
                if ClienteIaAtividade.erro:
                    raise ClienteIaAtividade.erro
                pedido = payload["pedido"]
                questoes = []
                for i in range(pedido["quantidadeQuestoes"]):
                    objetiva = pedido["tipoDasQuestoes"] == "objetiva" or (
                        pedido["tipoDasQuestoes"] == "mista" and i % 2 == 0)
                    questoes.append({
                        "tipo": "objetiva" if objetiva else "discursiva",
                        "enunciado": "Questao %d sobre %s" % (i + 1, pedido["tema"]),
                        "alternativas": ["A) um", "B) dois", "C) tres", "D) quatro"]
                        if objetiva else [],
                        "respostaEsperada": "B" if objetiva else "Cita causas e impactos.",
                        "explicacao": "Explicacao %d" % (i + 1),
                    })
                return caso.validar({
                    "titulo": "Atividade sugerida: %s" % pedido["tema"],
                    "descricao": "Leia com atencao e responda.",
                    "objetivo": "Compreender o tema.",
                    "questoes": questoes,
                    "rubricaSugerida": [
                        {"criterio": "Compreensao", "descricao": "Entende o conceito", "peso": 60},
                        {"criterio": "Clareza", "descricao": "Escreve com clareza", "peso": 40},
                    ],
                })

        def gerar_ia(cliente, turma_id, corpo):
            return cliente.post(
                "/api/professor/turmas/%d/atividades/gerar" % turma_id, corpo)

        def total_atividades():
            return query_one("SELECT COUNT(*) AS n FROM atividade")["n"]

        etapa_fech = criar_etapa(coord_a, "E26 Fechada IA", 96, 6, 10)
        crit_fech = criar_criterio(coord_a, etapa_fech["id"], "Provas", 100)
        checar(coord_a.post("/api/config/etapas/%d/fechar" % etapa_fech["id"]
                            ).status_code == 200, "M9B-00: etapa de teste fechada")

        pedido_ok = {
            "etapaId": etapa_26["id"], "criterioId": crit_26["id"],
            "tema": "Revolucao Industrial", "objetivo": "Compreender causas e impactos",
            "dificuldade": "media", "quantidadeQuestoes": 4, "tipo": "mista",
            "professorId": 999999, "coordenacaoId": 999999,
        }
        cliente_ia = ClienteIaAtividade()
        with patch("services.ia.gerar_atividade.AIClient", return_value=cliente_ia):
            antes = total_atividades()
            lista_antes = len(professor_6.get("/api/activities?class_id=%d" % t26["id"]).get_json())
            ok = gerar_ia(professor_6, t26["id"], pedido_ok)
            corpo_ok = ok.get_json() or {}
            sugestao = corpo_ok.get("sugestao", {})
            checar(ok.status_code == 200 and corpo_ok.get("geradoPorIA") is True
                   and len(sugestao.get("questoes", [])) == 4
                   and sugestao.get("titulo", "").startswith("Atividade sugerida"),
                   "M9B-01: Professor vinculado recebe sugestao estruturada com 4 questoes")
            checar(corpo_ok["contexto"]["etapa"] == "E26 Contexto"
                   and corpo_ok["contexto"]["criterio"] == "Provas",
                   "M9B-02: contexto devolve etapa e criterio validados")
            checar(total_atividades() == antes
                   and len(professor_6.get("/api/activities?class_id=%d" % t26["id"]
                                           ).get_json()) == lista_antes,
                   "M9B-03: gerar sugestao NAO cria atividade no banco")
            checar(sugestao["questoes"][0]["alternativas"][0] == "um"
                   and sugestao["questoes"][0]["respostaEsperada"] == "B",
                   "M9B-04: letra duplicada some das alternativas e o gabarito vira uma letra")

            payload_ia = ClienteIaAtividade.payload
            serializado = str(payload_ia).lower()
            checar(payload_ia["etapa"] == "E26 Contexto"
                   and payload_ia["criterioDeAvaliacao"] == "Provas"
                   and payload_ia["pedido"]["tema"] == "Revolucao Industrial"
                   and payload_ia["pedido"]["quantidadeQuestoes"] == 4,
                   "M9B-05: payload leva turma, etapa, criterio e o pedido do Professor")
            checar("@" not in serializado and "999999" not in serializado
                   and "professor" not in serializado
                   and "matricula" not in serializado
                   and "alunos" not in serializado and "senha" not in serializado,
                   "M9B-06: payload sem aluno, email, matricula, ids nem professor_id do corpo")

            # --- autorizacao: nenhuma falha chega ao provedor
            ClienteIaAtividade.chamadas = 0
            checar(gerar_ia(professor_a2, t26["id"], pedido_ok).status_code == 404,
                   "M9B-07: professor da escola sem vinculo com a turma recebe 404")
            checar(gerar_ia(professor_b, t26["id"], pedido_ok).status_code == 404,
                   "M9B-08: professor de outra escola recebe 404")
            checar(gerar_ia(coord_a, t26["id"], pedido_ok).status_code == 403,
                   "M9B-09: Coordenacao recebe 403 no endpoint do Professor")
            checar(gerar_ia(Cliente(cliente_flask), t26["id"], pedido_ok
                            ).status_code == 401, "M9B-10: sem token recebe 401")
            checar(gerar_ia(professor_6, 99999999, pedido_ok).status_code == 404,
                   "M9B-11: turma inexistente recebe 404")

            # --- etapa e criterio: mesmas regras da criacao de atividade
            def com(**mudancas):
                corpo = dict(pedido_ok)
                corpo.update(mudancas)
                return corpo

            r = gerar_ia(professor_6, t26["id"],
                         com(etapaId=etapa_fech["id"], criterioId=crit_fech["id"]))
            checar(r.status_code == 400 and "fechada" in r.get_json()["error"],
                   "M9B-12: etapa fechada recebe 400")
            r = gerar_ia(professor_6, t26["id"],
                         com(etapaId=etapa_27["id"], criterioId=crit_27["id"]))
            checar(r.status_code == 400 and "ano letivo" in r.get_json()["error"],
                   "M9B-13: etapa de outro ano letivo recebe 400")
            checar(gerar_ia(professor_6, t27["id"], pedido_ok).status_code == 400,
                   "M9B-14: turma 2027 com etapa de 2026 recebe 400")
            checar(gerar_ia(professor_6, t26["id"],
                            com(etapaId=etapa_b_2029["id"], criterioId=crit_b_2029["id"])
                            ).status_code == 404,
                   "M9B-15: etapa e criterio de outra escola recebem 404")
            checar(gerar_ia(professor_6, t26["id"],
                            com(criterioId=crit_27["id"])).status_code == 404,
                   "M9B-16: criterio que nao pertence a etapa recebe 404")
            checar(gerar_ia(professor_6, t26["id"], com(criterioId=None)
                            ).status_code == 400,
                   "M9B-17: criterio sem etapa (ou etapa sem criterio) recebe 400")

            # --- validacao do pedido
            for rotulo, mudanca in (
                ("tema vazio", {"tema": "   "}),
                ("tema ausente", {"tema": None}),
                ("tema gigante", {"tema": "x" * 201}),
                ("quantidade zero", {"quantidadeQuestoes": 0}),
                ("quantidade 11", {"quantidadeQuestoes": 11}),
                ("quantidade texto", {"quantidadeQuestoes": "muitas"}),
                ("quantidade booleana", {"quantidadeQuestoes": True}),
                ("tipo invalido", {"tipo": "teste"}),
                ("dificuldade invalida", {"dificuldade": "impossivel"}),
                ("objetivo nao texto", {"objetivo": 5}),
            ):
                checar(gerar_ia(professor_6, t26["id"], com(**mudanca)
                                ).status_code == 400,
                       "M9B-18: %s recebe 400" % rotulo)
            for rotulo, mudanca in (
                ("tema lista", {"tema": ["x"]}),
                ("objetivo objeto", {"objetivo": {"a": 1}}),
                ("observacoes lista", {"observacoes": [1]}),
                ("dificuldade lista", {"dificuldade": ["facil"]}),
                ("tipo objeto", {"tipo": {"a": 1}}),
                ("quantidade lista", {"quantidadeQuestoes": [3]}),
                ("etapaId lista", {"etapaId": [1]}),
                ("criterioId objeto", {"criterioId": {"a": 1}}),
            ):
                r = gerar_ia(professor_6, t26["id"], com(**mudanca))
                checar(r.status_code == 400,
                       "M9B-18b: tipo errado (%s) continua 400 de validacao, nao 500" % rotulo)
            checar(ClienteIaAtividade.chamadas == 0,
                   "M9B-19: nenhuma falha de autorizacao ou validacao chamou a Groq")

            # --- tipos
            for tipo in ("discursiva", "objetiva"):
                r = gerar_ia(professor_6, t26["id"], com(tipo=tipo, quantidadeQuestoes=3))
                tipos = {q["tipo"] for q in (r.get_json() or {}).get("sugestao", {}).get("questoes", [])}
                checar(r.status_code == 200 and tipos == {tipo},
                       "M9B-20: tipo %s gera so questoes %s" % (tipo, tipo))

            # --- falhas do provedor: 503 amigavel, nada gravo, criacao manual segue
            antes = total_atividades()
            for rotulo, erro in (
                ("provedor indisponivel", AIProviderError(MENSAGEM_INDISPONIVEL)),
                ("contrato invalido", AIResponseError(MENSAGEM_INDISPONIVEL)),
            ):
                ClienteIaAtividade.erro = erro
                r = gerar_ia(professor_6, t26["id"], pedido_ok)
                checar(r.status_code == 503 and "Tente novamente" in r.get_json()["error"]
                       and "manualmente" in r.get_json()["error"],
                       "M9B-21: %s devolve 503 amigavel" % rotulo)
            ClienteIaAtividade.erro = None
            checar(total_atividades() == antes,
                   "M9B-22: falha da IA nao deixa atividade parcial")
            manual = nova_atividade(professor_6, t26["id"], etapa_26["id"],
                                    crit_26["id"], "Atividade manual apos falha")
            checar(manual.status_code == 201,
                   "M9B-23: criacao manual continua funcionando com a IA indisponivel")

            # --- confirmacao: so o fluxo normal grava, com o que o Professor editou
            ok = gerar_ia(professor_6, t26["id"], pedido_ok).get_json()["sugestao"]
            antes = total_atividades()
            descricao_editada = "Revisada pelo Professor: " + ok["questoes"][0]["enunciado"]
            criada = professor_6.post("/api/activities", {
                "title": "Titulo editado pelo Professor", "description": descricao_editada,
                "class_id": t26["id"], "etapa_id": etapa_26["id"],
                "criterio_id": crit_26["id"], "nota_maxima": 8,
            })
            salva = criada.get_json() or {}
            linha = query_one("SELECT titulo, descricao, nota_maxima, professor_id "
                              "FROM atividade WHERE id = %s", (salva.get("id"),))
            checar(criada.status_code == 201 and total_atividades() == antes + 1
                   and linha["titulo"] == "Titulo editado pelo Professor"
                   and linha["descricao"] == descricao_editada
                   and float(linha["nota_maxima"]) == 8.0
                   and linha["titulo"] != ok["titulo"]
                   and linha["professor_id"] == prof6["id"],
                   "M9B-24: atividade criada pelo fluxo normal guarda o que o Professor confirmou")
            checar(query_one("SELECT COUNT(*) AS n FROM atividade WHERE titulo = %s",
                             (ok["titulo"],))["n"] == 0,
                   "M9B-25: o titulo bruto sugerido pela IA nao foi gravado")

        # ---------------------------------------------------------
        print("\n[17] Marco 9C - correcao assistida (IA sugere, Professor lanca)")

        class ClienteIaCorrecao:
            """Imita o AIClient e aplica o validador do caso, como o real faz."""
            model = "modelo-smoke"
            chamadas = 0
            payload = None
            nota = 1.5
            erro = None

            def gerar(self, payload, caso=None):
                ClienteIaCorrecao.chamadas += 1
                ClienteIaCorrecao.payload = payload
                if ClienteIaCorrecao.erro:
                    raise ClienteIaCorrecao.erro
                trecho = " ".join(payload["respostaAluno"].split()[:4])
                nome = payload["rubrica"][0]["item"] if payload["rubrica"] else "Compreensao"
                return caso.validar({
                    "notaSugerida": ClienteIaCorrecao.nota,
                    "percentual": 999,
                    "avaliacao": [{
                        "criterio": nome, "resultado": "atendido_parcialmente",
                        "evidencia": 'O aluno escreve "%s".' % trecho,
                        "faltou": "Nao aprofunda.",
                    }],
                    "pontosPositivos": ["Cita o tema."],
                    "pontosMelhorar": ["Aprofundar."],
                    "justificativa": "Atende parte do esperado.",
                    "feedbackAluno": "Bom comeco; aprofunde a explicacao.",
                })

        def corrigir_ia(cliente, atividade_id, corpo):
            return cliente.post(
                "/api/professor/atividades/%d/correcao-assistida" % atividade_id, corpo)

        def notas_da_atividade(atividade_id):
            return query_all("SELECT aluno_id, valor FROM nota WHERE atividade_id = %s "
                             "ORDER BY aluno_id", (atividade_id,))

        ativ_9c = nova_atividade(professor_6, t26["id"], etapa_26["id"],
                                 crit_26["id"], "Prova 9C").get_json()
        al_controle = coord_a.post("/api/coordenacao/turmas/%d/alunos" % t26["id"],
                                   {"nome": "Aluno Controle 9C"}).get_json()
        checar(lancar(professor_6, ativ_9c["id"], al_26["id"], 4).status_code == 201,
               "M9C-00: nota 4 ja lancada para um aluno (nao pode mudar)")
        etapa_c9 = criar_etapa(coord_a, "E26 C9 a fechar", 97, 6, 10)
        crit_c9 = criar_criterio(coord_a, etapa_c9["id"], "Provas", 100)
        ativ_fech = nova_atividade(professor_6, t26["id"], etapa_c9["id"],
                                   crit_c9["id"], "Prova 9C fechada").get_json()
        checar(coord_a.post("/api/config/etapas/%d/fechar" % etapa_c9["id"]
                            ).status_code == 200, "M9C-00b: etapa da outra atividade fechada")
        row_b = query_one("SELECT coordenacao_id FROM turma WHERE id = %s", (turma_b["id"],))
        id_ativ_b = insert(
            "INSERT INTO atividade (coordenacao_id, turma_id, professor_id, etapa_id, "
            "criterio_id, titulo, nota_maxima) VALUES (%s, %s, %s, %s, %s, %s, %s)",
            (row_b["coordenacao_id"], turma_b["id"], prof_b["id"], etapa_b, criterio_b,
             "Prova da escola B", 10))

        pedido_c = {
            "questao": "Explique como a Revolucao Industrial mudou o trabalho.",
            "respostaEsperada": "Mecanizacao, fabricas e urbanizacao.",
            "respostaAluno": "A industrializacao aumentou a producao e levou gente do campo para a cidade.",
            "valorMaximo": 2,
            "rubrica": [{"item": "Compreensao do conceito", "peso": 100}],
            "alunoId": 123456, "professorId": 654321, "coordenacaoId": 777, "turmaId": 888,
        }
        cliente_c = ClienteIaCorrecao()
        with patch("services.ia.corrigir_resposta.AIClient", return_value=cliente_c):
            antes = notas_da_atividade(ativ_9c["id"])
            ok = corrigir_ia(professor_6, ativ_9c["id"], pedido_c)
            corpo = ok.get_json() or {}
            sug = corpo.get("sugestao", {})
            checar(ok.status_code == 200 and corpo.get("geradoPorIA") is True
                   and sug.get("notaSugerida") == 1.5 and len(sug.get("avaliacao", [])) == 1
                   and sug.get("feedbackAluno"),
                   "M9C-01: Professor vinculado recebe sugestao estruturada")
            checar(sug.get("percentual") == 75.0 and sug.get("valorMaximo") == 2.0,
                   "M9C-02: valorMaximo 2 e nota 1.5 geram percentual 75 (calculado no backend, nao os 999 da IA)")
            checar(notas_da_atividade(ativ_9c["id"]) == antes
                   and len(antes) == 1 and float(antes[0]["valor"]) == 4.0,
                   "M9C-03: analisar NAO cria nem altera nota")
            serializado = str(ClienteIaCorrecao.payload).lower()
            checar("aluno risco" not in serializado and "123456" not in serializado
                   and "654321" not in serializado and "777" not in serializado
                   and "888" not in serializado and "@" not in serializado
                   and "matricula" not in serializado,
                   "M9C-04: payload sem nome, ids, e-mail ou matricula; ids do corpo sao ignorados")
            checar(ClienteIaCorrecao.payload["valorMaximo"] == 2.0
                   and ClienteIaCorrecao.payload["criterioOficial"] == {"nome": "Provas"},
                   "M9C-05: contexto vem da atividade (criterio oficial) e o valor da rubrica/pedido")

            # --- autorizacao: nenhuma falha chega ao provedor
            ClienteIaCorrecao.chamadas = 0
            checar(corrigir_ia(professor_a2, ativ_9c["id"], pedido_c).status_code == 404,
                   "M9C-06: professor da escola sem vinculo com a turma recebe 404")
            checar(corrigir_ia(professor_b, ativ_9c["id"], pedido_c).status_code == 404,
                   "M9C-07: professor de outra escola recebe 404")
            checar(corrigir_ia(professor_6, id_ativ_b, pedido_c).status_code == 404,
                   "M9C-08: atividade de outra escola recebe 404")
            checar(corrigir_ia(coord_a, ativ_9c["id"], pedido_c).status_code == 403,
                   "M9C-09: Coordenacao recebe 403 no endpoint do Professor")
            checar(corrigir_ia(Cliente(cliente_flask), ativ_9c["id"], pedido_c
                               ).status_code == 401, "M9C-10: sem token recebe 401")
            checar(corrigir_ia(professor_6, 99999999, pedido_c).status_code == 404,
                   "M9C-11: atividade inexistente recebe 404")
            r = corrigir_ia(professor_6, ativ_fech["id"], pedido_c)
            checar(r.status_code == 400 and "fechada" in r.get_json()["error"],
                   "M9C-12: etapa fechada bloqueia a correcao com mensagem clara")

            def com(**mudancas):
                corpo_ = dict(pedido_c)
                corpo_.update(mudancas)
                return corpo_

            for rotulo, mudanca in (
                ("questao vazia", {"questao": "  "}),
                ("resposta esperada vazia", {"respostaEsperada": ""}),
                ("resposta do aluno vazia", {"respostaAluno": None}),
                ("valor maximo zero", {"valorMaximo": 0}),
                ("valor maximo negativo", {"valorMaximo": -2}),
                ("valor maximo texto", {"valorMaximo": "dois"}),
                ("valor maximo booleano", {"valorMaximo": True}),
                ("valor maximo acima da atividade", {"valorMaximo": 11}),
                ("rubrica nao lista", {"rubrica": "x"}),
                ("rubrica item sem nome", {"rubrica": [{"peso": 10}]}),
                ("rubrica peso invalido", {"rubrica": [{"item": "a", "peso": 500}]}),
            ):
                checar(corrigir_ia(professor_6, ativ_9c["id"], com(**mudanca)
                                   ).status_code == 400,
                       "M9C-13: %s recebe 400" % rotulo)
            for rotulo, mudanca in (
                ("questao objeto", {"questao": {"a": 1}}),
                ("resposta esperada lista", {"respostaEsperada": ["x"]}),
                ("resposta do aluno lista", {"respostaAluno": ["x"]}),
                ("valor maximo lista", {"valorMaximo": [2]}),
                ("valor maximo objeto", {"valorMaximo": {"a": 1}}),
                ("rubrica item lista", {"rubrica": [{"item": ["x"]}]}),
                ("rubrica peso lista", {"rubrica": [{"item": "a", "peso": [1]}]}),
                ("rubrica item numero", {"rubrica": [5]}),
            ):
                r = corrigir_ia(professor_6, ativ_9c["id"], com(**mudanca))
                checar(r.status_code == 400,
                       "M9C-13b: tipo errado (%s) continua 400 de validacao, nao 500" % rotulo)
            checar(ClienteIaCorrecao.chamadas == 0,
                   "M9C-14: nenhuma falha de autorizacao, etapa ou entrada chamou a Groq")

            # --- contrato da IA: nota fora da faixa vira 503, nunca clamp
            for rotulo, nota in (("nota negativa", -1), ("nota acima do maximo", 3),
                                 ("nota texto", "1,5"), ("nota NaN", float("nan"))):
                ClienteIaCorrecao.nota = nota
                r = corrigir_ia(professor_6, ativ_9c["id"], pedido_c)
                checar(r.status_code == 503 and "manualmente" in r.get_json()["error"],
                       "M9C-15: IA devolve %s -> 503 amigavel (sem corrigir em silencio)" % rotulo)
            ClienteIaCorrecao.nota = 1.5

            # --- falhas do provedor
            for rotulo, erro in (
                ("provedor indisponivel", AIProviderError(MENSAGEM_INDISPONIVEL)),
                ("resposta invalida", AIResponseError(MENSAGEM_INDISPONIVEL)),
            ):
                ClienteIaCorrecao.erro = erro
                r = corrigir_ia(professor_6, ativ_9c["id"], pedido_c)
                checar(r.status_code == 503 and "Tente novamente" in r.get_json()["error"],
                       "M9C-16: %s devolve 503 amigavel" % rotulo)
            ClienteIaCorrecao.erro = None
            checar(notas_da_atividade(ativ_9c["id"]) == antes,
                   "M9C-17: falhas da IA nao mexem em nenhuma nota")
            checar(lancar(professor_6, ativ_9c["id"], al_26["id"], 5).status_code == 201,
                   "M9C-18: lancar nota manualmente continua funcionando com a IA indisponivel")
            lancar(professor_6, ativ_9c["id"], al_26["id"], 4)

            # --- controle humano: IA sugere 6, Professor decide 7, banco recebe 7
            ClienteIaCorrecao.nota = 6.0
            r = corrigir_ia(professor_6, ativ_9c["id"], com(valorMaximo=10))
            sug = (r.get_json() or {}).get("sugestao", {})
            sem_nota = query_one("SELECT COUNT(*) AS n FROM nota WHERE atividade_id = %s "
                                 "AND aluno_id = %s", (ativ_9c["id"], al_controle["id"]))["n"]
            checar(r.status_code == 200 and sug.get("notaSugerida") == 6.0
                   and sug.get("percentual") == 60.0 and sem_nota == 0,
                   "M9C-19: IA sugere 6.0 (60%) e o aluno continua sem nota no banco")
            salvar = lancar(professor_6, ativ_9c["id"], al_controle["id"], 7.0)
            gravada = query_one("SELECT valor FROM nota WHERE atividade_id = %s AND aluno_id = %s",
                                (ativ_9c["id"], al_controle["id"]))
            checar(salvar.status_code == 201 and float(gravada["valor"]) == 7.0
                   and float(gravada["valor"]) != sug["notaSugerida"],
                   "M9C-20: Professor altera 6.0 para 7.0 e o banco recebe 7.0, a decisao humana")

        # ---------------------------------------------------------
        print("\n[18] Marco 9D - feedback e recuperacao (IA so interpreta; leitura)")

        class ClienteIaFeedback:
            """Imita o AIClient e aplica o validador do caso, como o real faz."""
            model = "modelo-smoke"
            chamadas = 0
            payload = None
            erro = None
            resumo_extra = ""

            def gerar(self, payload, caso=None):
                ClienteIaFeedback.chamadas += 1
                json.dumps(payload)  # como o AIClient real: Decimal do MySQL quebraria aqui
                ClienteIaFeedback.payload = payload
                if ClienteIaFeedback.erro:
                    raise ClienteIaFeedback.erro
                resumo = "Resumo do desempenho com base nos dados calculados."
                if payload["tipoDePlano"] == "acompanhamento":
                    resumo += " Os dados da etapa ainda estao incompletos."
                return caso.validar({
                    "resumo": resumo + ClienteIaFeedback.resumo_extra,
                    "pontosConsolidados": ["Criterio com melhor desempenho."],
                    "pontosAtencao": [{"descricao": "Criterio com menor desempenho.",
                                       "evidencia": "Dado recebido do motor academico."}],
                    "objetivosRecuperacao": ["Reforcar o criterio de menor desempenho."],
                    "acoesSugeridas": [{"acao": "Atividade curta com correcao guiada.",
                                        "motivo": "Criterio com desempenho mais baixo."}],
                    "atividadesSugeridas": ["Exercicio focado no criterio."],
                    "acompanhamento": "Observar as proximas atividades avaliadas.",
                })

        def feedback_ia(cliente, aluno_id, corpo):
            return cliente.post("/api/professor/alunos/%d/feedback-ia" % aluno_id, corpo)

        def instantaneo():
            """Estado das tabelas academicas: 0 diferencas entre antes e depois."""
            tabelas = ("nota", "atividade", "etapa", "criterio", "aluno", "turma",
                       "professor_turma", "aluno_turma_historico")
            return {t: query_all("SELECT * FROM %s ORDER BY id" % t if t != "professor_turma"
                                 and t != "aluno_turma_historico" else "SELECT * FROM %s" % t)
                    for t in tabelas}

        etapa_fb = criar_etapa(coord_a, "E26 Feedback", 98, 6, 10)
        crit_prova = criar_criterio(coord_a, etapa_fb["id"], "Provas", 60)
        crit_trab = criar_criterio(coord_a, etapa_fb["id"], "Trabalhos", 40)
        ativ_p = nova_atividade(professor_6, t26["id"], etapa_fb["id"], crit_prova["id"], "Prova FB").get_json()
        ativ_t = nova_atividade(professor_6, t26["id"], etapa_fb["id"], crit_trab["id"], "Trabalho FB").get_json()

        def aluno_novo(nome):
            return coord_a.post("/api/coordenacao/turmas/%d/alunos" % t26["id"],
                                {"nome": nome}).get_json()

        al_baixo = aluno_novo("Aluno Feedback Baixo")
        al_ok = aluno_novo("Aluno Feedback Adequado")
        al_and = aluno_novo("Aluno Feedback Andamento")
        al_zero = aluno_novo("Aluno Feedback Sem Notas")
        lancar(professor_6, ativ_p["id"], al_baixo["id"], 4)
        lancar(professor_6, ativ_t["id"], al_baixo["id"], 5)
        lancar(professor_6, ativ_p["id"], al_ok["id"], 9)
        lancar(professor_6, ativ_t["id"], al_ok["id"], 8)
        lancar(professor_6, ativ_p["id"], al_and["id"], 7)   # trabalho sem nota lancada

        # etapa com atividade graduada e FECHADA: o feedback continua permitido (leitura)
        etapa_f = criar_etapa(coord_a, "E26 FB fechada", 99, 6, 10)
        crit_f = criar_criterio(coord_a, etapa_f["id"], "Provas", 100)
        ativ_f = nova_atividade(professor_6, t26["id"], etapa_f["id"], crit_f["id"], "Prova FB fechada").get_json()
        lancar(professor_6, ativ_f["id"], al_ok["id"], 9)
        checar(coord_a.post("/api/config/etapas/%d/fechar" % etapa_f["id"]).status_code == 200,
               "M9D-00: etapa de teste fechada")
        # etapa sem pesos validos (soma 50): configuracao invalida
        etapa_inv = criar_etapa(coord_a, "E26 FB pesos", 100, 6, 10)
        criar_criterio(coord_a, etapa_inv["id"], "Provas", 50)

        outro_aluno_a = coord_a.post("/api/coordenacao/turmas/%d/alunos" % turma_a["id"],
                                     {"nome": "Aluno Outra Turma"}).get_json()
        aluno_b = coord_b.post("/api/coordenacao/turmas/%d/alunos" % turma_b["id"],
                               {"nome": "Aluno Escola B"}).get_json()

        cliente_f = ClienteIaFeedback()
        with patch("services.ia.gerar_feedback.AIClient", return_value=cliente_f):
            antes = instantaneo()

            r = feedback_ia(professor_6, al_baixo["id"], {"etapaId": etapa_fb["id"]})
            corpo = r.get_json() or {}
            oficial = corpo.get("contexto", {}).get("resultadoOficial", {})
            checar(r.status_code == 200 and corpo.get("geradoPorIA") is True
                   and corpo["contexto"]["tipoPlano"] == "recuperacao"
                   and oficial.get("situacao") == "abaixo_do_minimo"
                   and oficial.get("nota") == 4.4 and oficial.get("percentual") == 44.0,
                   "M9D-01: abaixo do minimo gera plano de recuperacao com o resultado oficial do motor (4.4 / 44%)")
            checar(ClienteIaFeedback.payload["tipoDePlano"] == "recuperacao"
                   and ClienteIaFeedback.payload["resultado"]["nota"] == 4.4
                   and {c["nome"]: c["desempenhoPercentual"]
                        for c in ClienteIaFeedback.payload["criterios"]} == {"Provas": 40.0, "Trabalhos": 50.0},
                   "M9D-02: payload leva o calculo do motor, com o desempenho por criterio")
            serializado = str(ClienteIaFeedback.payload).lower()
            checar("feedback baixo" not in serializado and "aluno feedback" not in serializado
                   and "@" not in serializado and "matricula" not in serializado
                   and str(al_baixo["id"]) not in ClienteIaFeedback.payload["etapa"]["nome"]
                   and "'id'" not in serializado and "turma" not in serializado,
                   "M9D-03: payload sem nome, e-mail, matricula, ids nem turma")

            r = feedback_ia(professor_6, al_ok["id"], {"etapaId": etapa_fb["id"]})
            corpo = r.get_json() or {}
            checar(r.status_code == 200 and corpo["contexto"]["tipoPlano"] == "continuidade"
                   and corpo["contexto"]["resultadoOficial"]["situacao"] == "adequado"
                   and corpo["contexto"]["resultadoOficial"]["nota"] == 8.6,
                   "M9D-04: adequado gera plano de continuidade (nao forca recuperacao)")

            r = feedback_ia(professor_6, al_and["id"], {"etapaId": etapa_fb["id"]})
            corpo = r.get_json() or {}
            checar(r.status_code == 200 and corpo["contexto"]["tipoPlano"] == "acompanhamento"
                   and corpo["contexto"]["resultadoOficial"]["situacao"] == "em_andamento"
                   and corpo["contexto"]["resultadoOficial"]["nota"] is None
                   and ClienteIaFeedback.payload["atividades"]["semNotaLancada"] == 1
                   and "incompletos" in corpo["sugestao"]["resumo"],
                   "M9D-05: em andamento nao conclui nada: acompanhamento, 1 atividade sem nota e aviso de dados incompletos")

            r = feedback_ia(professor_6, al_ok["id"], {"etapaId": etapa_f["id"]})
            checar(r.status_code == 200 and r.get_json()["contexto"]["fechada"] is True,
                   "M9D-06: etapa fechada e permitida (somente leitura)")

            # --- autorizacao: nenhuma falha chega ao provedor
            ClienteIaFeedback.chamadas = 0
            corpo_ok = {"etapaId": etapa_fb["id"]}
            checar(feedback_ia(professor_a2, al_baixo["id"], corpo_ok).status_code == 404,
                   "M9D-07: professor da escola sem vinculo com a turma recebe 404")
            checar(feedback_ia(professor_b, al_baixo["id"], corpo_ok).status_code == 404,
                   "M9D-08: professor de outra escola recebe 404")
            checar(feedback_ia(professor_6, aluno_b["id"], corpo_ok).status_code == 404,
                   "M9D-09: aluno de outra escola recebe 404")
            checar(feedback_ia(professor_6, outro_aluno_a["id"], corpo_ok).status_code == 404,
                   "M9D-10: aluno de turma nao vinculada ao professor recebe 404")
            checar(feedback_ia(professor_6, 99999999, corpo_ok).status_code == 404,
                   "M9D-11: aluno inexistente recebe 404")
            checar(feedback_ia(coord_a, al_baixo["id"], corpo_ok).status_code == 403,
                   "M9D-12: Coordenacao recebe 403 no endpoint do Professor")
            checar(feedback_ia(Cliente(cliente_flask), al_baixo["id"], corpo_ok).status_code == 401,
                   "M9D-13: sem token recebe 401")

            # --- etapa
            checar(feedback_ia(professor_6, al_baixo["id"], {}).status_code == 400,
                   "M9D-14: sem etapa recebe 400 (nao usa etapa implicita)")
            checar(feedback_ia(professor_6, al_baixo["id"], {"etapaId": "abc"}).status_code == 400,
                   "M9D-15: etapa nao numerica recebe 400")
            r = feedback_ia(professor_6, al_baixo["id"], {"etapaId": etapa_27["id"]})
            checar(r.status_code == 400 and "ano letivo" in r.get_json()["error"],
                   "M9D-16: etapa de outro ano letivo recebe 400")
            checar(feedback_ia(professor_6, al_baixo["id"], {"etapaId": etapa_b}).status_code == 404,
                   "M9D-17: etapa de outra escola recebe 404")
            checar(feedback_ia(professor_6, al_baixo["id"], {"etapaId": 99999999}).status_code == 404,
                   "M9D-18: etapa inexistente recebe 404")

            # --- dados insuficientes: 422 sem chamar a Groq
            r = feedback_ia(professor_6, al_zero["id"], corpo_ok)
            checar(r.status_code == 422 and "atividade avaliada" in r.get_json()["error"],
                   "M9D-19: aluno sem atividade avaliada recebe 422")
            r = feedback_ia(professor_6, al_ok["id"], {"etapaId": etapa_inv["id"]})
            checar(r.status_code == 422 and "pesos" in r.get_json()["error"].lower(),
                   "M9D-20: etapa com configuracao invalida recebe 422")
            checar(ClienteIaFeedback.chamadas == 0,
                   "M9D-21: nenhuma falha de autorizacao, etapa ou dados chamou a Groq")

            # --- contrato da IA: numero inventado e previsao viram 503
            for rotulo, extra in (("numero inventado", " O resultado foi 72%."),
                                  ("previsao de reprovacao", " O aluno sera reprovado."),
                                  ("atividade pendente", " Ha atividade pendente.")):
                ClienteIaFeedback.resumo_extra = extra
                r = feedback_ia(professor_6, al_baixo["id"], corpo_ok)
                checar(r.status_code == 503 and "Tente novamente" in r.get_json()["error"],
                       "M9D-22: IA devolve %s -> 503 amigavel" % rotulo)
            ClienteIaFeedback.resumo_extra = ""

            # --- falhas do provedor
            for rotulo, erro in (
                ("provedor indisponivel", AIProviderError(MENSAGEM_INDISPONIVEL)),
                ("resposta invalida", AIResponseError(MENSAGEM_INDISPONIVEL)),
            ):
                ClienteIaFeedback.erro = erro
                r = feedback_ia(professor_6, al_baixo["id"], corpo_ok)
                checar(r.status_code == 503 and "continua disponivel" in r.get_json()["error"],
                       "M9D-23: %s devolve 503 amigavel" % rotulo)
            ClienteIaFeedback.erro = None
            ainda = professor_6.get("/api/professor/alunos/%d/estatisticas" % al_baixo["id"])
            checar(ainda.status_code == 200 and any(
                e["etapa_id"] == etapa_fb["id"] and e["nota_calculada"] == 4.4
                for e in ainda.get_json()["etapas"]),
                   "M9D-24: com a IA indisponivel, o desempenho do aluno segue funcionando e a nota e a mesma")

            # --- leitura: nenhuma tabela academica muda
            depois = instantaneo()
            checar(depois == antes,
                   "M9D-25: gerar feedback NAO altera nenhuma tabela academica (nota, atividade, etapa, "
                   "criterio, aluno, turma, vinculos): estado identico antes e depois")

        # ---------------------------------------------------------
        print("\n[I-02] Atividade com notas nao troca de turma")
        prof_i2_dados = coord_a.post("/api/coordenacao/professores", {
            "nome": "Professor Mover", "email": "prof.mover.%s" % SUFIXO,
            "disciplina": "Geografia",
        }).get_json()
        prof_i2 = ativar_professor(prof_i2_dados)
        turma_orig = coord_a.post("/api/classes", {"name": "I02 Origem"}).get_json()
        turma_dest = coord_a.post("/api/classes", {"name": "I02 Destino"}).get_json()
        coord_a.post("/api/config/anos-letivos", {"ano": 2033})
        turma_outro_ano = coord_a.post(
            "/api/classes", {"name": "I02 Turma 2033", "ano_letivo": 2033}
        ).get_json()
        coord_a.post(
            "/api/coordenacao/professores/%d/turmas" % prof_i2_dados["id"],
            {"turma_ids": [turma_orig["id"], turma_dest["id"], turma_outro_ano["id"]]},
        )
        etapa_i2 = criar_etapa(coord_a, "E I02", 101, 6, 10)
        crit_i2 = criar_criterio(coord_a, etapa_i2["id"], "Provas", 100)
        alunos_i2 = [
            coord_a.post("/api/coordenacao/turmas/%d/alunos" % turma_orig["id"],
                         {"nome": nome}).get_json()
            for nome in ("Ana Mover Silva", "Bia Mover Costa")
        ]

        def turma_da_atividade(atividade_id):
            return query_one(
                "SELECT turma_id FROM atividade WHERE id = %s", (atividade_id,)
            )["turma_id"]

        def notas_da_atividade(atividade_id):
            return query_all(
                "SELECT id, atividade_id, aluno_id, valor, observacao, "
                "created_at, updated_at FROM nota WHERE atividade_id = %s "
                "ORDER BY id", (atividade_id,),
            )

        # 1. sem notas: muda de turma normalmente
        ativ_sem = criar_atividade(prof_i2, turma_orig["id"], etapa_i2["id"],
                                   crit_i2["id"], 10, "I02 sem notas")
        mover = prof_i2.put("/api/activities/%d" % ativ_sem["id"],
                            {"class_id": turma_dest["id"]})
        checar(mover.status_code == 200
               and turma_da_atividade(ativ_sem["id"]) == turma_dest["id"],
               "I02-01: atividade SEM notas muda de turma com sucesso")
        checar(prof_i2.put("/api/activities/%d" % ativ_sem["id"],
                           {"turma_id": turma_outro_ano["id"]}).status_code == 400
               and turma_da_atividade(ativ_sem["id"]) == turma_dest["id"],
               "I02-02: sem notas, a validacao normal continua valendo (etapa de outro ano -> 400)")

        # atividade com notas (uma delas zero: nota 0 conta como nota lancada)
        ativ_com = criar_atividade(prof_i2, turma_orig["id"], etapa_i2["id"],
                                   crit_i2["id"], 10, "I02 com notas")
        lancar(prof_i2, ativ_com["id"], alunos_i2[0]["id"], 8)
        lancar(prof_i2, ativ_com["id"], alunos_i2[1]["id"], 0)
        antes = notas_da_atividade(ativ_com["id"])
        checar(len(antes) == 2, "I02-03: preparo: atividade com 2 notas (uma delas zero)")

        # 2. tentar mudar de turma -> 400 amigavel
        for chave in ("class_id", "turma_id"):
            r = prof_i2.put("/api/activities/%d" % ativ_com["id"],
                            {chave: turma_dest["id"]})
            checar(r.status_code == 400 and "notas" in r.get_json()["error"].lower(),
                   "I02-04: atividade com notas nao troca de turma (%s) -> 400 amigavel" % chave)
        checar(turma_da_atividade(ativ_com["id"]) == turma_orig["id"],
               "I02-05: a atividade continua na turma de origem apos a tentativa")

        # 5. nenhuma nota apagada ou alterada
        checar(notas_da_atividade(ativ_com["id"]) == antes,
               "I02-06: nenhuma nota foi apagada ou alterada na tentativa bloqueada "
               "(ids, alunos, valores, observacao e datas identicos)")

        # so uma nota de valor zero tambem bloqueia
        ativ_zero = criar_atividade(prof_i2, turma_orig["id"], etapa_i2["id"],
                                    crit_i2["id"], 10, "I02 so zero")
        lancar(prof_i2, ativ_zero["id"], alunos_i2[0]["id"], 0)
        checar(prof_i2.put("/api/activities/%d" % ativ_zero["id"],
                           {"class_id": turma_dest["id"]}).status_code == 400,
               "I02-07: uma unica nota de valor zero ja impede a troca de turma")

        # 3. editar so titulo/descricao continua funcionando
        r = prof_i2.put("/api/activities/%d" % ativ_com["id"], {
            "title": "I02 com notas (renomeada)", "description": "novo texto",
        })
        checar(r.status_code == 200 and r.get_json()["title"] == "I02 com notas (renomeada)"
               and r.get_json()["class_id"] == turma_orig["id"],
               "I02-08: com notas, editar titulo e descricao continua funcionando")

        # 4. mesma turma no payload continua valida
        r = prof_i2.put("/api/activities/%d" % ativ_com["id"], {
            "class_id": turma_orig["id"], "title": "I02 com notas v2",
        })
        checar(r.status_code == 200 and r.get_json()["title"] == "I02 com notas v2",
               "I02-09: com notas, informar a MESMA turma no payload continua funcionando")
        checar(notas_da_atividade(ativ_com["id"]) == antes,
               "I02-10: nenhuma nota mudou depois das edicoes permitidas")

        # 6. cross-school segue como esta (404, nada muda)
        checar(professor_b.put("/api/activities/%d" % ativ_com["id"],
                               {"class_id": turma_b["id"]}).status_code == 404,
               "I02-11: professor de OUTRA escola tentando mover atividade com notas -> 404")
        checar(prof_i2.put("/api/activities/%d" % ativ_sem["id"],
                           {"class_id": turma_b["id"]}).status_code == 404,
               "I02-12: mover atividade (sem notas) para turma de outra escola -> 404")
        checar(turma_da_atividade(ativ_sem["id"]) == turma_dest["id"]
               and turma_da_atividade(ativ_com["id"]) == turma_orig["id"]
               and notas_da_atividade(ativ_com["id"]) == antes,
               "I02-13: depois das tentativas cross-school nada mudou (turmas e notas)")

        # 7. etapa fechada: comportamento existente intacto
        checar(coord_a.post("/api/config/etapas/%d/fechar" % etapa_i2["id"]
                            ).status_code == 200, "I02-14: coordenacao fecha a etapa do teste")
        checar(prof_i2.put("/api/activities/%d" % ativ_com["id"],
                           {"title": "na etapa fechada"}).status_code == 400,
               "I02-15: etapa fechada: editar atividade com notas continua 400")
        checar(prof_i2.put("/api/activities/%d" % ativ_sem["id"],
                           {"class_id": turma_orig["id"]}).status_code == 400,
               "I02-16: etapa fechada: mover atividade sem notas continua 400")
        checar(turma_da_atividade(ativ_sem["id"]) == turma_dest["id"]
               and notas_da_atividade(ativ_com["id"]) == antes,
               "I02-17: etapa fechada: nada mudou")

        # ---------------------------------------------------------
        print("\n[I-03] Etapa fechada congela a configuracao")
        etapa_i3 = criar_etapa(coord_a, "E I03", 102, 6, 10)
        crit_prova = criar_criterio(coord_a, etapa_i3["id"], "Provas", 60)
        crit_trab = criar_criterio(coord_a, etapa_i3["id"], "Trabalhos", 40)
        etapa_i3_aberta = criar_etapa(coord_a, "E I03 aberta", 103, 6, 10)
        crit_i3_aberta = criar_criterio(coord_a, etapa_i3_aberta["id"], "Provas", 100)

        def config_da_etapa(etapa_id):
            """Estado exato da etapa e dos criterios dela, direto do banco."""
            return (
                query_one("SELECT * FROM etapa WHERE id = %s", (etapa_id,)),
                query_all("SELECT * FROM criterio WHERE etapa_id = %s ORDER BY id",
                          (etapa_id,)),
            )

        ep = "/api/config/etapas/%d" % etapa_i3["id"]

        # 1. etapa aberta pode ser editada
        r = coord_a.put("/api/config/etapas/%d" % etapa_i3_aberta["id"],
                        {"nome": "E I03 aberta v2", "ativa": True})
        checar(r.status_code == 200 and r.get_json()["nome"] == "E I03 aberta v2",
               "I03-01: etapa ABERTA pode ser editada")
        checar(coord_a.post("/api/config/etapas/%d/notas" % etapa_i3_aberta["id"],
                            {"nota_minima": 5, "nota_maxima": 10}).status_code == 200
               and coord_a.put("/api/config/criterios/%d" % crit_i3_aberta["id"],
                               {"peso": 100}).status_code == 200,
               "I03-02: etapa ABERTA aceita notas minima/maxima e edicao de criterio")

        # fecha a etapa e guarda o estado exato
        checar(coord_a.post(ep + "/fechar").status_code == 200,
               "I03-03: coordenacao fecha a etapa")
        antes_i3 = config_da_etapa(etapa_i3["id"])

        def bloqueada(resposta):
            return (resposta.status_code == 400
                    and "fechada" in resposta.get_json()["error"].lower())

        checar(bloqueada(coord_a.put(ep, {"nome": "Renomeada"})),
               "I03-04: etapa fechada: editar nome -> 400 amigavel")
        checar(bloqueada(coord_a.put(ep, {"ordem": 150})),
               "I03-05: etapa fechada: alterar ordem -> 400")
        checar(bloqueada(coord_a.put(ep, {"data_inicio": "2026-02-01",
                                          "data_fim": "2026-04-30"})),
               "I03-06: etapa fechada: alterar datas -> 400")
        checar(bloqueada(coord_a.put(ep, {"ativa": False})),
               "I03-07: etapa fechada: alterar 'ativa' -> 400")
        checar(bloqueada(coord_a.post(ep + "/notas", {"nota_maxima": 100,
                                                      "nota_minima": 6})),
               "I03-08: etapa fechada: alterar nota_maxima -> 400")
        checar(bloqueada(coord_a.post(ep + "/notas", {"nota_minima": 9.5,
                                                      "nota_maxima": 10})),
               "I03-09: etapa fechada: alterar nota_minima -> 400")
        checar(bloqueada(coord_a.post("/api/config/etapas", {
            "nome": "Reconfig", "ordem": 102, "ano_letivo": ANO})),
               "I03-10: etapa fechada: reconfigurar pela mesma ordem/ano (upsert) -> 400")
        checar(bloqueada(coord_a.delete(ep)),
               "I03-11: etapa fechada: excluir a etapa -> 400")
        checar(bloqueada(coord_a.post("/api/config/criterios/etapa/%d" % etapa_i3["id"],
                                      {"nome": "Novo", "peso": 10})),
               "I03-12: etapa fechada: criar criterio -> 400")
        checar(bloqueada(coord_a.post("/api/config/criterios/etapa/%d" % etapa_i3["id"],
                                      {"nome": "Provas", "peso": 90})),
               "I03-13: etapa fechada: criar criterio com nome existente (upsert) -> 400")
        checar(bloqueada(coord_a.put("/api/config/criterios/%d" % crit_prova["id"],
                                     {"peso": 10})),
               "I03-14: etapa fechada: editar criterio -> 400")
        checar(bloqueada(coord_a.delete("/api/config/criterios/%d" % crit_trab["id"])),
               "I03-15: etapa fechada: excluir criterio -> 400")

        # 8. nada mudou
        checar(config_da_etapa(etapa_i3["id"]) == antes_i3,
               "I03-16: nenhuma configuracao mudou (etapa e criterios identicos, "
               "inclusive updated_at, depois de todas as tentativas)")

        # leitura continua liberada
        checar(coord_a.get(ep).status_code == 200
               and coord_a.get("/api/config/criterios/etapa/%d" % etapa_i3["id"]
                               ).status_code == 200,
               "I03-17: etapa fechada continua legivel (GET etapa e criterios)")

        # 11. cross-school: 404 (nao revela que esta fechada)
        for rotulo, resposta in (
            ("editar etapa", coord_b.put(ep, {"nome": "x"})),
            ("alterar notas", coord_b.post(ep + "/notas",
                                           {"nota_minima": 1, "nota_maxima": 2})),
            ("excluir etapa", coord_b.delete(ep)),
            ("criar criterio", coord_b.post(
                "/api/config/criterios/etapa/%d" % etapa_i3["id"],
                {"nome": "x", "peso": 1})),
            ("editar criterio", coord_b.put(
                "/api/config/criterios/%d" % crit_prova["id"], {"peso": 1})),
            ("excluir criterio", coord_b.delete(
                "/api/config/criterios/%d" % crit_prova["id"])),
        ):
            checar(resposta.status_code == 404,
                   "I03-18: escola B, %s em etapa fechada da escola A -> 404 (nao 400)" % rotulo)

        # 12. professor continua sem permissao
        checar(professor_a.put(ep, {"nome": "x"}).status_code == 403
               and professor_a.post(ep + "/notas", {"nota_minima": 1,
                                                    "nota_maxima": 2}).status_code == 403
               and professor_a.post("/api/config/criterios/etapa/%d" % etapa_i3["id"],
                                    {"nome": "x", "peso": 1}).status_code == 403
               and professor_a.put("/api/config/criterios/%d" % crit_prova["id"],
                                   {"peso": 1}).status_code == 403
               and professor_a.delete("/api/config/criterios/%d" % crit_prova["id"]
                                      ).status_code == 403,
               "I03-19: professor continua recebendo 403 na configuracao da etapa")
        checar(config_da_etapa(etapa_i3["id"]) == antes_i3,
               "I03-20: nada mudou depois das tentativas cross-school e do professor")

        # 9 e 10. reabrir restaura a edicao
        checar(coord_a.post(ep + "/reabrir").status_code == 200
               and coord_a.get(ep).get_json()["fechada"] is False,
               "I03-21: coordenacao reabre a etapa")
        r = coord_a.put(ep, {"nome": "E I03 reaberta"})
        checar(r.status_code == 200 and r.get_json()["nome"] == "E I03 reaberta",
               "I03-22: apos reabrir, editar a etapa volta a funcionar")
        checar(coord_a.post(ep + "/notas", {"nota_minima": 7, "nota_maxima": 10}
                            ).status_code == 200
               and float(query_one("SELECT nota_minima FROM etapa WHERE id = %s",
                                   (etapa_i3["id"],))["nota_minima"]) == 7.0,
               "I03-23: apos reabrir, alterar notas minima/maxima volta a funcionar")
        r = coord_a.post("/api/config/criterios/etapa/%d" % etapa_i3["id"],
                         {"nome": "Extra", "peso": 5})
        checar(r.status_code == 201, "I03-24: apos reabrir, criar criterio volta a funcionar")
        checar(coord_a.put("/api/config/criterios/%d" % crit_prova["id"],
                           {"peso": 55}).status_code == 200,
               "I03-25: apos reabrir, editar criterio volta a funcionar")
        checar(coord_a.delete("/api/config/criterios/%d" % r.get_json()["id"]
                              ).status_code == 204,
               "I03-26: apos reabrir, excluir criterio volta a funcionar")
        # 13. fechar de novo e conferir que congela de novo
        checar(coord_a.post(ep + "/fechar").status_code == 200
               and bloqueada(coord_a.put(ep, {"nome": "outra vez"})),
               "I03-27: fechar de novo congela de novo")
        checar(coord_a.post(ep + "/fechar").status_code == 400
               and coord_a.post(ep + "/reabrir").status_code == 200
               and coord_a.post(ep + "/reabrir").status_code == 400,
               "I03-28: fechar/reabrir mantem as regras de estado (fechar fechada e reabrir aberta -> 400)")

        # ---------------------------------------------------------
        print("\n[I-04] Exclusao barrada por FK vira 409 (nao 500)")

        def limpa(resposta):
            """Sem erro bruto: nada de SQL, constraint ou texto do driver."""
            texto = resposta.get_data(as_text=True).lower()
            return not any(t in texto for t in (
                "integrityerror", "constraint", "foreign key", "1451", "fk_",
                "`", "delete from", "traceback", "pymysql",
            ))

        def linha(sql, parametros):
            return query_one(sql, parametros)

        def linhas(sql, parametros):
            return query_all(sql, parametros)

        # --- criterio ---------------------------------------------------
        etapa_i4 = criar_etapa(coord_a, "E I04", 104, 6, 10)
        crit_livre = criar_criterio(coord_a, etapa_i4["id"], "Livre", 10)
        crit_usado = criar_criterio(coord_a, etapa_i4["id"], "Usado", 90)
        ativ_i4 = criar_atividade(prof_i2, turma_orig["id"], etapa_i4["id"],
                                  crit_usado["id"], 10, "I04 atividade vinculada")

        r = coord_a.delete("/api/config/criterios/%d" % crit_livre["id"])
        checar(r.status_code == 204, "I04-01: excluir criterio SEM dependencia continua funcionando (204)")
        checar(linha("SELECT id FROM criterio WHERE id = %s", (crit_livre["id"],)) is None,
               "I04-02: o criterio sem dependencia foi mesmo excluido")

        crit_antes = linha("SELECT * FROM criterio WHERE id = %s", (crit_usado["id"],))
        ativ_antes = linha("SELECT * FROM atividade WHERE id = %s", (ativ_i4["id"],))
        r = coord_a.delete("/api/config/criterios/%d" % crit_usado["id"])
        checar(r.status_code == 409 and r.get_json()["error"]
               == "Este criterio possui dados vinculados e nao pode ser excluido.",
               "I04-03: excluir criterio COM atividade -> 409 com mensagem de negocio")
        checar(limpa(r), "I04-04: a resposta do criterio nao traz SQL, constraint nem erro bruto")
        checar(linha("SELECT * FROM criterio WHERE id = %s", (crit_usado["id"],)) == crit_antes,
               "I04-05: o criterio permanece intacto no banco depois do 409")
        checar(linha("SELECT * FROM atividade WHERE id = %s", (ativ_i4["id"],)) == ativ_antes,
               "I04-06: a atividade vinculada permanece intacta")

        # --- etapa ------------------------------------------------------
        etapa_vazia = criar_etapa(coord_a, "E I04 vazia", 105, 6, 10)
        criar_criterio(coord_a, etapa_vazia["id"], "Provas", 100)
        r = coord_a.delete("/api/config/etapas/%d" % etapa_vazia["id"])
        checar(r.status_code == 204
               and linha("SELECT id FROM etapa WHERE id = %s", (etapa_vazia["id"],)) is None,
               "I04-07: excluir etapa SEM atividades (so com criterios) continua funcionando (204)")

        etapa_antes = linha("SELECT * FROM etapa WHERE id = %s", (etapa_i4["id"],))
        crits_antes = linhas("SELECT * FROM criterio WHERE etapa_id = %s ORDER BY id",
                             (etapa_i4["id"],))
        r = coord_a.delete("/api/config/etapas/%d" % etapa_i4["id"])
        checar(r.status_code == 409 and r.get_json()["error"]
               == "Esta etapa possui dados vinculados e nao pode ser excluida.",
               "I04-08: excluir etapa ABERTA com atividade -> 409 com mensagem de negocio")
        checar(limpa(r), "I04-09: a resposta da etapa nao traz SQL, constraint nem erro bruto")
        checar(linha("SELECT * FROM etapa WHERE id = %s", (etapa_i4["id"],)) == etapa_antes
               and linhas("SELECT * FROM criterio WHERE etapa_id = %s ORDER BY id",
                          (etapa_i4["id"],)) == crits_antes
               and linha("SELECT * FROM atividade WHERE id = %s", (ativ_i4["id"],)) == ativ_antes,
               "I04-10: etapa, criterios e atividade permanecem intactos depois do 409")

        # etapa FECHADA continua 400 (I-03), nao vira 409
        etapa_fech_i4 = criar_etapa(coord_a, "E I04 fechada", 106, 6, 10)
        crit_fech_i4 = criar_criterio(coord_a, etapa_fech_i4["id"], "Provas", 100)
        criar_atividade(prof_i2, turma_orig["id"], etapa_fech_i4["id"],
                        crit_fech_i4["id"], 10, "I04 em etapa fechada")
        coord_a.post("/api/config/etapas/%d/fechar" % etapa_fech_i4["id"])
        r = coord_a.delete("/api/config/etapas/%d" % etapa_fech_i4["id"])
        checar(r.status_code == 400 and "fechada" in r.get_json()["error"].lower(),
               "I04-11: etapa FECHADA (com dependencia) continua 400 por etapa fechada, nao 409")
        r = coord_a.delete("/api/config/criterios/%d" % crit_fech_i4["id"])
        checar(r.status_code == 400 and "fechada" in r.get_json()["error"].lower(),
               "I04-12: criterio de etapa fechada continua 400 por etapa fechada, nao 409")

        # --- turma ------------------------------------------------------
        turma_livre = coord_a.post("/api/classes", {"name": "I04 livre"}).get_json()
        coord_a.post("/api/coordenacao/turmas/%d/alunos" % turma_livre["id"],
                     {"nome": "Aluno Sem Transferencia"})
        r = coord_a.delete("/api/classes/%d" % turma_livre["id"])
        checar(r.status_code == 204
               and linha("SELECT id FROM turma WHERE id = %s", (turma_livre["id"],)) is None,
               "I04-13: excluir turma SEM historico de transferencia (mesmo com aluno) continua funcionando (204)")

        turma_t1 = coord_a.post("/api/classes", {"name": "I04 origem"}).get_json()
        turma_t2 = coord_a.post("/api/classes", {"name": "I04 destino"}).get_json()
        aluno_t = coord_a.post("/api/coordenacao/turmas/%d/alunos" % turma_t1["id"],
                               {"nome": "Aluno Transferido Teste"}).get_json()
        tr = coord_a.post("/api/coordenacao/alunos/%d/transferir" % aluno_t["id"],
                          {"turma_id": turma_t2["id"], "motivo": "teste I-04"})
        checar(tr.status_code == 200, "I04-14: preparo: aluno transferido da origem para o destino")
        hist_antes = linhas("SELECT * FROM aluno_turma_historico WHERE aluno_id = %s ORDER BY id",
                            (aluno_t["id"],))
        aluno_antes = linha("SELECT * FROM aluno WHERE id = %s", (aluno_t["id"],))
        turma_antes = linha("SELECT * FROM turma WHERE id = %s", (turma_t1["id"],))
        r = coord_a.delete("/api/classes/%d" % turma_t1["id"])
        checar(r.status_code == 409 and r.get_json()["error"]
               == "Esta turma possui dados historicos vinculados e nao pode ser excluida.",
               "I04-15: excluir turma de origem de aluno transferido -> 409 com mensagem de negocio")
        checar(limpa(r), "I04-16: a resposta da turma nao traz SQL, constraint nem erro bruto")
        checar(linhas("SELECT * FROM aluno_turma_historico WHERE aluno_id = %s ORDER BY id",
                      (aluno_t["id"],)) == hist_antes and len(hist_antes) == 2,
               "I04-17: o historico do aluno (2 vinculos) permanece intacto")
        checar(linha("SELECT * FROM aluno WHERE id = %s", (aluno_t["id"],)) == aluno_antes
               and linha("SELECT * FROM turma WHERE id = %s", (turma_t1["id"],)) == turma_antes,
               "I04-18: o aluno e a turma de origem permanecem intactos")

        # --- cross-school e professor ----------------------------------
        alvos = (
            ("criterio", "/api/config/criterios/%d" % crit_usado["id"]),
            ("etapa", "/api/config/etapas/%d" % etapa_i4["id"]),
            ("turma", "/api/classes/%d" % turma_t1["id"]),
        )
        for rotulo, url in alvos:
            r = coord_b.delete(url)
            checar(r.status_code == 404 and limpa(r),
                   "I04-19: escola B excluindo %s da escola A -> 404 (nao revela dependencias)" % rotulo)
            r = professor_a.delete(url)
            checar(r.status_code == 403,
                   "I04-20: professor excluindo %s -> 403" % rotulo)
        checar(linha("SELECT * FROM criterio WHERE id = %s", (crit_usado["id"],)) == crit_antes
               and linha("SELECT * FROM etapa WHERE id = %s", (etapa_i4["id"],)) == etapa_antes
               and linha("SELECT * FROM turma WHERE id = %s", (turma_t1["id"],)) == turma_antes
               and linhas("SELECT * FROM aluno_turma_historico WHERE aluno_id = %s ORDER BY id",
                          (aluno_t["id"],)) == hist_antes,
               "I04-21: nada mudou depois das tentativas cross-school e do professor")

        # ---------------------------------------------------------
        print("\n[M-01] Entradas malformadas: 400 em vez de 500")
        cid_a = query_one("SELECT id FROM coordenacao WHERE email = %s",
                          ("a." + SUFIXO,))["id"]

        def enviar(cliente, metodo, url, texto_json):
            """Corpo cru (o Cliente do teste converte [] em {} e esconderia o caso)."""
            return getattr(cliente._cliente, metodo)(
                url, data=texto_json, content_type="application/json",
                headers=cliente._cabecalhos(),
            )

        def estado_da_escola():
            """Foto exata de tudo que as requisicoes ruins poderiam gravar."""
            return {
                tabela: query_all(sql, (cid_a,))
                for tabela, sql in (
                    ("turma", "SELECT * FROM turma WHERE coordenacao_id = %s ORDER BY id"),
                    ("etapa", "SELECT * FROM etapa WHERE coordenacao_id = %s ORDER BY id"),
                    ("criterio", "SELECT * FROM criterio WHERE coordenacao_id = %s ORDER BY id"),
                    ("atividade", "SELECT * FROM atividade WHERE coordenacao_id = %s ORDER BY id"),
                    ("professor", "SELECT * FROM professor WHERE coordenacao_id = %s ORDER BY id"),
                    ("aluno", "SELECT al.* FROM aluno al INNER JOIN turma t ON t.id = al.turma_id "
                              "WHERE t.coordenacao_id = %s ORDER BY al.id"),
                    ("nota", "SELECT n.* FROM nota n INNER JOIN atividade a ON a.id = n.atividade_id "
                             "WHERE a.coordenacao_id = %s ORDER BY n.id"),
                )
            }

        def e400(resposta):
            corpo = resposta.get_json(silent=True)
            return resposta.status_code == 400 and bool(corpo and corpo.get("error"))

        etapa_m1 = criar_etapa(coord_a, "E M01", 107, 6, 10)
        etapa_m1b = criar_etapa(coord_a, "E M01 b", 108, 6, 10)
        crit_m1 = criar_criterio(coord_a, etapa_m1["id"], "Provas", 60)
        crit_m1b = criar_criterio(coord_a, etapa_m1["id"], "Trabalhos", 40)
        ativ_m1 = criar_atividade(prof_i2, turma_orig["id"], etapa_m1["id"],
                                  crit_m1["id"], 10, "M01 base")
        lancar(prof_i2, ativ_m1["id"], alunos_i2[0]["id"], 7)
        aluno_m1 = alunos_i2[0]["id"]
        turma_o = turma_orig["id"]
        antes_m1 = estado_da_escola()

        # 1-3. corpo que nao e objeto -> 400 amigavel
        alvos_corpo = (
            (coord_a, "post", "/api/classes"),
            (coord_a, "post", "/api/config/etapas"),
            (coord_a, "post", "/api/coordenacao/professores"),
            (coord_a, "post", "/api/coordenacao/turmas/%d/alunos" % turma_o),
            (prof_i2, "put", "/api/activities/%d" % ativ_m1["id"]),
            (prof_i2, "post", "/api/atividades/%d/notas" % ativ_m1["id"]),
            (Cliente(cliente_flask), "post", "/api/auth/login-coordenacao"),
        )
        for rotulo, texto_json in (("array vazio", "[]"), ("array com itens", "[1, 2]"),
                                   ("string", '"texto"'), ("numero", "5"), ("booleano", "true")):
            falhou = [url for cli, metodo, url in alvos_corpo
                      if not e400(enviar(cli, metodo, url, texto_json))]
            checar(not falhou,
                   "M01-01: corpo JSON %s -> 400 amigavel nos %d endpoints testados%s"
                   % (rotulo, len(alvos_corpo), "" if not falhou else " (falhou: %s)" % falhou))
        r = enviar(prof_i2, "post", "/api/professor/turmas/%d/atividades/gerar" % turma_o, "[]")
        checar(e400(r), "M01-02: corpo array tambem e recusado nas rotas de IA (400, sem chamar o provedor)")

        # 4-6. tipo errado em campos de texto -> 400 (nunca 500, nunca 409 de duplicidade)
        base_ativ = {"class_id": turma_o, "etapa_id": etapa_m1["id"],
                     "criterio_id": crit_m1["id"], "nota_maxima": 10}
        checar(e400(prof_i2.post("/api/activities", {**base_ativ, "title": {"a": 1}})),
               "M01-03: titulo como objeto -> 400")
        checar(e400(prof_i2.post("/api/activities", {**base_ativ, "title": ["a"]})),
               "M01-04: titulo como lista -> 400")
        checar(e400(prof_i2.post("/api/activities", {**base_ativ, "title": 123})),
               "M01-05: titulo como numero -> 400")
        checar(e400(prof_i2.put("/api/activities/%d" % ativ_m1["id"], {"title": {"a": 1}})),
               "M01-06: editar atividade com titulo objeto -> 400")
        checar(e400(prof_i2.post("/api/activities", {**base_ativ, "title": "ok",
                                                      "description": {"x": 1}})),
               "M01-07: descricao como objeto -> 400 (antes: TypeError do driver)")
        checar(e400(coord_a.post("/api/coordenacao/professores",
                                 {"nome": ["Ana"], "email": "lista.%s" % SUFIXO})),
               "M01-08: professor com nome como lista -> 400 (nao 409)")
        checar(e400(coord_a.post("/api/classes", {"name": ["x"], "ano_letivo": ANO})),
               "M01-09: turma com nome como lista -> 400 (nao 409)")
        checar(e400(coord_a.post("/api/coordenacao/turmas/%d/alunos" % turma_o,
                                 {"nome": ["Ana", "Lima"]})),
               "M01-10: aluno com nome como lista -> 400")
        checar(e400(coord_a.post("/api/coordenacao/turmas/%d/alunos" % turma_o,
                                 {"nome": "Caio Dias Neto", "matricula": {"a": 1}})),
               "M01-11: aluno com matricula como objeto -> 400")
        checar(e400(coord_a.put("/api/coordenacao/alunos/%d" % aluno_m1, {"matricula": {"a": 1}})),
               "M01-12: editar aluno com matricula objeto -> 400")
        checar(e400(coord_a.put("/api/coordenacao/alunos/%d" % aluno_m1, {"matricula": 123})),
               "M01-13: editar aluno com matricula numerica -> 400")
        checar(e400(coord_a.post("/api/config/etapas", {"nome": 123, "ordem": 120, "ano_letivo": ANO})),
               "M01-14: etapa com nome numerico -> 400")
        checar(e400(coord_a.post("/api/config/criterios/etapa/%d" % etapa_m1["id"],
                                 {"nome": {"a": 1}, "peso": 1})),
               "M01-15: criterio com nome objeto -> 400")
        checar(e400(Cliente(cliente_flask).post("/api/auth/cadastro-coordenacao",
                                                {"nome": "X", "email": 123, "senha": "123456"})),
               "M01-16: cadastro de coordenacao com e-mail numerico -> 400")
        checar(e400(Cliente(cliente_flask).post("/api/auth/cadastro-coordenacao",
                                                {"nome": "X", "email": "m01@x.com", "senha": 123456})),
               "M01-17: cadastro de coordenacao com senha numerica -> 400")
        checar(e400(Cliente(cliente_flask).post("/api/auth/login-coordenacao",
                                                {"email": ["a@b.c"], "senha": "123456"})),
               "M01-18: login com e-mail como lista -> 400")
        checar(e400(coord_a.post("/api/coordenacao/professores/%d/turmas" % prof_i2_dados["id"],
                                 {"turma_ids": 5})),
               "M01-19: vincular com turma_ids numerico -> 400")
        checar(e400(coord_a.post("/api/coordenacao/professores/%d/turmas" % prof_i2_dados["id"],
                                 {"turma_ids": [turma_o, {"a": 1}]})),
               "M01-20: vincular com item invalido em turma_ids -> 400")

        # 7-9. NaN / Infinity / valores fora do DECIMAL
        url_notas = "/api/atividades/%d/notas" % ativ_m1["id"]
        for lit in ("NaN", "Infinity", "-Infinity", '"nan"', '"inf"', "1e999", "1000", "99999999"):
            r = enviar(prof_i2, "post", url_notas,
                       '{"aluno_id": %d, "valor": %s}' % (aluno_m1, lit))
            checar(e400(r), "M01-21: nota %s -> 400" % lit)
        checar(e400(enviar(prof_i2, "post", url_notas, '{"aluno_id": Infinity, "valor": 5}')),
               "M01-22: aluno_id Infinity -> 400")
        checar(e400(enviar(prof_i2, "post", url_notas, '{"notas": [1, 2]}')),
               "M01-23: notas como lista de numeros -> 400")
        checar(e400(enviar(prof_i2, "post", url_notas, '{"notas": "x"}')),
               "M01-24: notas como texto -> 400")
        checar(e400(prof_i2.post(url_notas, {"aluno_id": aluno_m1, "valor": 5, "observacao": {"a": 1}})),
               "M01-25: observacao como objeto -> 400")
        for lit in ("NaN", "Infinity", "-Infinity", '"nan"', "1000", "1e10"):
            r = enviar(prof_i2, "post", "/api/activities",
                       '{"title": "x", "class_id": %d, "etapa_id": %d, "criterio_id": %d, '
                       '"nota_maxima": %s}' % (turma_o, etapa_m1["id"], crit_m1["id"], lit))
            checar(e400(r), "M01-26: atividade com nota_maxima %s -> 400" % lit)
        checar(e400(enviar(prof_i2, "put", "/api/activities/%d" % ativ_m1["id"], '{"nota_maxima": NaN}')),
               "M01-27: editar atividade com nota_maxima NaN -> 400")
        ep_m1 = "/api/config/etapas/%d" % etapa_m1["id"]
        for corpo, rotulo in (('{"nota_minima": NaN, "nota_maxima": 10}', "nota minima NaN"),
                              ('{"nota_minima": 6, "nota_maxima": NaN}', "nota maxima NaN"),
                              ('{"nota_minima": 6, "nota_maxima": Infinity}', "nota maxima Infinity"),
                              ('{"nota_minima": -Infinity, "nota_maxima": 10}', "nota minima -Infinity"),
                              ('{"nota_minima": 6, "nota_maxima": 1000}', "nota maxima 1000 (acima do DECIMAL)"),
                              ('{"nota_minima": "abc", "nota_maxima": 10}', "nota minima 'abc'")):
            checar(e400(enviar(coord_a, "post", ep_m1 + "/notas", corpo)),
                   "M01-28: etapa com %s -> 400" % rotulo)

        # 10-12. peso de criterio: 0 a 100
        url_crit = "/api/config/criterios/etapa/%d" % etapa_m1["id"]
        for peso, rotulo in ((-1, "-1"), (-50, "-50"), (101, "101"), (500, "500"), (1000, "1000"),
                             ("abc", "'abc'"), ([1], "lista"), ({"a": 1}, "objeto"), (True, "booleano")):
            checar(e400(coord_a.post(url_crit, {"nome": "PesoRuim", "peso": peso})),
                   "M01-30: criterio com peso %s -> 400" % rotulo)
            checar(e400(coord_a.put("/api/config/criterios/%d" % crit_m1b["id"], {"peso": peso})),
                   "M01-31: editar criterio com peso %s -> 400" % rotulo)
        for lit in ("NaN", "Infinity", "-Infinity"):
            checar(e400(enviar(coord_a, "post", url_crit, '{"nome": "PesoRuim", "peso": %s}' % lit)),
                   "M01-32: criterio com peso %s -> 400" % lit)
        checar(e400(coord_a.post(url_crit, {"nome": "NotaRuim", "peso": 1, "nota_maxima": 1000})),
               "M01-33: criterio com nota_maxima 1000 -> 400")

        # 13-14. datas
        for corpo, rotulo in (({"data_inicio": "xx"}, "data de inicio 'xx'"),
                              ({"data_fim": "2026-13-45"}, "data de fim impossivel"),
                              ({"data_inicio": 123}, "data de inicio numerica"),
                              ({"data_inicio": "2026-12-01", "data_fim": "2026-01-01"},
                               "inicio depois do fim")):
            checar(e400(coord_a.put(ep_m1, corpo)),
                   "M01-34: editar etapa com %s -> 400" % rotulo)
            checar(e400(coord_a.post("/api/config/etapas", {"nome": "D", "ordem": 121,
                                                            "ano_letivo": ANO, **corpo})),
                   "M01-35: criar etapa com %s -> 400" % rotulo)
        # 15. duplicidade esperada: 409 amigavel, nunca 500
        r = coord_a.put(ep_m1, {"ordem": etapa_m1b["ordem"]})
        checar(r.status_code == 409 and r.get_json()["error"]
               == "Ja existe uma etapa com esta ordem neste ano letivo.",
               "M01-39: ordem de etapa duplicada -> 409 amigavel (antes: IntegrityError 1062, 500)")
        r = coord_a.put("/api/config/criterios/%d" % crit_m1b["id"], {"nome": "Provas"})
        checar(r.status_code == 409 and "criterio" in r.get_json()["error"].lower(),
               "M01-41: renomear criterio para um nome ja usado na etapa -> 409 amigavel")
        for ordem, rotulo in (("abc", "'abc'"), (0, "0"), (-3, "-3"), (1001, "1001"),
                              (10 ** 12, "1000000000000"), ({"a": 1}, "objeto"), (True, "booleano")):
            checar(e400(coord_a.put(ep_m1, {"ordem": ordem})),
                   "M01-42: etapa com ordem %s -> 400" % rotulo)
        checar(e400(enviar(coord_a, "put", ep_m1, '{"ordem": Infinity}'))
               and e400(enviar(coord_a, "post", "/api/config/etapas",
                               '{"nome": "O", "ordem": Infinity, "ano_letivo": 2026}')),
               "M01-43: ordem Infinity -> 400 (editar e criar)")

        # 16. textos acima do limite da coluna
        longos = (
            ("turma: nome com 121 caracteres", coord_a.post("/api/classes", {"name": "t" * 121, "ano_letivo": ANO})),
            ("turma: disciplina com 101", coord_a.post("/api/classes", {"name": "Disc M01", "disciplina": "d" * 101, "ano_letivo": ANO})),
            ("turma: turno com 31", coord_a.post("/api/classes", {"name": "Turno M01", "turno": "t" * 31, "ano_letivo": ANO})),
            ("atividade: titulo com 201", prof_i2.post("/api/activities", {**base_ativ, "title": "x" * 201})),
            ("atividade: descricao com 16001", prof_i2.post("/api/activities", {**base_ativ, "title": "ok", "description": "d" * 16001})),
            ("aluno: nome com 151", coord_a.post("/api/coordenacao/turmas/%d/alunos" % turma_o, {"nome": "Ana " + "s" * 150})),
            ("aluno: matricula com 51", coord_a.post("/api/coordenacao/turmas/%d/alunos" % turma_o, {"nome": "Caio Dias Neto", "matricula": "m" * 51})),
            ("aluno: email com 151", coord_a.post("/api/coordenacao/turmas/%d/alunos" % turma_o, {"nome": "Caio Dias Neto", "email": "e" * 145 + "@x.com"})),
            ("nota: observacao com 256", prof_i2.post(url_notas, {"aluno_id": aluno_m1, "valor": 5, "observacao": "o" * 256})),
            ("etapa: nome com 81", coord_a.post("/api/config/etapas", {"nome": "e" * 81, "ordem": 122, "ano_letivo": ANO})),
            ("criterio: nome com 81", coord_a.post(url_crit, {"nome": "c" * 81, "peso": 1})),
            ("professor: nome com 151", coord_a.post("/api/coordenacao/professores", {"nome": "p" * 151, "email": "longo.%s" % SUFIXO})),
            ("professor: disciplina com 101", coord_a.post("/api/coordenacao/professores", {"nome": "Prof Longo", "email": "longo2.%s" % SUFIXO, "disciplina": "d" * 101})),
            ("coordenacao: nome com 151", Cliente(cliente_flask).post("/api/auth/cadastro-coordenacao", {"nome": "n" * 151, "email": "longo.coord.%s" % SUFIXO, "senha": "123456"})),
        )
        for rotulo, resposta in longos:
            checar(e400(resposta), "M01-44: %s -> 400" % rotulo)

        # 17. nada foi gravado, nem parcialmente
        checar(estado_da_escola() == antes_m1,
               "M01-45: nenhuma das requisicoes invalidas gravou nada (turma, etapa, criterio, "
               "atividade, aluno, nota e professor identicos, linha a linha)")

        # os limites exatos e entradas validas continuam funcionando
        checar(coord_a.put(ep_m1, {"data_inicio": "2026-03-01", "data_fim": "2026-05-31"}).status_code == 200,
               "M01-36: datas validas continuam funcionando (200)")
        checar(e400(coord_a.put(ep_m1, {"data_fim": "2026-02-01"})),
               "M01-37: mudar so a data de fim para antes do inicio ja gravado -> 400")
        checar(e400(coord_a.put(ep_m1, {"data_inicio": "2026-09-01"})),
               "M01-38: mudar so a data de inicio para depois do fim ja gravado -> 400")

        checar(coord_a.put(ep_m1, {"ordem": etapa_m1["ordem"]}).status_code == 200,
               "M01-40: reenviar a propria ordem continua funcionando")
        checar(coord_a.post(url_crit, {"nome": "Peso zero", "peso": 0}).status_code == 201
               and coord_a.post(url_crit, {"nome": "Peso cem", "peso": 100}).status_code == 201
               and coord_a.post(url_crit, {"nome": "Peso virgula", "peso": "33,5"}).status_code == 201,
               "M01-46: pesos 0, 100 e '33,5' continuam validos")
        checar(coord_a.post(ep_m1 + "/notas", {"nota_minima": 5.5, "nota_maxima": "10,0"}).status_code == 200
               and coord_a.post(ep_m1 + "/notas", {"nota_minima": 60, "nota_maxima": 100}).status_code == 200,
               "M01-47: notas minima/maxima validas (inclusive com virgula) continuam funcionando")
        r = prof_i2.post("/api/activities", {**base_ativ, "title": "M01 valida", "nota_maxima": "12,5",
                                              "due_date": "2026-11-20", "description": "d" * 16000})
        checar(r.status_code == 201 and r.get_json()["nota_maxima"] == 12.5,
               "M01-48: atividade valida (valor com virgula, data, descricao no limite) continua funcionando")
        checar(prof_i2.post(url_notas, {"aluno_id": aluno_m1, "valor": "8,5", "observacao": "o" * 255}).status_code == 201,
               "M01-49: nota valida (virgula, observacao no limite) continua funcionando")
        checar(coord_a.post("/api/config/etapas", {"nome": "Datas", "ordem": 123, "ano_letivo": ANO,
                                                    "data_inicio": "2026-02-01", "data_fim": "2026-04-30"}
                            ).status_code == 201,
               "M01-50: etapa com datas validas continua funcionando")

        # --- handler de erro 500: resposta generica, log preservado
        import logging
        registros = []

        class _Captura(logging.Handler):
            def emit(self, registro):
                registros.append(registro)

        app_erro = app_module.create_app()
        app_erro.config["TESTING"] = False
        app_erro.config["PROPAGATE_EXCEPTIONS"] = False
        app_erro.add_url_rule("/api/_teste_erro", "teste_erro", lambda: 1 / 0)

        def _erro_de_banco():
            import pymysql
            raise pymysql.err.DataError(1406, "Data too long for column 'nome' at row 1")

        app_erro.add_url_rule("/api/_teste_erro_banco", "teste_erro_banco", _erro_de_banco)
        captura = _Captura()
        # So a captura: o handler padrao imprimiria os tracebacks esperados.
        from flask.logging import default_handler
        app_erro.logger.removeHandler(default_handler)
        app_erro.logger.addHandler(captura)
        with app_erro.test_client() as cliente_erro:
            r = cliente_erro.get("/api/_teste_erro")
            checar(r.status_code == 500 and r.get_json() == {"error": "Erro interno do servidor."},
                   "M01-51: erro interno devolve JSON generico (nao HTML)")
            r2 = cliente_erro.get("/api/_teste_erro_banco")
            texto_resposta = r2.get_data(as_text=True)
            checar(r2.status_code == 500 and "Data too long" not in texto_resposta
                   and "1406" not in texto_resposta and "ZeroDivision" not in r.get_data(as_text=True),
                   "M01-52: a resposta nao expoe erro do banco, excecao nem stack")
            checar(any(reg.exc_info and isinstance(reg.exc_info[1], ZeroDivisionError)
                       for reg in registros)
                   and any(reg.exc_info and "Data too long" in str(reg.exc_info[1])
                           for reg in registros),
                   "M01-53: a excecao original continua registrada no log (diagnostico preservado)")
            checar(cliente_erro.get("/api/rota-que-nao-existe").status_code == 404
                   and cliente_erro.delete("/api/auth/login-coordenacao").status_code == 405,
                   "M01-54: erros conhecidos (404, 405) nao viram 500")
            checar(cliente_erro.post("/api/auth/login-coordenacao", json=[1]).status_code == 400
                   and cliente_erro.post("/api/classes").status_code == 401,
                   "M01-55: 400 e 401 seguem como antes")
        app_erro.logger.removeHandler(captura)

        # ---------------------------------------------------------
        print("\n[M-02] Ano encerrado e historico somente leitura")
        ano_m2 = 2040
        r = coord_a.post("/api/config/anos-letivos", {"ano": ano_m2})
        id_ano_m2 = r.get_json()["id"]
        etapa_m2 = coord_a.post("/api/config/etapas", {
            "nome": "E M02", "ordem": 1, "ano_letivo": ano_m2}).get_json()
        coord_a.post("/api/config/etapas/%d/notas" % etapa_m2["id"],
                     {"nota_minima": 6, "nota_maxima": 10})
        crit_m2 = criar_criterio(coord_a, etapa_m2["id"], "Provas", 100)
        turma_m2 = coord_a.post("/api/classes", {"name": "M02 Turma 2040",
                                                 "ano_letivo": ano_m2}).get_json()
        alunos_m2 = [
            coord_a.post("/api/coordenacao/turmas/%d/alunos" % turma_m2["id"],
                         {"nome": nome, "matricula": mat}).get_json()
            for nome, mat in (("Ana Historica Silva", "H1"), ("Bia Historica Costa", "H2"))
        ]
        coord_a.post(
            "/api/coordenacao/professores/%d/turmas" % prof_i2_dados["id"],
            {"turma_ids": [turma_orig["id"], turma_dest["id"], turma_outro_ano["id"],
                           turma_m2["id"]]},
        )
        ativ_m2 = criar_atividade(prof_i2, turma_m2["id"], etapa_m2["id"],
                                  crit_m2["id"], 10, "M02 atividade")
        lancar(prof_i2, ativ_m2["id"], alunos_m2[0]["id"], 8)
        nota_m2 = query_one("SELECT id FROM nota WHERE atividade_id = %s AND aluno_id = %s",
                            (ativ_m2["id"], alunos_m2[0]["id"]))["id"]
        # aluno de ano aberto, para o teste de transferencia PARA ano encerrado
        aluno_aberto = coord_a.post(
            "/api/coordenacao/turmas/%d/alunos" % turma_orig["id"],
            {"nome": "Caio Ano Aberto", "matricula": "AB1"}).get_json()

        # controle: com o ano ainda em planejamento tudo funciona
        checar(coord_a.put("/api/classes/%d" % turma_m2["id"],
                           {"description": "ano em planejamento"}).status_code == 200
               and coord_a.put("/api/config/etapas/%d" % etapa_m2["id"],
                               {"nome": "E M02 (planejamento)"}).status_code == 200,
               "M02-01: ano em PLANEJAMENTO continua aceitando edicao de turma e etapa")
        status_2026 = ano_por_numero(coord_a, ANO)["status"]
        checar(status_2026 in ("atual", "planejamento")
               and coord_a.put("/api/classes/%d" % turma_orig["id"],
                               {"description": "ano nao encerrado"}).status_code == 200,
               "M02-02: turma de ano nao encerrado (%s) continua editavel" % status_2026)

        def estado_m2():
            """Foto exata das tabelas do cenario, escopo da escola A."""
            return {
                tabela: query_all(sql, (cid_a,))
                for tabela, sql in (
                    ("turma", "SELECT * FROM turma WHERE coordenacao_id = %s ORDER BY id"),
                    ("aluno", "SELECT al.* FROM aluno al INNER JOIN turma t ON t.id = al.turma_id "
                              "WHERE t.coordenacao_id = %s ORDER BY al.id"),
                    ("etapa", "SELECT * FROM etapa WHERE coordenacao_id = %s ORDER BY id"),
                    ("criterio", "SELECT * FROM criterio WHERE coordenacao_id = %s ORDER BY id"),
                    ("atividade", "SELECT * FROM atividade WHERE coordenacao_id = %s ORDER BY id"),
                    ("nota", "SELECT n.* FROM nota n INNER JOIN atividade a ON a.id = n.atividade_id "
                             "WHERE a.coordenacao_id = %s ORDER BY n.id"),
                    ("historico", "SELECT * FROM aluno_turma_historico WHERE coordenacao_id = %s ORDER BY id"),
                )
            }

        # encerra o ano
        checar(coord_a.put("/api/config/anos-letivos/%d" % id_ano_m2,
                           {"status": "encerrado"}).status_code == 200,
               "M02-03: coordenacao encerra o ano 2040")
        antes_m2 = estado_m2()

        def bloqueado(resposta):
            corpo = resposta.get_json(silent=True) or {}
            return (resposta.status_code == 400
                    and "encerrado" in (corpo.get("error") or "").lower())

        # ---- leitura continua liberada
        leituras = (
            ("turma", coord_a.get("/api/classes/%d" % turma_m2["id"])),
            ("lista de turmas do ano", coord_a.get("/api/classes?ano_letivo=%d" % ano_m2)),
            ("alunos (coordenacao)", coord_a.get("/api/coordenacao/turmas/%d/alunos" % turma_m2["id"])),
            ("alunos (professor)", prof_i2.get("/api/professor/turmas/%d/alunos" % turma_m2["id"])),
            ("historico do aluno", coord_a.get("/api/coordenacao/alunos/%d/historico" % alunos_m2[0]["id"])),
            ("atividades", prof_i2.get("/api/activities?class_id=%d" % turma_m2["id"])),
            ("atividade", prof_i2.get("/api/activities/%d" % ativ_m2["id"])),
            ("notas da atividade", prof_i2.get("/api/atividades/%d/notas" % ativ_m2["id"])),
            ("boletim (coordenacao)", coord_a.get("/api/coordenacao/turmas/%d/boletim" % turma_m2["id"])),
            ("boletim (professor)", prof_i2.get("/api/professor/turmas/%d/boletim" % turma_m2["id"])),
            ("desempenho do aluno", prof_i2.get("/api/professor/alunos/%d/estatisticas" % alunos_m2[0]["id"])),
            ("etapas do ano", coord_a.get("/api/config/etapas?ano_letivo=%d" % ano_m2)),
            ("etapa", coord_a.get("/api/config/etapas/%d" % etapa_m2["id"])),
            ("criterios", coord_a.get("/api/config/criterios/etapa/%d" % etapa_m2["id"])),
        )
        for rotulo, resposta in leituras:
            checar(resposta.status_code == 200, "M02-04: leitura em ano encerrado continua 200 (%s)" % rotulo)
        checar(any(n["valor"] == 8 for n in leituras[7][1].get_json()["notas"] if n["valor"] is not None)
               and leituras[8][1].get_json()["alunos"][0]["etapas"][0]["situacao"] == "adequado",
               "M02-05: o historico segue visivel e calculado (nota 8 -> adequado)")

        # ---- turma
        checar(bloqueado(coord_a.put("/api/classes/%d" % turma_m2["id"], {"name": "Renomeada"})),
               "M02-06: editar turma de ano encerrado -> 400")
        checar(bloqueado(coord_a.delete("/api/classes/%d" % turma_m2["id"])),
               "M02-07: excluir turma de ano encerrado -> 400 (sem cascata)")
        r = coord_a.post("/api/classes", {"name": "M02 nova turma", "ano_letivo": ano_m2})
        checar(r.status_code == 409 and "encerrado" in r.get_json()["error"].lower(),
               "M02-08: criar turma em ano encerrado continua bloqueada (409, como validado no Marco 6)")

        # ---- aluno
        checar(bloqueado(coord_a.post("/api/coordenacao/turmas/%d/alunos" % turma_m2["id"],
                                      {"nome": "Novo Aluno Teste"})),
               "M02-09: cadastrar aluno em turma de ano encerrado (coordenacao) -> 400")
        checar(bloqueado(prof_i2.post("/api/professor/turmas/%d/alunos" % turma_m2["id"],
                                      {"nome": "Novo Aluno Teste"})),
               "M02-10: cadastrar aluno em turma de ano encerrado (professor) -> 400")
        checar(bloqueado(coord_a.upload("/api/coordenacao/turmas/%d/alunos/importar" % turma_m2["id"],
                                        "alunos.csv", b"nome\nAluno Importado Teste\n")),
               "M02-11: importar alunos para turma de ano encerrado -> 400")
        checar(bloqueado(coord_a.put("/api/coordenacao/alunos/%d" % alunos_m2[0]["id"],
                                     {"nome": "Ana Renomeada Silva"})),
               "M02-12: editar aluno (nome) de turma de ano encerrado -> 400 (decisao: aluno e historico)")
        checar(bloqueado(coord_a.put("/api/coordenacao/alunos/%d" % alunos_m2[0]["id"],
                                     {"matricula": "H9"}))
               and bloqueado(prof_i2.put("/api/professor/alunos/%d" % alunos_m2[0]["id"],
                                         {"email": "ana@escola.com"})),
               "M02-13: editar matricula/e-mail do aluno (coordenacao e professor) -> 400")
        checar(bloqueado(coord_a.delete("/api/coordenacao/alunos/%d" % alunos_m2[1]["id"]))
               and bloqueado(prof_i2.delete("/api/professor/alunos/%d" % alunos_m2[1]["id"])),
               "M02-14: excluir aluno de turma de ano encerrado (coordenacao e professor) -> 400")

        # ---- etapa e criterio (etapa ABERTA: o ano encerrado vale mesmo assim)
        ep_m2 = "/api/config/etapas/%d" % etapa_m2["id"]
        checar(coord_a.get(ep_m2).get_json()["fechada"] is False,
               "M02-15: a etapa do teste esta ABERTA (nao e a regra do I-03 que bloqueia)")
        checar(bloqueado(coord_a.post("/api/config/etapas", {"nome": "E nova", "ordem": 2, "ano_letivo": ano_m2})),
               "M02-16: criar etapa em ano encerrado -> 400")
        checar(bloqueado(coord_a.post("/api/config/etapas", {"nome": "Reconfig", "ordem": 1, "ano_letivo": ano_m2})),
               "M02-17: reconfigurar (upsert) etapa existente de ano encerrado -> 400")
        checar(bloqueado(coord_a.put(ep_m2, {"nome": "Outro nome"})),
               "M02-18: editar etapa de ano encerrado -> 400")
        checar(bloqueado(coord_a.post(ep_m2 + "/notas", {"nota_minima": 5, "nota_maxima": 10})),
               "M02-19: alterar notas minima/maxima de etapa de ano encerrado -> 400")
        checar(bloqueado(coord_a.delete(ep_m2)),
               "M02-20: excluir etapa de ano encerrado -> 400")
        checar(bloqueado(coord_a.post("/api/config/criterios/etapa/%d" % etapa_m2["id"],
                                      {"nome": "Novo criterio", "peso": 10})),
               "M02-21: criar criterio em etapa de ano encerrado -> 400")
        checar(bloqueado(coord_a.put("/api/config/criterios/%d" % crit_m2["id"], {"peso": 50})),
               "M02-22: editar criterio de ano encerrado -> 400")
        checar(bloqueado(coord_a.delete("/api/config/criterios/%d" % crit_m2["id"])),
               "M02-23: excluir criterio de ano encerrado -> 400")

        # ---- atividade e nota
        checar(bloqueado(prof_i2.post("/api/activities", {
            "title": "Nova", "class_id": turma_m2["id"], "etapa_id": etapa_m2["id"],
            "criterio_id": crit_m2["id"], "nota_maxima": 10})),
               "M02-24: criar atividade em turma de ano encerrado -> 400")
        checar(bloqueado(prof_i2.put("/api/activities/%d" % ativ_m2["id"], {"title": "Outro"})),
               "M02-25: editar atividade de ano encerrado -> 400")
        checar(bloqueado(prof_i2.put("/api/activities/%d" % ativ_m2["id"], {"class_id": turma_dest["id"]})),
               "M02-26: mover atividade de ano encerrado para outra turma -> 400")
        checar(bloqueado(prof_i2.delete("/api/activities/%d" % ativ_m2["id"])),
               "M02-27: excluir atividade de ano encerrado -> 400")
        checar(bloqueado(lancar(prof_i2, ativ_m2["id"], alunos_m2[1]["id"], 5)),
               "M02-28: lancar nota nova em ano encerrado -> 400")
        checar(bloqueado(lancar(prof_i2, ativ_m2["id"], alunos_m2[0]["id"], 3)),
               "M02-29: editar nota existente em ano encerrado -> 400")
        checar(bloqueado(prof_i2.delete("/api/professor/notas/%d" % nota_m2)),
               "M02-30: excluir nota em ano encerrado -> 400")
        checar(bloqueado(prof_i2.upload("/api/atividades/%d/notas/importar" % ativ_m2["id"],
                                        "notas.csv", b"matricula,nota\nH1,5\n")),
               "M02-31: importar notas em ano encerrado -> 400")

        # ---- transferencia
        r = coord_a.post("/api/coordenacao/alunos/%d/transferir" % aluno_aberto["id"],
                         {"turma_id": turma_m2["id"]})
        checar(r.status_code == 400 and "encerrado" in r.get_json()["error"].lower(),
               "M02-32: transferir aluno PARA turma de ano encerrado continua recusado (400)")

        # ---- cross-school e papel: o status do ano da escola A nao vaza
        for rotulo, resposta in (
            ("editar turma", coord_b.put("/api/classes/%d" % turma_m2["id"], {"name": "x"})),
            ("excluir turma", coord_b.delete("/api/classes/%d" % turma_m2["id"])),
            ("cadastrar aluno", coord_b.post("/api/coordenacao/turmas/%d/alunos" % turma_m2["id"], {"nome": "Zé Silva"})),
            ("editar aluno", coord_b.put("/api/coordenacao/alunos/%d" % alunos_m2[0]["id"], {"nome": "Zé Silva"})),
            ("excluir aluno", coord_b.delete("/api/coordenacao/alunos/%d" % alunos_m2[0]["id"])),
            ("editar etapa", coord_b.put(ep_m2, {"nome": "x"})),
            ("excluir criterio", coord_b.delete("/api/config/criterios/%d" % crit_m2["id"])),
            ("editar atividade", professor_b.put("/api/activities/%d" % ativ_m2["id"], {"title": "x"})),
            ("excluir atividade", professor_b.delete("/api/activities/%d" % ativ_m2["id"])),
            ("lancar nota", lancar(professor_b, ativ_m2["id"], alunos_m2[0]["id"], 1)),
            ("excluir nota", professor_b.delete("/api/professor/notas/%d" % nota_m2)),
        ):
            checar(resposta.status_code == 404
                   and "encerrado" not in resposta.get_data(as_text=True).lower(),
                   "M02-33: escola B, %s do ano encerrado da escola A -> 404 (sem revelar o status)" % rotulo)
        checar(prof_i2.put("/api/classes/%d" % turma_m2["id"], {"name": "x"}).status_code == 403
               and prof_i2.delete("/api/config/etapas/%d" % etapa_m2["id"]).status_code == 403,
               "M02-34: professor continua recebendo 403 nas rotas da coordenacao")

        # ---- integridade
        checar(estado_m2() == antes_m2,
               "M02-35: nada mudou (turma, aluno, etapa, criterio, atividade, nota e "
               "historico identicos, linha a linha, depois de todas as tentativas)")

        # ---- a regra acompanha o status do ano: reabrindo, volta a funcionar
        checar(coord_a.put("/api/config/anos-letivos/%d" % id_ano_m2,
                           {"status": "planejamento"}).status_code == 200,
               "M02-36: coordenacao volta o ano 2040 para planejamento")
        checar(coord_a.put("/api/classes/%d" % turma_m2["id"], {"description": "reaberto"}).status_code == 200
               and coord_a.post("/api/coordenacao/turmas/%d/alunos" % turma_m2["id"],
                                {"nome": "Aluno Reaberto Teste"}).status_code == 201
               and coord_a.put(ep_m2, {"nome": "E M02 (reaberta)"}).status_code == 200
               and prof_i2.put("/api/activities/%d" % ativ_m2["id"], {"title": "M02 reaberta"}).status_code == 200
               and lancar(prof_i2, ativ_m2["id"], alunos_m2[1]["id"], 5).status_code == 201,
               "M02-37: fora do encerrado, turma, aluno, etapa, atividade e nota voltam a aceitar escrita")

        # ---- transferencia a PARTIR de ano encerrado continua permitida (promocao)
        coord_a.put("/api/config/anos-letivos/%d" % id_ano_m2, {"status": "encerrado"})
        r = coord_a.post("/api/coordenacao/alunos/%d/transferir" % alunos_m2[0]["id"],
                         {"turma_id": turma_dest["id"], "motivo": "promocao"})
        hist = coord_a.get("/api/coordenacao/alunos/%d/historico" % alunos_m2[0]["id"]).get_json()
        checar(r.status_code == 200 and len(hist) == 2 and hist[0]["atual"] is True
               and hist[1]["anoLetivo"] == ano_m2 and hist[1]["atual"] is False,
               "M02-38: transferir um aluno A PARTIR de turma de ano encerrado continua permitido "
               "(caminho de promocao) e o historico do ano encerrado e preservado")

        # ---------------------------------------------------------
        print("\n[M-03] Atividade com notas: etapa, criterio e valor ficam congelados")
        etapa_m3 = criar_etapa(coord_a, "E M03", 109, 6, 10)
        etapa_m3b = criar_etapa(coord_a, "E M03 b", 110, 6, 10)
        crit_m3 = criar_criterio(coord_a, etapa_m3["id"], "Provas", 50)
        crit_m3x = criar_criterio(coord_a, etapa_m3["id"], "Trabalhos", 50)
        crit_m3b = criar_criterio(coord_a, etapa_m3b["id"], "Provas", 100)
        turma_m3 = turma_orig["id"]
        al_m3 = alunos_i2  # Ana Mover Silva e Bia Mover Costa, da turma_orig

        def nova_m3(titulo, valor=10, etapa=None, crit=None):
            return criar_atividade(prof_i2, turma_m3, (etapa or etapa_m3)["id"],
                                   (crit or crit_m3)["id"], valor, titulo)

        def put_m3(atividade, corpo, cliente=None):
            return (cliente or prof_i2).put("/api/activities/%d" % atividade["id"], corpo)

        def msg_m3(resposta):
            return (resposta.get_json(silent=True) or {}).get("error", "")

        def bloqueou_m3(resposta):
            return (resposta.status_code == 400
                    and "notas lancadas" in msg_m3(resposta).lower())

        # 8. atividade SEM notas altera tudo normalmente
        sem = nova_m3("M03 sem notas")
        r = put_m3(sem, {"etapa_id": etapa_m3b["id"], "criterio_id": crit_m3b["id"]})
        checar(r.status_code == 200 and r.get_json()["etapa_id"] == etapa_m3b["id"]
               and r.get_json()["criterio_id"] == crit_m3b["id"],
               "M03-01: atividade SEM notas troca de etapa (e criterio) -> 200")
        r = put_m3(sem, {"etapa_id": etapa_m3["id"], "criterio_id": crit_m3["id"]})
        r2 = put_m3(sem, {"criterio_id": crit_m3x["id"]})
        checar(r.status_code == 200 and r2.status_code == 200
               and r2.get_json()["criterio_id"] == crit_m3x["id"],
               "M03-02: atividade SEM notas troca de criterio dentro da etapa -> 200")
        r = put_m3(sem, {"nota_maxima": 20})
        checar(r.status_code == 200 and r.get_json()["nota_maxima"] == 20.0,
               "M03-03: atividade SEM notas altera o valor maximo (aumentar) -> 200")
        r = put_m3(sem, {"nota_maxima": 5})
        checar(r.status_code == 200 and r.get_json()["nota_maxima"] == 5.0,
               "M03-04: atividade SEM notas altera o valor maximo (diminuir) -> 200")

        # atividades com notas
        com = nova_m3("M03 com notas")
        lancar(prof_i2, com["id"], al_m3[0]["id"], 8)
        lancar(prof_i2, com["id"], al_m3[1]["id"], 3)
        zero = nova_m3("M03 so nota zero")
        lancar(prof_i2, zero["id"], al_m3[0]["id"], 0)

        def foto_atividade(atividade_id):
            return (
                query_one("SELECT * FROM atividade WHERE id = %s", (atividade_id,)),
                query_all("SELECT * FROM nota WHERE atividade_id = %s ORDER BY id",
                          (atividade_id,)),
            )

        def foto_resultados():
            """Boletim da turma e desempenho de cada aluno, como o Professor ve."""
            # Do desempenho entra so o que e calculo (a lista de notas traz o
            # titulo e a data da atividade, que o teste edita de proposito).
            desempenho = []
            for a in al_m3:
                est = prof_i2.get("/api/professor/alunos/%d/estatisticas" % a["id"]).get_json()
                desempenho.append({k: est[k] for k in
                                   ("etapas", "consolidado", "media", "totalNotas")})
            return (
                prof_i2.get("/api/professor/turmas/%d/boletim" % turma_m3).get_json(),
                desempenho,
            )

        antes_com, antes_zero = foto_atividade(com["id"]), foto_atividade(zero["id"])
        resultados_antes = foto_resultados()
        checar(len(resultados_antes[0]["alunos"]) >= 2
               and all(est["etapas"] for est in resultados_antes[1]),
               "M03-05: preparo: boletim e desempenho consultados antes das tentativas")

        # 4-7. tentativas de mudar o contexto das notas -> 400
        checar(bloqueou_m3(put_m3(com, {"etapa_id": etapa_m3b["id"], "criterio_id": crit_m3b["id"]})),
               "M03-06: com nota, trocar a etapa -> 400 amigavel")
        checar(bloqueou_m3(put_m3(com, {"criterio_id": crit_m3x["id"]})),
               "M03-07: com nota, trocar o criterio -> 400 amigavel")
        r = put_m3(com, {"nota_maxima": 20})
        checar(bloqueou_m3(r), "M03-08: com nota, AUMENTAR o valor maximo (10 -> 20) -> 400 amigavel")
        r = put_m3(com, {"nota_maxima": 5})
        checar(bloqueou_m3(r), "M03-09: com nota, DIMINUIR o valor maximo (10 -> 5) -> 400")
        checar(bloqueou_m3(put_m3(com, {"nota_maxima": 8})) and bloqueou_m3(put_m3(com, {"nota_maxima": 10.5})),
               "M03-10: bloqueia mesmo quando todas as notas ainda caberiam no novo limite (8 e 10,5)")
        checar(bloqueou_m3(put_m3(com, {"nota_maxima": "20,0", "title": "tentativa mista"})),
               "M03-11: pedido misto (titulo + valor novo) tambem e recusado por inteiro")
        # 8. nota zero conta
        checar(bloqueou_m3(put_m3(zero, {"nota_maxima": 20}))
               and bloqueou_m3(put_m3(zero, {"etapa_id": etapa_m3b["id"], "criterio_id": crit_m3b["id"]}))
               and bloqueou_m3(put_m3(zero, {"criterio_id": crit_m3x["id"]})),
               "M03-12: uma unica nota de valor ZERO tambem congela etapa, criterio e valor")
        checar("etapa" in msg_m3(put_m3(com, {"nota_maxima": 20})).lower()
               and "sql" not in msg_m3(put_m3(com, {"nota_maxima": 20})).lower(),
               "M03-13: a mensagem e de negocio (cita os dados congelados, sem termo tecnico)")

        # 15-16. nada mudou
        checar(foto_atividade(com["id"]) == antes_com and foto_atividade(zero["id"]) == antes_zero,
               "M03-14: atividade e notas identicas (linha a linha, inclusive updated_at) depois das tentativas")
        checar(foto_resultados() == resultados_antes,
               "M03-15: boletim e desempenho dos alunos identicos depois das tentativas")

        # 9-14. o que continua permitido
        r = put_m3(com, {"title": "M03 com notas (titulo novo)"})
        checar(r.status_code == 200 and r.get_json()["title"] == "M03 com notas (titulo novo)",
               "M03-16: com nota, editar o titulo -> 200")
        r = put_m3(com, {"description": "descricao nova"})
        checar(r.status_code == 200 and r.get_json()["description"] == "descricao nova",
               "M03-17: com nota, editar a descricao -> 200")
        r = put_m3(com, {"due_date": "2026-12-15"})
        checar(r.status_code == 200 and r.get_json()["due_date"].startswith("2026-12-15"),
               "M03-18: com nota, editar a data de entrega -> 200")
        checar(put_m3(com, {"etapa_id": etapa_m3["id"]}).status_code == 200
               and put_m3(com, {"criterio_id": crit_m3["id"]}).status_code == 200
               and put_m3(com, {"etapa_id": str(etapa_m3["id"]), "criterio_id": crit_m3["id"]}).status_code == 200,
               "M03-19: reenviar a MESMA etapa e o MESMO criterio (int ou texto) -> 200")
        checar(all(put_m3(com, {"nota_maxima": valor}).status_code == 200
                   for valor in (10, 10.0, "10", "10,0")),
               "M03-20: reenviar o MESMO valor maximo (10, 10.0, '10', '10,0') -> 200")
        r = put_m3(com, {"class_id": turma_m3, "etapa_id": etapa_m3["id"],
                         "criterio_id": crit_m3["id"], "nota_maxima": 10,
                         "title": "M03 tudo igual, so titulo"})
        checar(r.status_code == 200 and r.get_json()["title"] == "M03 tudo igual, so titulo",
               "M03-21: reenviar turma, etapa, criterio e valor iguais + novo titulo -> 200")
        r = put_m3(com, {"class_id": turma_dest["id"]})
        checar(r.status_code == 400 and "outra turma" in msg_m3(r).lower(),
               "M03-22: trocar a turma continua recusado com a mensagem propria do I-02")
        antes_depois = foto_atividade(com["id"])
        checar([n for n in antes_depois[1]] == antes_com[1],
               "M03-23: as notas seguem identicas depois das edicoes permitidas")
        checar(foto_resultados() == resultados_antes,
               "M03-24: boletim e desempenho seguem identicos depois das edicoes permitidas")

        # 20. cross-school e professor sem vinculo: 404, sem revelar se ha notas
        for rotulo, corpo in (("valor", {"nota_maxima": 20}),
                              ("etapa de outra escola", {"etapa_id": 1, "criterio_id": 1}),
                              ("titulo", {"title": "x"})):
            r = put_m3(com, corpo, professor_b)
            checar(r.status_code == 404 and "notas" not in msg_m3(r).lower(),
                   "M03-25: professor de OUTRA escola editando atividade com notas (%s) -> 404" % rotulo)
        prof_sv = ativar_professor(coord_a.post("/api/coordenacao/professores", {
            "nome": "Professor Sem Vinculo", "email": "prof.sv.%s" % SUFIXO,
        }).get_json())
        r = put_m3(com, {"nota_maxima": 20}, prof_sv)
        checar(r.status_code == 404 and "notas" not in msg_m3(r).lower(),
               "M03-26: professor da escola SEM vinculo com a turma -> 404 (nao descobre as notas)")
        checar(put_m3(com, {"nota_maxima": 20}, coord_a).status_code == 403,
               "M03-27: coordenacao continua sem poder editar atividade (403)")
        checar(foto_atividade(com["id"])[1] == antes_com[1],
               "M03-28: nada mudou depois das tentativas cross-school, sem vinculo e da coordenacao")

        # 17. etapa fechada continua bloqueando (I-03)
        fech = nova_m3("M03 em etapa a fechar", etapa=etapa_m3b, crit=crit_m3b)
        lancar(prof_i2, fech["id"], al_m3[0]["id"], 6)
        coord_a.post("/api/config/etapas/%d/fechar" % etapa_m3b["id"])
        r = put_m3(fech, {"title": "titulo em etapa fechada"})
        checar(r.status_code == 400 and "fechada" in msg_m3(r).lower(),
               "M03-29: etapa fechada continua bloqueando ate o titulo (mensagem da etapa fechada)")
        coord_a.post("/api/config/etapas/%d/reabrir" % etapa_m3b["id"])
        checar(put_m3(fech, {"title": "titulo apos reabrir"}).status_code == 200
               and bloqueou_m3(put_m3(fech, {"nota_maxima": 30})),
               "M03-30: reaberta a etapa, o titulo volta a ser editavel e o valor segue congelado pelas notas")

        # 18. ano encerrado continua bloqueando (M-02)
        ano_m3 = coord_a.post("/api/config/anos-letivos", {"ano": 2041}).get_json()
        etapa_m3y = coord_a.post("/api/config/etapas", {"nome": "E M03 y", "ordem": 1,
                                                        "ano_letivo": 2041}).get_json()
        coord_a.post("/api/config/etapas/%d/notas" % etapa_m3y["id"], {"nota_minima": 6, "nota_maxima": 10})
        crit_m3y = criar_criterio(coord_a, etapa_m3y["id"], "Provas", 100)
        turma_m3y = coord_a.post("/api/classes", {"name": "M03 Turma 2041", "ano_letivo": 2041}).get_json()
        aluno_m3y = coord_a.post("/api/coordenacao/turmas/%d/alunos" % turma_m3y["id"],
                                 {"nome": "Aluno Anual Teste"}).get_json()
        coord_a.post("/api/coordenacao/professores/%d/turmas" % prof_i2_dados["id"],
                     {"turma_ids": [turma_orig["id"], turma_dest["id"], turma_outro_ano["id"],
                                    turma_m2["id"], turma_m3y["id"]]})
        ativ_y = criar_atividade(prof_i2, turma_m3y["id"], etapa_m3y["id"], crit_m3y["id"], 10, "M03 ano")
        lancar(prof_i2, ativ_y["id"], aluno_m3y["id"], 7)
        coord_a.put("/api/config/anos-letivos/%d" % ano_m3["id"], {"status": "encerrado"})
        r = put_m3(ativ_y, {"title": "titulo em ano encerrado"})
        checar(r.status_code == 400 and "encerrado" in msg_m3(r).lower(),
               "M03-31: ano encerrado continua bloqueando a edicao (mensagem do ano encerrado)")

        # ---------------------------------------------------------
        print("\n[M-06] Codigo e token so aparecem com DEV_EXPOSE_AUTH_CODES")
        import contextlib
        import smtplib
        import config as config_module
        from services import email_service

        class _SmtpFalso:
            """Nenhum email real: guarda o que seria enviado, ou falha."""
            enviados = []
            falhar = False

            def __init__(self, *args, **kwargs):
                pass

            def __enter__(self):
                return self

            def __exit__(self, *args):
                return False

            def starttls(self):
                pass

            def login(self, *args):
                pass

            def send_message(self, mensagem):
                if _SmtpFalso.falhar:
                    raise smtplib.SMTPException("falha simulada")
                _SmtpFalso.enviados.append(mensagem)

        def cenario_m6(dev, smtp, falhar=False):
            """Contexto: interruptor de dev, SMTP configurado ou nao, SMTP falso."""
            pilha = contextlib.ExitStack()
            pilha.enter_context(patch.object(config_module, "DEV_EXPOSE_AUTH_CODES", dev))
            pilha.enter_context(patch.dict(
                email_service.SMTP_CONFIG, {"host": "smtp.invalido.test" if smtp else ""}))
            pilha.enter_context(patch.object(email_service.smtplib, "SMTP", _SmtpFalso))
            _SmtpFalso.enviados = []
            _SmtpFalso.falhar = falhar
            return pilha

        def convite_no_banco(email):
            return query_one("SELECT convite_token FROM professor WHERE email = %s",
                             (email,))["convite_token"]

        def codigo_no_banco(email):
            return query_one("SELECT codigo FROM codigo_verificacao WHERE email = %s "
                             "ORDER BY id DESC LIMIT 1", (email,))["codigo"]

        def corpo_de(mensagem):
            return mensagem.get_content()

        def rodar_cenario(rotulo, dev, smtp, falhar=False):
            """Cadastra professor, reenvia o convite e pede um codigo. Devolve tudo."""
            sufixo = "%s.%s" % (rotulo, SUFIXO)
            saida = io.StringIO()
            with cenario_m6(dev, smtp, falhar), contextlib.redirect_stdout(saida):
                cadastro = coord_a.post("/api/coordenacao/professores", {
                    "nome": "Professor M06 %s" % rotulo, "email": "prof.m6.%s" % sufixo})
                professor_id = cadastro.get_json()["id"]
                reenvio = coord_a.post(
                    "/api/coordenacao/professores/%d/reenviar-convite" % professor_id)
                codigo = Cliente(cliente_flask).post(
                    "/api/auth/enviar-codigo", {"email": "codigo.m6.%s" % sufixo})
                edicao = coord_a.put(
                    "/api/coordenacao/professores/%d" % professor_id,
                    {"email": "prof.m6.novo.%s" % sufixo})
                enviados = list(_SmtpFalso.enviados)
            return {
                "cadastro": cadastro, "reenvio": reenvio, "codigo": codigo,
                "edicao": edicao, "console": saida.getvalue(), "enviados": enviados,
                "email_codigo": "codigo.m6.%s" % sufixo,
                "email_professor": "prof.m6.novo.%s" % sufixo,
                "id": professor_id,
            }

        def segredos_no_texto(r):
            """Convite e codigo vigentes (do banco) procurados em TODAS as respostas."""
            token = convite_no_banco(r["email_professor"])
            codigo = codigo_no_banco(r["email_codigo"])
            respostas = " ".join(r[k].get_data(as_text=True)
                                 for k in ("cadastro", "reenvio", "codigo", "edicao"))
            return token, codigo, respostas

        # 3, 4, 7. SMTP ausente e modo dev DESLIGADO: nada vaza
        r = rodar_cenario("a", dev=False, smtp=False)
        token, codigo, respostas = segredos_no_texto(r)
        checar(r["cadastro"].status_code == 201 and r["reenvio"].status_code == 200
               and r["codigo"].status_code == 200 and r["edicao"].status_code == 200,
               "M06-01: sem SMTP e sem modo dev os fluxos respondem normalmente (201/200)")
        checar("conviteToken" not in respostas and token not in respostas,
               "M06-02: sem SMTP e sem modo dev: o conviteToken NAO aparece (cadastro, reenvio e troca de e-mail)")
        checar('"codigo"' not in r["codigo"].get_data(as_text=True)
               and "modo" not in r["codigo"].get_json() and codigo not in respostas,
               "M06-03: sem SMTP e sem modo dev: o codigo de verificacao NAO aparece")
        checar(r["cadastro"].get_json()["conviteEnviado"] is False
               and r["reenvio"].get_json()["conviteEnviado"] is False
               and r["codigo"].get_json() == {"enviado": False},
               "M06-04: sem SMTP a API informa que NAO enviou (conviteEnviado/enviado = false)")
        checar(token not in r["console"] and codigo not in r["console"] and r["console"] == "",
               "M06-05: o segredo nao e impresso nem no console (nada e escrito)")
        checar(not r["enviados"], "M06-06: nenhum email foi tentado sem SMTP")
        # o resto do fluxo continua valido: o codigo gravado confirma, o convite ativa
        r_conf = Cliente(cliente_flask).post(
            "/api/auth/confirmar-codigo", {"email": r["email_codigo"], "codigo": codigo})
        ativ = cliente_flask.post("/api/auth/criar-senha-professor", json={
            "email": r["email_professor"], "senha": "senha123", "token": token})
        checar(r_conf.get_json() == {"valido": True} and ativ.status_code == 200
               and token not in ativ.get_data(as_text=True),
               "M06-07: o codigo e o convite gravados continuam funcionando; o convite nao volta na resposta")

        # 5, 6. modo dev LIGADO (sem SMTP): os campos auxiliares aparecem
        r = rodar_cenario("b", dev=True, smtp=False)
        token, codigo, respostas = segredos_no_texto(r)
        checar("conviteToken" in r["cadastro"].get_json(),
               "M06-08: modo dev: o cadastro devolve o conviteToken")
        checar(r["reenvio"].get_json().get("conviteToken") is not None
               and r["edicao"].get_json().get("conviteToken") == token,
               "M06-09: modo dev: reenvio e troca de e-mail devolvem o conviteToken vigente")
        checar(r["codigo"].get_json().get("codigo") == codigo
               and r["codigo"].get_json().get("modo") == "dev",
               "M06-10: modo dev: o codigo de verificacao aparece (marcado modo=dev)")
        checar(token in r["console"] and r["cadastro"].get_json()["conviteEnviado"] is True,
               "M06-11: modo dev sem SMTP: o email vai para o console (caixa de saida local)")

        # 9. SMTP configurado e modo dev desligado: fluxo normal, sem segredo na resposta
        r = rodar_cenario("c", dev=False, smtp=True)
        token, codigo, respostas = segredos_no_texto(r)
        checar("conviteToken" not in respostas and token not in respostas
               and '"codigo"' not in r["codigo"].get_data(as_text=True)
               and codigo not in respostas,
               "M06-12: com SMTP e sem modo dev a resposta nao traz conviteToken nem codigo")
        checar(r["cadastro"].get_json()["conviteEnviado"] is True
               and r["codigo"].get_json() == {"enviado": True},
               "M06-13: com SMTP o envio e confirmado (conviteEnviado/enviado = true)")
        corpos = " ".join(corpo_de(m) for m in r["enviados"])
        checar(len(r["enviados"]) == 4 and token in corpos and codigo in corpos,
               "M06-14: o segredo segue pelo canal certo: esta no corpo do email enviado (4 emails)")
        checar(r["console"] == "", "M06-15: com SMTP nada e impresso no console")

        # SMTP configurado e modo dev ligado: dev explicito vale
        r = rodar_cenario("d", dev=True, smtp=True)
        checar("conviteToken" in r["cadastro"].get_json() and "codigo" in r["codigo"].get_json(),
               "M06-16: SMTP configurado + modo dev explicito: campos auxiliares aparecem")

        # 10. erro de SMTP: tratado de forma amigavel, sem segredo, professor criado
        r = rodar_cenario("e", dev=False, smtp=True, falhar=True)
        token, codigo, respostas = segredos_no_texto(r)
        checar(r["cadastro"].status_code == 201
               and r["cadastro"].get_json()["conviteEnviado"] is False
               and r["codigo"].status_code == 200
               and r["codigo"].get_json() == {"enviado": False}
               and r["reenvio"].status_code == 200,
               "M06-17: falha do SMTP: 201/200 com enviado=false (o professor foi cadastrado), sem erro 500")
        checar("conviteToken" not in respostas and token not in respostas
               and codigo not in respostas,
               "M06-18: falha do SMTP nao vaza codigo nem token")

        # outros campos: o segredo nunca aparece em campo inesperado (JSON inteiro)
        lista = coord_a.get("/api/coordenacao/professores").get_data(as_text=True)
        checar(token not in lista and "conviteToken" not in lista
               and "convite_token" not in lista,
               "M06-19: a listagem de professores nao expoe convite nem token")

        # limpeza dos codigos gerados
        execute("DELETE FROM codigo_verificacao WHERE email LIKE %s", ("%" + SUFIXO,))

        # ---------------------------------------------------------
        print("\n[M-07] Token na URL (?token=) nao autentica; so o Bearer")
        import jwt
        from datetime import datetime, timedelta, timezone
        from config import SECRET_KEY

        def req(metodo, url, bearer=None, corpo=None, cabecalho_bruto=None):
            cabecalhos = {}
            if bearer:
                cabecalhos["Authorization"] = "Bearer %s" % bearer
            if cabecalho_bruto:
                cabecalhos["Authorization"] = cabecalho_bruto
            kw = {"headers": cabecalhos}
            if corpo is not None:
                kw["json"] = corpo
            return getattr(cliente_flask, metodo)(url, **kw)

        tok_coord_a, tok_coord_b = coord_a.token, coord_b.token
        tok_prof_a, tok_prof_b = prof_i2.token, professor_b.token
        turma_q = turma_orig["id"]

        # professor desativado e token expirado (de um professor real)
        pd_dados = coord_a.post("/api/coordenacao/professores", {
            "nome": "Professor Desativado M07", "email": "prof.m7.%s" % SUFIXO}).get_json()
        pd_cli = ativar_professor(pd_dados)
        coord_a.post("/api/coordenacao/professores/%d/desativar" % pd_dados["id"])
        agora = datetime.now(timezone.utc)
        tok_expirado = jwt.encode({
            "sub": str(prof_i2_dados["id"]), "uid": prof_i2_dados["id"],
            "tipo": "professor", "coordenacao_id": cid_a,
            "iat": agora - timedelta(hours=13), "exp": agora - timedelta(hours=1),
        }, SECRET_KEY, algorithm="HS256")

        antes_m7 = estado_da_escola()

        # 1-4. endpoints normais + ?token=valido SEM header -> 401
        gerais = (
            ("GET", "/api/classes/%d" % turma_q, tok_coord_a, None),
            ("GET", "/api/classes", tok_prof_a, None),
            ("GET", "/api/activities", tok_prof_a, None),
            ("GET", "/api/config/etapas", tok_coord_a, None),
        )
        coordenacao = (
            ("GET", "/api/coordenacao/professores", tok_coord_a, None),
            ("GET", "/api/coordenacao/turmas/%d/alunos" % turma_q, tok_coord_a, None),
            ("GET", "/api/coordenacao/turmas/%d/boletim" % turma_q, tok_coord_a, None),
            ("GET", "/api/config/anos-letivos", tok_coord_a, None),
        )
        professor = (
            ("GET", "/api/professor/turmas", tok_prof_a, None),
            ("GET", "/api/professor/dashboard", tok_prof_a, None),
            ("GET", "/api/professor/turmas/%d/boletim" % turma_q, tok_prof_a, None),
            ("GET", "/api/atividades/%d/notas" % ativ_m1["id"], tok_prof_a, None),
        )
        ia = (
            ("POST", "/api/professor/turmas/%d/insights" % turma_q, tok_prof_a, {}),
            ("POST", "/api/professor/turmas/%d/atividades/gerar" % turma_q, tok_prof_a, {"tema": "Fracoes"}),
            ("POST", "/api/professor/alunos/%d/feedback-ia" % aluno_m1, tok_prof_a, {"etapaId": etapa_m1["id"]}),
            ("POST", "/api/professor/atividades/%d/correcao-assistida" % ativ_m1["id"], tok_prof_a,
             {"questao": "q", "respostaEsperada": "r", "respostaAluno": "a b c d"}),
        )
        for grupo, rotulo in ((gerais, "endpoint geral"), (coordenacao, "endpoint de Coordenacao"),
                              (professor, "endpoint de Professor"), (ia, "endpoint de IA")):
            for metodo, url, token, corpo in grupo:
                r = req(metodo.lower(), "%s?token=%s" % (url, token), corpo=corpo)
                checar(r.status_code == 401,
                       "M07-01: %s %s com ?token= valido e SEM header -> 401 (%s)"
                       % (metodo, url.split("?")[0][:50], rotulo))

        # 10. escrita so por query nao grava nada
        ataques = (
            ("POST", "/api/classes", tok_coord_a, {"name": "Turma via URL", "ano_letivo": ANO}),
            ("PUT", "/api/classes/%d" % turma_q, tok_coord_a, {"name": "Renomeada via URL"}),
            ("DELETE", "/api/classes/%d" % turma_q, tok_coord_a, None),
            ("PUT", "/api/config/etapas/%d" % etapa_m1["id"], tok_coord_a, {"nome": "via URL"}),
            ("DELETE", "/api/config/criterios/%d" % crit_m1["id"], tok_coord_a, None),
            ("POST", "/api/coordenacao/professores", tok_coord_a, {"nome": "Via Url Silva", "email": "via.url.%s" % SUFIXO}),
            ("POST", "/api/coordenacao/alunos/%d/transferir" % aluno_m1, tok_coord_a, {"turma_id": turma_dest["id"]}),
            ("POST", "/api/activities", tok_prof_a, {"title": "via url", "class_id": turma_q,
                                                       "etapa_id": etapa_m1["id"], "criterio_id": crit_m1["id"], "nota_maxima": 10}),
            ("PUT", "/api/activities/%d" % ativ_m1["id"], tok_prof_a, {"title": "via URL"}),
            ("DELETE", "/api/activities/%d" % ativ_m1["id"], tok_prof_a, None),
            ("POST", "/api/atividades/%d/notas" % ativ_m1["id"], tok_prof_a, {"aluno_id": aluno_m1, "valor": 1}),
            ("DELETE", "/api/professor/alunos/%d" % aluno_m1, tok_prof_a, None),
        )
        for metodo, url, token, corpo in ataques:
            r = req(metodo.lower(), "%s?token=%s" % (url, token), corpo=corpo)
            checar(r.status_code == 401, "M07-02: %s %s so com ?token= -> 401" % (metodo, url[:52]))
        checar(estado_da_escola() == antes_m7,
               "M07-03: nenhuma das escritas autenticadas so por query alterou o banco (7 tabelas identicas)")

        # 5. o header Bearer segue funcionando
        checar(req("get", "/api/classes/%d" % turma_q, tok_coord_a).status_code == 200
               and req("get", "/api/coordenacao/professores", tok_coord_a).status_code == 200
               and req("get", "/api/professor/turmas", tok_prof_a).status_code == 200
               and req("get", "/api/activities", tok_prof_a).status_code == 200,
               "M07-04: Authorization: Bearer valido continua 200 (geral, coordenacao e professor)")
        checar(req("get", "/api/professor/turmas", tok_coord_a).status_code == 403
               and req("get", "/api/config/anos-letivos", tok_prof_a).status_code == 403,
               "M07-05: os papeis continuam valendo com o header (403 no papel errado)")
        checar(req("get", "/api/professor/turmas", pd_cli.token).status_code == 403,
               "M07-06: professor desativado com header continua bloqueado (403)")
        checar(req("get", "/api/classes/%d" % turma_q, tok_coord_b).status_code == 404,
               "M07-07: cross-school com header continua 404")

        # 6. header invalido + query valido -> 401 (a URL nao assume o lugar do header)
        for rotulo, cab in (("Bearer com lixo", "Bearer lixo.lixo.lixo"), ("Bearer vazio", "Bearer"),
                            ("esquema Basic", "Basic YWJjOmRlZg=="), ("token solto", "abc")):
            for url in ("/api/classes/%d" % turma_q,
                        "/api/professor/turmas/%d/alunos/modelo-planilha" % turma_q):
                r = req("get", "%s?token=%s" % (url, tok_coord_a if "coord" in url else tok_prof_a),
                        cabecalho_bruto=cab)
                checar(r.status_code == 401,
                       "M07-08: header invalido (%s) + ?token= valido -> 401 em %s" % (rotulo, url[:46]))

        # 7. header valido + query de OUTRO usuario: a identidade e a do header
        r = req("get", "/api/classes?token=%s" % tok_coord_b, tok_coord_a)
        ids = {t["id"] for t in r.get_json()}
        ids_a = {t["id"] for t in req("get", "/api/classes", tok_coord_a).get_json()}
        checar(r.status_code == 200 and ids == ids_a and turma_b["id"] not in ids,
               "M07-09: header da escola A + ?token= da escola B -> lista so da escola A")
        checar(req("get", "/api/classes/%d?token=%s" % (turma_b["id"], tok_coord_a), tok_coord_b).status_code == 200
               and req("get", "/api/classes/%d?token=%s" % (turma_q, tok_coord_a), tok_coord_b).status_code == 404,
               "M07-10: a escola do header decide o acesso, nunca a do ?token=")
        checar(req("get", "/api/professor/turmas?token=%s" % tok_prof_a, tok_coord_a).status_code == 403,
               "M07-11: header de Coordenacao + ?token= de Professor -> 403 (papel do header)")

        # token ruim na query: nao autentica
        checar(req("get", "/api/professor/turmas?token=%s" % pd_cli.token).status_code == 401,
               "M07-12: token de professor DESATIVADO na query (endpoint normal) -> 401")
        checar(req("get", "/api/professor/turmas?token=%s" % tok_expirado).status_code == 401,
               "M07-13: token EXPIRADO na query (endpoint normal) -> 401")

        # excecao real e restrita: os 3 downloads de modelo de planilha (GET)
        downloads = (
            ("/api/coordenacao/turmas/%d/alunos/modelo-planilha" % turma_q, tok_coord_a, tok_prof_a),
            ("/api/professor/turmas/%d/alunos/modelo-planilha" % turma_q, tok_prof_a, tok_coord_a),
            ("/api/atividades/%d/notas/modelo-planilha" % ativ_m1["id"], tok_prof_a, tok_coord_a),
        )
        for url, certo, errado in downloads:
            r = req("get", "%s?token=%s" % (url, certo))
            checar(r.status_code == 200 and "spreadsheetml" in r.headers["Content-Type"],
                   "M07-14: EXCECAO: download %s abre com ?token= (navegador nao manda header)" % url[5:48])
            checar(req("get", "%s?token=%s" % (url, errado)).status_code == 403,
                   "M07-15: exceção: o papel errado na URL continua barrado (403)")
            checar(req("get", "%s?token=%s" % (url, tok_expirado)).status_code == 401
                   and req("get", "%s?token=%s" % (url, pd_cli.token)).status_code in (401, 403)
                   and req("get", "%s?token=lixo" % url).status_code == 401,
                   "M07-16: exceção: expirado, desativado e lixo na URL nao autenticam")
            checar(req("get", "%s?token=%s" % (url, tok_coord_b if "coordenacao" in url else tok_prof_b)
                       ).status_code in (200, 404),
                   "M07-17: exceção: token de outra escola so alcanca o modelo em branco (sem dado da escola A)")
            checar(req("get", "%s?token=%s" % (url, errado), certo).status_code == 200,
                   "M07-18: exceção: com header presente a URL e ignorada (identidade do header)")
            checar(req("post", "%s?token=%s" % (url, certo)).status_code in (401, 405),
                   "M07-19: exceção: so GET; POST na mesma rota com ?token= nao autentica")
        # a excecao nao vaza para as rotas vizinhas
        checar(req("get", "/api/professor/turmas/%d/alunos?token=%s" % (turma_q, tok_prof_a)).status_code == 401
               and req("get", "/api/coordenacao/turmas/%d/alunos?token=%s" % (turma_q, tok_coord_a)).status_code == 401,
               "M07-20: a excecao nao se estende as rotas vizinhas (listas de alunos -> 401)")
        checar(estado_da_escola() == antes_m7,
               "M07-21: depois de tudo isso o banco segue identico")

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

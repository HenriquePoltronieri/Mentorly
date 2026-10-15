"""Métricas de leitura e risco determinístico, compartilhados pelos gráficos e IA.

Gráficos recebem pontos reais e o máximo de cada atividade. Comparações
internas e IA usam escala 0–10 (valor / máximo * 10).
Sem nota não é zero e não confirma falta de entrega; situações explícitas
são registradas separadamente do valor. Pendências de lançamento
vencidas entram como sinal para o professor conferir, nunca como diagnóstico.
"""
from datetime import datetime
from services.horario import agora_brasilia
from database.connection import query_all
from models.turma_model import Turma
from models.professor_turma_model import ProfessorTurma
from models.aluno_model import Aluno
from models.etapa_model import Etapa
from models.criterio_model import Criterio
from services.professor.acompanhamento import acompanhar_etapa
from services.academico.calculo import etapa_atual
from erros import AcessoNegado, RecursoNaoEncontrado


def _media(valores):
    return round(sum(valores) / len(valores), 2) if valores else None


def resumir(turma, etapas, atual, atividades, alunos, notas, etapa_id=None, hoje=None, criterios=None):
    hoje = hoje or agora_brasilia().date()
    selecionadas = [a for a in atividades if etapa_id is None or a["etapa_id"] == etapa_id]
    selecionadas.sort(key=lambda a: (str(a.get("data_entrega") or a.get("created_at") or ""), a["id"]))
    valores = {(n["aluno_id"], n["atividade_id"]): n for n in notas if n.get("valor") is not None}
    situacoes = {(n["aluno_id"], n["atividade_id"]): n.get("situacao") for n in notas if n.get("situacao")}
    medias = {}
    medias_pontos = {}
    entregas = 0
    for a in selecionadas:
        ns = [valores.get((al["id"], a["id"])) for al in alunos]
        escala = float(a.get("nota_maxima") or 0)
        medias[a["id"]] = _media([float(n["valor"]) / escala * 10 for n in ns if n and escala > 0])
        medias_pontos[a["id"]] = _media([float(n["valor"]) for n in ns if n])
        entregas += sum(1 for al, n in zip(alunos, ns) if n and
                        situacoes.get((al["id"], a["id"]), n.get("observacao")) not in ("Ausente", "Não entregou", "Não corrigido"))
    ranking = []
    for al in alunos:
        lista = []
        vencidas = entregues = 0
        for a in selecionadas:
            n = valores.get((al["id"], a["id"]))
            maximo = float(a.get("nota_maxima") or 0)
            nota = float(n["valor"]) if n else None
            normalizada = round(nota / maximo * 10, 2) if nota is not None and maximo > 0 else None
            prazo = a.get("data_entrega")
            if not n and prazo and str(prazo)[:10] < hoje.isoformat():
                vencidas += 1
            status = situacoes.get((al["id"], a["id"])) or (n.get("observacao") if n and n.get("observacao") in ("Ausente", "Não entregou") else "Entregue" if n else "Sem nota lançada")
            entregues += status == "Entregue"
            lista.append({"id": a["id"], "titulo": a["titulo"], "etapa_id": a["etapa_id"],
                          "criterio_id": a.get("criterio_id"), "descricao": a.get("descricao"),
                          "observacao": n.get("observacao") if n else None,
                          "data": str(prazo or a.get("created_at") or ""), "nota": nota,
                          "nota_maxima": maximo or None, "nota_normalizada": normalizada,
                          "media_turma": medias[a["id"]],
                          "media_turma_pontos": medias_pontos[a["id"]], "status": status})
        avaliadas = [a["nota_normalizada"] for a in lista if a["nota_normalizada"] is not None]
        com_nota = [a for a in lista if a["nota_normalizada"] is not None]
        pontos = sum(a["nota"] for a in com_nota)
        possiveis = sum(a["nota_maxima"] for a in com_nota)
        media = round(pontos / possiveis * 10, 2) if possiveis else None
        variacao = round(avaliadas[-1] - avaliadas[-2], 2) if len(avaliadas) >= 2 else None
        tendencia = "sem dados" if variacao is None else "subindo" if variacao > .5 else "caindo" if variacao < -.5 else "estável"
        acompanhamentos = [acompanhar_etapa(e, [c for c in (criterios or []) if c["etapa_id"] == e["id"]],
                            [a for a in lista if a["etapa_id"] == e["id"]], hoje)
                           for e in etapas if etapa_id is None or e["id"] == etapa_id]
        referencia = next((e for e in acompanhamentos if e["etapa_id"] == (etapa_id if etapa_id is not None else atual)), None)
        minimo = (round(referencia["nota_minima"] / referencia["nota_maxima"] * 10, 2)
                  if referencia and referencia["nota_minima"] is not None and referencia["nota_maxima"] else None)
        risco, motivos = (referencia["risco"], referencia["motivos"]) if referencia else ("Sem dados", ["Selecione uma etapa para acompanhar a nota."])
        ranking.append({"id": al["id"], "nome": al["nome"], "turma_id": turma["id"], "turma": turma["nome"],
                        "media": media, "nota_minima": minimo, "risco": risco, "motivos": motivos,
                        "acompanhamento": referencia, "acompanhamento_etapas": acompanhamentos,
                        "pontos_obtidos": referencia["pontos_obtidos"] if referencia else None,
                        "pontos_avaliados": referencia["pontos_avaliados"] if referencia else None,
                        "pendentes_vencidas": vencidas,
                        "tendencia": tendencia, "variacao": variacao, "entregues": entregues,
                        "pendentes": len(lista) - entregues, "sem_nota": sum(a["nota"] is None for a in lista),
                        "maior_nota": max(avaliadas) if avaliadas else None,
                        "menor_nota": min(avaliadas) if avaliadas else None, "atividades": lista})
    ranking.sort(key=lambda a: ({"Alto": 0, "Médio": 1, "Em andamento": 2, "Baixo": 3, "Sem dados": 4}[a["risco"]], a["media"] if a["media"] is not None else -1, a["nome"]))
    distribuicao = {r: sum(a["risco"] == r for a in ranking) for r in ("Alto", "Médio", "Em andamento", "Baixo", "Sem dados")}
    por_atividade = [{"id": a["id"], "titulo": a["titulo"], "media": medias[a["id"]],
                      "media_pontos": medias_pontos[a["id"]],
                      "nota_maxima": float(a["nota_maxima"]) if a.get("nota_maxima") is not None else None,
                      "data": str(a.get("data_entrega") or a.get("created_at") or ""), "etapa_id": a["etapa_id"]} for a in selecionadas]
    avaliadas = [a for a in por_atividade if a["media"] is not None]
    total = len(alunos) * len(selecionadas)
    return {"turma": {"id": turma["id"], "nome": turma["nome"]}, "escala": 10,
            "etapa_atual": atual, "etapas": [{"id": e["id"], "nome": e["nome"], "fechada": bool(e.get("fechada", False)), "nota_minima": float(e["nota_minima"]) if e.get("nota_minima") is not None else None, "nota_maxima": float(e["nota_maxima"]) if e.get("nota_maxima") is not None else None} for e in etapas],
            "media": _media([a["media"] for a in ranking if a["media"] is not None]),
            "percentual_entregas": round(entregas / total * 100, 1) if total else None,
            "alunos_em_risco": distribuicao["Alto"] + distribuicao["Médio"],
            "pior_atividade": min(avaliadas, key=lambda a: a["media"]) if avaliadas else None,
            "distribuicao_risco": distribuicao, "atividades": por_atividade, "alunos": ranking}


class EstatisticasTurmaService:
    def execute(self, professor_id, coordenacao_id, turma_id, etapa_id=None, aluno_id=None):
        if not ProfessorTurma.professor_leciona_na_turma(professor_id, turma_id):
            raise AcessoNegado("Você só pode consultar estatísticas das suas turmas vinculadas.")
        turma = Turma.find_by_id(turma_id, coordenacao_id)
        if not turma:
            raise AcessoNegado("Turma indisponível para este professor.")
        etapas = Etapa.find_all_by_coordenacao(coordenacao_id, turma["ano_letivo"])
        if etapa_id is not None and not any(e["id"] == etapa_id for e in etapas):
            raise ValueError("Escolha uma etapa deste ano letivo.")
        atual, _ = etapa_atual(coordenacao_id, turma["ano_letivo"])
        alunos = Aluno.find_all_by_turma(turma_id)
        criterios = Criterio.find_all_by_coordenacao(coordenacao_id, turma["ano_letivo"])
        atividades = query_all("SELECT id,titulo,descricao,criterio_id,etapa_id,nota_maxima,data_entrega,created_at FROM atividade WHERE turma_id=%s AND coordenacao_id=%s", (turma_id, coordenacao_id))
        notas = query_all("SELECT al.id AS aluno_id,a.id AS atividade_id,n.valor,n.observacao,s.situacao "
                          "FROM atividade a JOIN aluno al ON al.turma_id=a.turma_id "
                          "LEFT JOIN nota n ON n.atividade_id=a.id AND n.aluno_id=al.id "
                          "LEFT JOIN atividade_situacao s ON s.atividade_id=a.id AND s.aluno_id=al.id "
                          "WHERE a.turma_id=%s AND a.coordenacao_id=%s AND (n.id IS NOT NULL OR s.situacao IS NOT NULL)", (turma_id, coordenacao_id))
        dados = resumir(turma, etapas, atual["id"] if atual else None, atividades, alunos, notas, etapa_id, criterios=criterios)
        if aluno_id is not None:
            aluno = next((a for a in dados["alunos"] if a["id"] == aluno_id), None)
            if not aluno:
                raise RecursoNaoEncontrado("Aluno não encontrado nesta turma.")
            return {**aluno, "etapas": dados["etapas"], "etapa_atual": dados["etapa_atual"], "escala": 10}
        return dados

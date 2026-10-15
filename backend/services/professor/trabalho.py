"""Pendencias e acompanhamentos: sempre limitados ao professor autenticado."""
from datetime import date
from database.connection import query_all, execute, insert
from models.aluno_model import Aluno
from models.turma_model import Turma
from models.professor_turma_model import ProfessorTurma
from models.ano_letivo_model import AnoLetivo
from services.config.anos_letivos import exigir_ano_nao_encerrado
from services.entrada import inteiro, texto
from erros import RecursoNaoEncontrado


def turma_autorizada(professor_id, coordenacao_id, turma_id):
    turma = Turma.find_by_id(turma_id, coordenacao_id)
    if not turma or not ProfessorTurma.professor_leciona_na_turma(professor_id, turma_id):
        raise RecursoNaoEncontrado("Turma não encontrada.")
    return turma


def listar_acompanhamentos(professor_id, coordenacao_id, turma_id=None, aluno_id=None):
    sql = ("SELECT ap.*, al.nome AS aluno, t.nome AS turma FROM acompanhamento_pedagogico ap "
           "JOIN aluno al ON al.id=ap.aluno_id AND al.turma_id=ap.turma_id "
           "JOIN turma t ON t.id=ap.turma_id "
           "JOIN professor_turma pt ON pt.turma_id=t.id AND pt.professor_id=ap.professor_id "
           "WHERE ap.professor_id=%s AND t.coordenacao_id=%s")
    params = [professor_id, coordenacao_id]
    for coluna, valor in (("ap.turma_id", turma_id), ("ap.aluno_id", aluno_id)):
        if valor is not None:
            sql += " AND " + coluna + "=%s"
            params.append(valor)
    rows = query_all(sql + " ORDER BY ap.concluido, ap.retorno_em, ap.id DESC", tuple(params))
    return [{**r, "retorno_em": str(r["retorno_em"]), "created_at": str(r["created_at"]),
             "concluido": bool(r["concluido"])} for r in rows]


def criar_acompanhamento(professor_id, coordenacao_id, turma_id, aluno_id, payload):
    turma = turma_autorizada(professor_id, coordenacao_id, turma_id)
    exigir_ano_nao_encerrado(coordenacao_id, turma["ano_letivo"])
    aluno = Aluno.find_by_id(aluno_id)
    if not aluno or aluno["turma_id"] != turma_id:
        raise RecursoNaoEncontrado("Aluno não encontrado nesta turma.")
    descricao = texto(payload.get("descricao"), "A intervenção", 3000)
    if not descricao:
        raise ValueError("Descreva a intervenção.")
    try:
        retorno = date.fromisoformat(payload.get("retorno_em", ""))
    except (ValueError, TypeError):
        raise ValueError("Informe uma data de retorno válida.")
    novo = insert("INSERT INTO acompanhamento_pedagogico (professor_id,turma_id,aluno_id,descricao,retorno_em) "
                  "VALUES (%s,%s,%s,%s,%s)", (professor_id, turma_id, aluno_id, descricao, retorno))
    return {"id": novo}


def concluir_acompanhamento(professor_id, coordenacao_id, registro_id, payload):
    registros = listar_acompanhamentos(professor_id, coordenacao_id)
    registro = next((r for r in registros if r["id"] == registro_id), None)
    if not registro:
        raise RecursoNaoEncontrado("Acompanhamento não encontrado.")
    turma = turma_autorizada(professor_id, coordenacao_id, registro["turma_id"])
    exigir_ano_nao_encerrado(coordenacao_id, turma["ano_letivo"])
    if type(payload.get("concluido")) is not bool:
        raise ValueError("Informe se o acompanhamento foi concluído.")
    execute("UPDATE acompanhamento_pedagogico SET concluido=%s WHERE id=%s AND professor_id=%s",
            (payload["concluido"], registro_id, professor_id))
    return {"id": registro_id, "concluido": payload["concluido"]}


def painel_trabalho(professor_id, coordenacao_id):
    ano = AnoLetivo.atual(coordenacao_id)
    if not ano:
        return {"pendencias": [], "acompanhamentos": [], "turmas": []}
    turmas = [t for t in ProfessorTurma.turmas_do_professor(professor_id) if t["ano_letivo"] == ano["ano"]]
    # Uma consulta para todas as atividades do ano; notas de alunos transferidos nao contam.
    pendencias = query_all(
        "SELECT a.id,a.titulo,a.turma_id,t.nome AS turma,a.data_entrega,a.etapa_id,e.nome AS etapa, "
        "a.criterio_id,a.nota_maxima,COUNT(al.id) AS total_alunos, "
        "SUM(CASE WHEN al.id IS NOT NULL AND n.id IS NULL THEN 1 ELSE 0 END) AS sem_nota "
        "FROM atividade a JOIN turma t ON t.id=a.turma_id "
        "JOIN professor_turma pt ON pt.turma_id=t.id AND pt.professor_id=%s "
        "JOIN etapa e ON e.id=a.etapa_id AND e.fechada=0 "
        "LEFT JOIN aluno al ON al.turma_id=t.id "
        "LEFT JOIN nota n ON n.atividade_id=a.id AND n.aluno_id=al.id "
        "WHERE t.coordenacao_id=%s AND t.ano_letivo=%s "
        "GROUP BY a.id,a.titulo,a.turma_id,t.nome,a.data_entrega,a.etapa_id,e.nome,a.criterio_id,a.nota_maxima "
        "HAVING sem_nota>0 ORDER BY a.data_entrega IS NULL,a.data_entrega,a.id",
        (professor_id, coordenacao_id, ano["ano"])) if ano["status"] != "encerrado" else []
    return {"pendencias": [{**p, "sem_nota": int(p["sem_nota"]),
                            "nota_maxima": float(p["nota_maxima"]) if p["nota_maxima"] is not None else None,
                            "data_entrega": str(p["data_entrega"] or "")[:10]} for p in pendencias],
            "turmas": [{"id": t["id"], "nome": t["nome"], "disciplina": t.get("disciplina"),
                        "totalAlunos": t.get("total_alunos", 0), "anoLetivo": t["ano_letivo"]} for t in turmas],
            "acompanhamentos": [r for r in listar_acompanhamentos(professor_id, coordenacao_id)
                                if not r["concluido"] and r["turma_id"] in {t["id"] for t in turmas}]}

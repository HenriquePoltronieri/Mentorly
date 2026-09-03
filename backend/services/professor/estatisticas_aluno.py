from models.nota_model import Nota
from services.aluno.acesso_turma import aluno_acessivel


class EstatisticasAlunoService:
    """Desempenho de um aluno, agrupado por etapa.

    So responde se o aluno estiver em uma turma vinculada ao professor
    logado - caso contrario levanta LookupError (404).
    """

    def execute(self, aluno_id, coordenacao_id, professor_id):
        aluno = aluno_acessivel(aluno_id, coordenacao_id, professor_id)
        notas = Nota.find_by_aluno(aluno_id)
        resumo = Nota.media_do_aluno(aluno_id)

        por_etapa = {}
        for linha in notas:
            chave = linha.get("etapa_id") or 0
            grupo = por_etapa.setdefault(chave, {
                "etapaId": linha.get("etapa_id"),
                "etapa": linha.get("etapa_nome") or "Sem etapa",
                "ordem": linha.get("etapa_ordem") or 0,
                "notaMinima": linha.get("nota_minima"),
                "notas": [],
            })
            grupo["notas"].append(Nota.to_dict(linha))

        etapas = sorted(por_etapa.values(), key=lambda e: e["ordem"])
        for etapa in etapas:
            valores = [n["valor"] for n in etapa["notas"] if n["valor"] is not None]
            etapa["media"] = (
                round(sum(valores) / len(valores), 2) if valores else None
            )

        return {
            "id": aluno["id"],
            "nome": aluno["nome"],
            "matricula": aluno.get("matricula"),
            "turma": aluno.get("turma_nome"),
            "turmaId": aluno.get("turma_id"),
            "media": resumo["media"],
            "totalNotas": resumo["total"],
            "etapas": etapas,
            # Lista plana, para o grafico que ja existe no app.
            "notas": [Nota.to_dict(linha) for linha in notas],
        }

from datetime import date

from models.aluno_model import Aluno
from models.professor_model import Professor
from models.professor_turma_model import ProfessorTurma
from services.academico.calculo import calcular_desempenho_etapa, etapa_atual


class DashboardProfessorService:
    """Resumo do professor com risco calculado na etapa atual da escola."""

    def execute(self, professor_id, ano_letivo=None):
        ano_letivo = ano_letivo or date.today().year

        professor = Professor.find_by_id(professor_id)
        turmas = ProfessorTurma.turmas_do_professor(professor_id)
        total_alunos = sum(t.get("total_alunos") or 0 for t in turmas)

        em_risco = []
        if professor:
            em_risco = self._alunos_em_risco(
                professor["coordenacao_id"], turmas, ano_letivo
            )

        return {
            "nome": professor["nome"] if professor else "",
            "email": professor["email"] if professor else "",
            "totalTurmas": len(turmas),
            "totalAlunos": total_alunos,
            "alunosEmRisco": em_risco,
        }

    def _alunos_em_risco(self, coordenacao_id, turmas, ano_letivo):
        """Alunos cujo desempenho calculado na etapa atual esta abaixo do
        minimo daquela etapa - nunca por falta de nota (isso e
        'em_andamento', nao risco) e nunca comparado com a etapa errada.
        """
        etapa, _regra = etapa_atual(coordenacao_id, ano_letivo)
        if etapa is None:
            return []

        resultado = []
        for turma in turmas:
            alunos = Aluno.find_all_by_turma(turma["id"])
            for aluno in alunos:
                calculo = calcular_desempenho_etapa(
                    aluno["id"], turma["id"], etapa
                )
                if calculo["completo"] and calculo["situacao"] == "abaixo_do_minimo":
                    resultado.append({
                        "id": aluno["id"],
                        "nome": aluno["nome"],
                        "turma": turma["nome"],
                        "media": calculo["nota_calculada"],
                        "notaMinima": etapa.get("nota_minima"),
                        "etapaId": etapa["id"],
                        "etapa": etapa.get("nome"),
                    })
        resultado.sort(key=lambda item: item["media"])
        return resultado

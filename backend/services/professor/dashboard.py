from models.aluno_model import Aluno
from models.ano_letivo_model import AnoLetivo
from models.professor_model import Professor
from models.professor_turma_model import ProfessorTurma
from services.academico.calculo import calcular_desempenho_etapa, etapa_atual


class DashboardProfessorService:
    """Resumo do professor, dentro de UM ano letivo.

    O ano e o ATUAL da escola (cadastro de anos letivos), a menos que o
    pedido informe outro ano que a escola tenha. Turmas, alunos e alunos em
    risco so contam as turmas daquele ano, e a etapa atual e a daquele ano:
    uma turma de 2025 nunca e avaliada contra a etapa de 2026. Ano em
    planejamento nao vira o contexto do dashboard enquanto nao for o atual.

    Se a escola ainda nao marcou um ano atual, o resumo vem zerado e com
    anoLetivo nulo (a tela avisa), em vez de adivinhar um ano.
    """

    def execute(self, professor_id, ano_letivo=None):
        professor = Professor.find_by_id(professor_id)
        if not professor:
            return self._resumo(None, None, [], [])

        ano = self._ano_do_contexto(professor["coordenacao_id"], ano_letivo)

        turmas = []
        if ano is not None:
            turmas = [
                t for t in ProfessorTurma.turmas_do_professor(professor_id)
                if t["ano_letivo"] == ano["ano"]
            ]

        em_risco = []
        if ano is not None:
            em_risco = self._alunos_em_risco(
                professor["coordenacao_id"], turmas, ano["ano"]
            )

        return self._resumo(professor, ano, turmas, em_risco)

    @staticmethod
    def _ano_do_contexto(coordenacao_id, ano_letivo):
        if ano_letivo is None:
            return AnoLetivo.atual(coordenacao_id)
        registro = AnoLetivo.find_by_ano(coordenacao_id, ano_letivo)
        if not registro:
            raise LookupError("Ano letivo nao encontrado")
        return registro

    @staticmethod
    def _resumo(professor, ano, turmas, em_risco):
        return {
            "nome": professor["nome"] if professor else "",
            "email": professor["email"] if professor else "",
            "anoLetivo": ano["ano"] if ano else None,
            "anoLetivoStatus": ano["status"] if ano else None,
            "totalTurmas": len(turmas),
            "totalAlunos": sum(t.get("total_alunos") or 0 for t in turmas),
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

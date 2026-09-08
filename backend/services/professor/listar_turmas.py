from models.turma_model import Turma
from repositories.turma_repository import TurmaRepository


class ListarTurmasDoProfessorService:
    """Turmas que o professor logado leciona.

    Fonte unica: o vinculo professor_turma criado pela Coordenacao. Um
    professor nunca ve turma de outro professor, nem turma da propria escola
    que nao foi vinculada a ele.
    """

    def __init__(self):
        self._repositorio = TurmaRepository()

    def execute(self, professor_id):
        linhas = self._repositorio.turmas_do_professor(professor_id)

        # A procedure devolve as chaves em portugues, mas parte das telas do
        # app usa TurmaModel.fromJson, que le "name"/"description". Sem os
        # dois formatos, a lista de atividades aparece com o nome em branco.
        return [
            {
                "id": linha["id"],
                "name": linha.get("nome"),
                "nome": linha.get("nome"),
                "description": linha.get("descricao"),
                "descricao": linha.get("descricao"),
                "disciplina": linha.get("disciplina"),
                "turno": linha.get("turno"),
                "anoLetivo": linha.get("anoLetivo"),
                "totalAlunos": linha.get("totalAlunos", 0),
            }
            for linha in linhas
        ]


class ListarAlunosDaTurmaService:
    """Alunos de uma turma do professor.

    Cada aluno ganha "media": a nota_calculada dele na etapa atual da
    escola (Marco 2), pela mesma regra central que o dashboard e a tela de
    estatisticas usam - nunca um calculo proprio desta tela. Fica None
    quando a etapa atual ainda nao esta completa para aquele aluno (nao
    inventa numero) ou quando a escola nao tem etapa configurada.
    """

    def execute(self, turma_id, professor_id):
        from datetime import date

        from models.aluno_model import Aluno
        from services.academico.calculo import calcular_desempenho_etapa, etapa_atual

        turma = Turma.find_by_id_para_professor(turma_id, professor_id)
        if not turma:
            raise LookupError("Turma nao encontrada")

        ano_letivo = turma.get("ano_letivo") or date.today().year
        etapa, _regra = etapa_atual(turma["coordenacao_id"], ano_letivo)

        alunos = []
        for linha in Aluno.find_all_by_turma(turma_id):
            aluno = Aluno.to_dict(linha)
            media = None
            if etapa is not None:
                calculo = calcular_desempenho_etapa(aluno["id"], turma_id, etapa)
                if calculo["completo"]:
                    media = calculo["nota_calculada"]
            aluno["media"] = media
            alunos.append(aluno)
        return alunos

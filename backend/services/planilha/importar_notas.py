"""Importacao de notas em lote por planilha (CSV ou XLSX).

Exclusivo do Professor, e so em atividade de turma vinculada a ele.
A planilha identifica o aluno por matricula ou, na falta dela, pelo nome.
"""

from models.aluno_model import Aluno
from models.atividade_model import Atividade
from models.nota_model import Nota
from models.professor_turma_model import ProfessorTurma
from services.planilha.leitor import PlanilhaInvalida, ler_planilha
from services.planilha.validacao import validar_linha_nota


class ImportarNotasService:
    def execute(self, atividade_id, professor_id, nome_arquivo, conteudo):
        atividade = Atividade.find_by_id(atividade_id)
        if not atividade:
            raise LookupError("Atividade nao encontrada")

        if not ProfessorTurma.professor_leciona_na_turma(
            professor_id, atividade["turma_id"]
        ):
            raise LookupError("Atividade nao encontrada")

        if not conteudo:
            raise PlanilhaInvalida("Nenhum arquivo foi enviado")

        colunas, registros = ler_planilha(nome_arquivo, conteudo)
        if "nota" not in colunas:
            raise PlanilhaInvalida("A planilha precisa ter a coluna: nota")
        if "matricula" not in colunas and "aluno" not in colunas:
            raise PlanilhaInvalida(
                "A planilha precisa ter a coluna matricula ou aluno"
            )

        alunos = Aluno.find_all_by_turma(atividade["turma_id"])
        por_matricula = {
            a["matricula"]: a["id"] for a in alunos if a.get("matricula")
        }
        por_nome = {a["nome"].strip().lower(): a["id"] for a in alunos}

        lancamentos = []
        erros = []
        ja_lancados = set()

        for numero, registro in registros:
            matricula = (registro.get("matricula") or "").strip()
            nome = (registro.get("aluno") or "").strip().lower()

            aluno_id = por_matricula.get(matricula) if matricula else None
            if aluno_id is None and nome:
                aluno_id = por_nome.get(nome)

            if aluno_id is None:
                erros.append({
                    "linha": numero,
                    "motivo": "aluno nao encontrado nesta turma",
                })
                continue

            if aluno_id in ja_lancados:
                erros.append({
                    "linha": numero,
                    "motivo": "aluno repetido na planilha",
                })
                continue

            dados, erro = validar_linha_nota(
                registro, atividade.get("nota_maxima")
            )
            if erro:
                erros.append({"linha": numero, "motivo": erro})
                continue

            ja_lancados.add(aluno_id)
            lancamentos.append({
                "aluno_id": aluno_id,
                "valor": dados["valor"],
                "observacao": dados["observacao"],
            })

        if lancamentos:
            Nota.lancar_em_lote(atividade_id, lancamentos)

        return {
            "lancadas": len(lancamentos),
            "adicionados": len(lancamentos),
            "comErro": len(erros),
            "erros": erros,
            "total": len(registros),
        }

"""Importacao de notas em lote por planilha (CSV ou XLSX).

Exclusivo do Professor, e so em atividade de turma vinculada a ele.
A planilha identifica o aluno por matricula ou, na falta dela, pelo nome.

Regra de identificacao (Marco 4 / A04): matricula manda quando informada -
se nao bater com ninguem da turma, a linha vira erro, nunca cai para o
nome (uma matricula digitada errada podia, antes, acertar por acaso o
nome de outro aluno). Nome so decide a linha quando NAO ha matricula
informada, e so quando aquele nome pertence a exatamente um aluno da
turma - nomes duplicados nunca sao resolvidos por adivinhacao.
"""

from collections import Counter

from models.aluno_model import Aluno
from models.atividade_model import Atividade
from models.etapa_model import Etapa
from models.nota_model import Nota
from models.professor_turma_model import ProfessorTurma
from services.config.anos_letivos import AnoEncerrado
from services.planilha.leitor import PlanilhaInvalida, ler_planilha
from services.professor.notas import exigir_ano_aberto_da_atividade
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

        try:
            exigir_ano_aberto_da_atividade(atividade)
        except AnoEncerrado as erro:
            raise PlanilhaInvalida(str(erro))

        if atividade.get("etapa_id") and Etapa.esta_fechada(
            atividade["etapa_id"], atividade["coordenacao_id"]
        ):
            raise PlanilhaInvalida(
                "Nao e possivel importar notas: a etapa ja esta fechada."
            )

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

        # Nomes duplicados ficam de fora do dict de proposito: um nome que
        # aparece em mais de um aluno da turma nunca deve resolver sozinho
        # para um dos dois - fica ausente, entao por_nome.get() sempre
        # devolve None para ele, e a linha vira erro explicito la embaixo.
        nomes = [a["nome"].strip().lower() for a in alunos]
        contagem_nomes = Counter(nomes)
        por_nome = {
            nome: a["id"]
            for a, nome in zip(alunos, nomes)
            if contagem_nomes[nome] == 1
        }

        lancamentos = []
        erros = []
        ja_lancados = set()

        for numero, registro in registros:
            matricula = (registro.get("matricula") or "").strip()
            nome = (registro.get("aluno") or "").strip().lower()

            if matricula:
                # Matricula informada manda: se nao bate com ninguem desta
                # turma, e erro - nunca tenta adivinhar pelo nome.
                aluno_id = por_matricula.get(matricula)
                if aluno_id is None:
                    erros.append({
                        "linha": numero,
                        "motivo": "matricula nao encontrada nesta turma",
                    })
                    continue
            elif nome:
                aluno_id = por_nome.get(nome)
                if aluno_id is None:
                    motivo = (
                        "nome duplicado nesta turma - informe a matricula"
                        if contagem_nomes.get(nome, 0) > 1
                        else "aluno nao encontrado nesta turma"
                    )
                    erros.append({"linha": numero, "motivo": motivo})
                    continue
            else:
                erros.append({
                    "linha": numero,
                    "motivo": "informe a matricula ou o nome do aluno",
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

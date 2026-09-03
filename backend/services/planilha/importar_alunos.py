"""Importacao de alunos em lote por planilha (CSV ou XLSX).

Comportamento escolhido: importa as linhas validas e devolve a lista de
erros das invalidas. Rejeitar a planilha inteira por causa de uma linha
errada obrigaria o usuario a corrigir e reenviar tudo.
"""

from models.aluno_model import Aluno
from services.aluno.acesso_turma import turma_acessivel
from services.planilha.leitor import PlanilhaInvalida, exigir_colunas, ler_planilha
from services.planilha.validacao import validar_linha_aluno

LIMITE_LINHAS = 2000


class ImportarAlunosService:
    def execute(self, turma_id, coordenacao_id, nome_arquivo, conteudo,
                professor_id=None):
        turma_acessivel(turma_id, coordenacao_id, professor_id)

        if not conteudo:
            raise PlanilhaInvalida("Nenhum arquivo foi enviado")

        colunas, registros = ler_planilha(nome_arquivo, conteudo)
        exigir_colunas(colunas, ["nome"])

        if len(registros) > LIMITE_LINHAS:
            raise PlanilhaInvalida(
                "A planilha tem %d linhas; o limite e %d"
                % (len(registros), LIMITE_LINHAS)
            )

        # Matriculas ja usadas na turma, para nao depender do erro da UNIQUE
        # e conseguir apontar a linha exata do problema.
        existentes = {
            aluno["matricula"]
            for aluno in Aluno.find_all_by_turma(turma_id)
            if aluno.get("matricula")
        }

        validos = []
        erros = []
        vistas_no_arquivo = set()

        for numero, registro in registros:
            dados, erro = validar_linha_aluno(registro)
            if erro:
                erros.append({"linha": numero, "motivo": erro})
                continue

            matricula = dados.get("matricula")
            if matricula:
                if matricula in existentes:
                    erros.append({
                        "linha": numero,
                        "motivo": "matricula %s ja existe na turma" % matricula,
                    })
                    continue
                if matricula in vistas_no_arquivo:
                    erros.append({
                        "linha": numero,
                        "motivo": "matricula %s repetida na planilha" % matricula,
                    })
                    continue
                vistas_no_arquivo.add(matricula)

            validos.append(dados)

        if validos:
            Aluno.create_em_lote(turma_id, validos)

        return {
            "adicionados": len(validos),
            "comErro": len(erros),
            "erros": erros,
            "total": len(registros),
        }

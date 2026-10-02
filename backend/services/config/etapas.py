from datetime import date

from models.aluno_model import Aluno
from models.criterio_model import Criterio
from models.etapa_model import Etapa
from models.turma_model import Turma
from services.academico.calculo import calcular_desempenho_etapa, resumo_pesos


class ListarEtapasService:
    """Etapas configuradas pela escola.

    E o que faz a configuracao ser PADRAO DA ESCOLA: o app chama isto ao
    abrir o fluxo e, se ja houver etapas, edita as existentes em vez de
    montar tudo de novo.
    """

    def execute(self, coordenacao_id, ano_letivo=None):
        linhas = Etapa.find_all_by_coordenacao(coordenacao_id, ano_letivo)
        resultado = []
        for linha in linhas:
            etapa = Etapa.to_dict(linha)
            criterios = Criterio.find_all_by_etapa(linha["id"], coordenacao_id)
            etapa["criterios"] = [Criterio.to_dict(c) for c in criterios]
            # Feedback imediato pra tela de configuracao: sem isso a
            # Coordenacao so descobre que os pesos estao errados quando
            # o Professor tentar ver o desempenho de um aluno.
            soma, valido = resumo_pesos(criterios)
            etapa["pesoTotal"] = soma
            etapa["pesoValido"] = valido
            resultado.append(etapa)
        return resultado


class BuscarEtapaService:
    def execute(self, etapa_id, coordenacao_id):
        linha = Etapa.find_by_id(etapa_id, coordenacao_id)
        if not linha:
            raise LookupError("Etapa nao encontrada")
        etapa = Etapa.to_dict(linha)
        criterios = Criterio.find_all_by_etapa(etapa_id, coordenacao_id)
        etapa["criterios"] = [Criterio.to_dict(c) for c in criterios]
        soma, valido = resumo_pesos(criterios)
        etapa["pesoTotal"] = soma
        etapa["pesoValido"] = valido
        return etapa


class SalvarEtapaService:
    """Cria a etapa, ou atualiza a que ja existe naquela ordem/ano.

    Usa upsert de proposito: passar pelo fluxo de configuracao de novo nao
    pode duplicar as etapas da escola.
    """

    def execute(self, coordenacao_id, nome, ordem, ano_letivo=None,
                data_inicio=None, data_fim=None, ativa=True):
        nome = (nome or "").strip()
        if not nome:
            raise ValueError("O nome da etapa e obrigatorio")

        try:
            ordem = int(ordem)
        except (TypeError, ValueError):
            raise ValueError("A ordem da etapa e obrigatoria")
        if ordem < 1:
            raise ValueError("A ordem da etapa precisa ser 1 ou maior")

        ano_letivo = int(ano_letivo or date.today().year)

        etapa_id = Etapa.upsert(
            coordenacao_id, nome, ordem, ano_letivo, data_inicio, data_fim, ativa
        )
        return Etapa.to_dict(Etapa.find_by_id(etapa_id, coordenacao_id))


class AtualizarEtapaService:
    def execute(self, etapa_id, coordenacao_id, nome=None, ordem=None,
                data_inicio=None, data_fim=None, ativa=None):
        if not Etapa.find_by_id(etapa_id, coordenacao_id):
            raise LookupError("Etapa nao encontrada")
        if nome is not None and not nome.strip():
            raise ValueError("O nome da etapa nao pode ficar vazio")
        Etapa.update(
            etapa_id, coordenacao_id, nome, ordem, data_inicio, data_fim, ativa
        )
        return Etapa.to_dict(Etapa.find_by_id(etapa_id, coordenacao_id))


class DefinirNotasEtapaService:
    """Grava a nota minima e maxima de uma etapa.

    Fica separado do upsert da etapa para que reconfigurar o ano letivo nao
    apague as notas que ja tinham sido definidas.
    """

    def execute(self, etapa_id, coordenacao_id, nota_minima, nota_maxima):
        if not Etapa.find_by_id(etapa_id, coordenacao_id):
            raise LookupError("Etapa nao encontrada")

        try:
            nota_minima = float(str(nota_minima).replace(",", "."))
            nota_maxima = float(str(nota_maxima).replace(",", "."))
        except (TypeError, ValueError):
            raise ValueError("Informe numeros validos para as notas")

        if nota_minima < 0 or nota_maxima < 0:
            raise ValueError("As notas nao podem ser negativas")
        if nota_minima >= nota_maxima:
            raise ValueError("A nota minima precisa ser menor que a maxima")

        Etapa.definir_notas(etapa_id, coordenacao_id, nota_minima, nota_maxima)
        return Etapa.to_dict(Etapa.find_by_id(etapa_id, coordenacao_id))


class ExcluirEtapaService:
    def execute(self, etapa_id, coordenacao_id):
        if not Etapa.find_by_id(etapa_id, coordenacao_id):
            raise LookupError("Etapa nao encontrada")
        Etapa.delete(etapa_id, coordenacao_id)


def _contar_alunos_incompletos(etapa):
    """Quantos alunos da escola ainda tem atividade sem nota nesta etapa.

    Etapa e configuracao da escola inteira (nao de uma turma so), entao
    percorre todas as turmas. Nao inventa nenhuma regra nova: usa o mesmo
    calcular_desempenho_etapa que o boletim e o dashboard ja chamam, e so
    conta quem tem "atividades_sem_nota" > 0. O fechamento continua sendo
    permitido de qualquer forma - isto e so para a Coordenacao decidir com
    informacao, nao para bloquear nada (Marco 4).
    """
    incompletos = 0
    for turma in Turma.find_all_by_coordenacao(etapa["coordenacao_id"]):
        for aluno in Aluno.find_all_by_turma(turma["id"]):
            resultado = calcular_desempenho_etapa(aluno["id"], turma["id"], etapa)
            if resultado["atividades_sem_nota"] > 0:
                incompletos += 1
    return incompletos


class FecharEtapaService:
    """Fecha a etapa: o resultado calculado fica congelado ate a reabertura.

    So a Coordenacao chama isto (rota com @coordenacao_required). Depois do
    fechamento, criar/editar atividade e lancar/importar nota nesta etapa
    passam a ser recusados - ver services/activity/validacao.py e
    services/professor/notas.py.

    O fechamento NAO e bloqueado por aluno incompleto (decisao do Marco 4):
    a Coordenacao pode ter motivo legitimo para fechar mesmo assim (aluno
    evadido, por exemplo). O que muda e que a resposta agora informa
    quantos alunos ficam com atividade sem nota nesta etapa, para a
    Coordenacao decidir com informacao em vez de descobrir depois.
    """

    def execute(self, etapa_id, coordenacao_id):
        etapa = Etapa.find_by_id(etapa_id, coordenacao_id)
        if not etapa:
            raise LookupError("Etapa nao encontrada")
        if etapa.get("fechada"):
            raise ValueError("Etapa ja esta fechada")

        alunos_incompletos = _contar_alunos_incompletos(etapa)

        Etapa.fechar(etapa_id, coordenacao_id)
        resultado = Etapa.to_dict(Etapa.find_by_id(etapa_id, coordenacao_id))
        resultado["alunosIncompletos"] = alunos_incompletos
        return resultado


class ReabrirEtapaService:
    """Reabre uma etapa fechada, para a Coordenacao corrigir alguma nota."""

    def execute(self, etapa_id, coordenacao_id):
        etapa = Etapa.find_by_id(etapa_id, coordenacao_id)
        if not etapa:
            raise LookupError("Etapa nao encontrada")
        if not etapa.get("fechada"):
            raise ValueError("Etapa ja esta aberta")
        Etapa.reabrir(etapa_id, coordenacao_id)
        return Etapa.to_dict(Etapa.find_by_id(etapa_id, coordenacao_id))

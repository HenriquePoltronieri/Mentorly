from models.aluno_model import Aluno
from models.atividade_model import Atividade
from models.nota_model import Nota
from models.professor_turma_model import ProfessorTurma


def _atividade_do_professor(atividade_id, professor_id):
    """Guarda comum: a atividade precisa ser de uma turma do professor."""
    atividade = Atividade.find_by_id(atividade_id)
    if not atividade:
        raise LookupError("Atividade nao encontrada")
    if not ProfessorTurma.professor_leciona_na_turma(
        professor_id, atividade["turma_id"]
    ):
        raise LookupError("Atividade nao encontrada")
    return atividade


class ListarNotasService:
    """Alunos da turma da atividade, com a nota de cada um (ou vazia).

    Devolve todos os alunos, e nao so quem ja tem nota, porque a tela de
    lancamento precisa listar a turma inteira.
    """

    def execute(self, atividade_id, professor_id):
        atividade = _atividade_do_professor(atividade_id, professor_id)
        linhas = Nota.find_by_atividade(atividade_id)
        return {
            "atividade": Atividade.to_dict(atividade),
            "notas": [Nota.to_dict(linha) for linha in linhas],
        }


class LancarNotasService:
    """Lancamento manual de notas, uma ou varias de uma vez.

    Aceita tanto {"aluno_id":..,"nota":..} quanto uma lista em "notas",
    porque a tela envia a turma inteira de uma vez.
    """

    def execute(self, atividade_id, professor_id, payload):
        atividade = _atividade_do_professor(atividade_id, professor_id)

        brutas = payload.get("notas")
        if brutas is None:
            brutas = [payload]

        # Quem pode receber nota nesta atividade: os alunos da turma DELA.
        # Sem esta lista, trocar o aluno_id na requisicao lancava nota em
        # aluno de outra turma - a FK de nota aponta para aluno(id) global,
        # entao o banco aceitaria. Uma consulta so, fora do laco.
        alunos_da_turma = {
            aluno["id"] for aluno in Aluno.find_all_by_turma(
                atividade["turma_id"]
            )
        }

        nota_maxima = atividade.get("nota_maxima")
        lancamentos = []
        for item in brutas:
            aluno_id = item.get("aluno_id") or item.get("alunoId")
            valor = item.get("valor")
            if valor is None:
                valor = item.get("nota")

            if aluno_id is None:
                raise ValueError("Informe o aluno de cada nota")
            if valor is None or str(valor).strip() == "":
                # Campo em branco na tela = nota ainda nao lancada, ignora.
                continue

            try:
                aluno_id = int(aluno_id)
            except (TypeError, ValueError):
                raise ValueError("Aluno invalido")

            # 404 e nao 403: confirmar que o aluno existe em outra turma ja
            # seria vazar dado de outra turma (ou de outra escola).
            if aluno_id not in alunos_da_turma:
                raise LookupError("Aluno nao encontrado nesta turma")

            try:
                valor = float(str(valor).replace(",", "."))
            except ValueError:
                raise ValueError("Nota invalida para o aluno %s" % aluno_id)

            if valor < 0:
                raise ValueError("A nota nao pode ser negativa")
            # Atividade sem valor maximo e legado: nao da para dizer se a
            # nota cabe, entao recusa em vez de aceitar qualquer numero.
            if nota_maxima is None:
                raise ValueError(
                    "Esta atividade ainda nao tem valor maximo definido. "
                    "Edite a atividade e informe quanto ela vale."
                )
            if valor > float(nota_maxima):
                raise ValueError(
                    "A nota nao pode passar de %s" % _limpo(nota_maxima)
                )

            lancamentos.append({
                "aluno_id": aluno_id,
                "valor": valor,
                "observacao": item.get("observacao"),
            })

        if lancamentos:
            Nota.lancar_em_lote(atividade_id, lancamentos)

        return {"lancadas": len(lancamentos)}


def _limpo(valor):
    """20.0 vira "20"; 13.5 continua "13.5". So para a mensagem de erro."""
    numero = float(valor)
    return str(int(numero)) if numero == int(numero) else str(numero)

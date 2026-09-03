from models.aluno_model import Aluno
from services.aluno.acesso_turma import turma_acessivel
from services.planilha.validacao import validar_linha_aluno


class CadastrarAlunoService:
    """Cadastro manual de um aluno em uma turma.

    Usa a mesma validacao da importacao por planilha (nome completo
    obrigatorio), para o cadastro manual e o em lote nao aceitarem coisas
    diferentes.
    """

    def execute(self, turma_id, coordenacao_id, nome, matricula=None,
                email=None, professor_id=None):
        turma_acessivel(turma_id, coordenacao_id, professor_id)

        dados, erro = validar_linha_aluno(
            {"nome": nome, "matricula": matricula, "email": email}
        )
        if erro:
            raise ValueError(erro)

        if dados.get("matricula") and Aluno.find_by_matricula(
            turma_id, dados["matricula"]
        ):
            raise ValueError("Ja existe um aluno com esta matricula na turma")

        aluno_id = Aluno.create(
            turma_id, dados["nome"], dados.get("matricula"), dados.get("email")
        )
        return Aluno.to_dict(Aluno.find_by_id(aluno_id))

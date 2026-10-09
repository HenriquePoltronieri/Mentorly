"""Edicao e exclusao de aluno (Marco 4).

Aluno.update e Aluno.delete ja existiam no model, sem nenhuma rota que os
chamasse. Aqui so amarra a autorizacao: aluno_acessivel resolve a turma do
aluno e confere a escola (e o vinculo do professor, quando for o caso)
antes de mexer em qualquer coisa - a mesma guarda usada por
ListarAlunosService, CadastrarAlunoService e EstatisticasAlunoService.
Coordenacao e Professor tem os mesmos direitos aqui que ja tinham para
cadastrar aluno (professor_id=None para Coordenacao, id do professor para
Professor).
"""

from models.aluno_model import Aluno
from services import entrada
from services.aluno.acesso_turma import aluno_acessivel
from services.planilha.validacao import validar_email, validar_nome_completo


class AtualizarAlunoService:
    """So mexe nos campos que vieram na requisicao (campo omitido preserva
    o valor atual - mesmo padrao de Turma.update/Etapa.update)."""

    def execute(self, aluno_id, coordenacao_id, nome=None, matricula=None,
                email=None, professor_id=None):
        aluno = aluno_acessivel(aluno_id, coordenacao_id, professor_id)

        if nome is not None:
            nome, erro = validar_nome_completo(nome)
            if erro:
                raise ValueError(erro)

        if matricula is not None:
            if not isinstance(matricula, str):
                raise ValueError("matricula invalida")
            if len(matricula.strip()) > entrada.LIMITE_MATRICULA:
                raise ValueError(
                    "matricula muito longa (maximo %d caracteres)"
                    % entrada.LIMITE_MATRICULA
                )
            matricula = matricula.strip() or None
            if matricula:
                existente = Aluno.find_by_matricula(aluno["turma_id"], matricula)
                if existente and existente["id"] != aluno_id:
                    raise ValueError(
                        "Ja existe um aluno com esta matricula na turma"
                    )

        if email is not None:
            email, erro = validar_email(email)
            if erro:
                raise ValueError(erro)

        Aluno.update(aluno_id, nome, matricula, email)
        return Aluno.to_dict(Aluno.find_by_id(aluno_id))


class ExcluirAlunoService:
    """Exclui o aluno. As notas dele caem junto (fk_nota_aluno e CASCADE no
    schema, o mesmo jeito que excluir turma ja cascateia aluno/nota)."""

    def execute(self, aluno_id, coordenacao_id, professor_id=None):
        aluno_acessivel(aluno_id, coordenacao_id, professor_id)
        Aluno.delete(aluno_id)

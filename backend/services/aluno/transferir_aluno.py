"""Transferencia administrativa de aluno, preservando o historico."""

from models.aluno_model import Aluno
from models.aluno_turma_historico_model import AlunoTurmaHistorico


class TransferirAlunoService:
    def execute(self, aluno_id, coordenacao_id, turma_destino_id, motivo=None):
        if not isinstance(turma_destino_id, int):
            raise ValueError("Informe a turma de destino")
        if motivo is not None:
            motivo = str(motivo).strip() or None
            if motivo and len(motivo) > 255:
                raise ValueError("O motivo deve ter no maximo 255 caracteres")
        AlunoTurmaHistorico.transferir(
            aluno_id, coordenacao_id, turma_destino_id, motivo)
        return Aluno.to_dict(Aluno.find_com_turma(aluno_id))


class HistoricoAlunoService:
    def execute(self, aluno_id, coordenacao_id):
        aluno = Aluno.find_com_turma(aluno_id)
        if not aluno or aluno["coordenacao_id"] != coordenacao_id:
            raise LookupError("Aluno nao encontrado")
        return [AlunoTurmaHistorico.to_dict(linha)
                for linha in AlunoTurmaHistorico.find_by_aluno(aluno_id)]

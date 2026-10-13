"""Consulta mínima para o primeiro acesso; não consome nem expõe o token."""
from datetime import datetime
from models.professor_model import Professor
from services import entrada


class ConsultarConviteService:
    def execute(self, token):
        token = entrada.texto(token, "O convite", entrada.LIMITE_CODIGO)
        if not token:
            raise ValueError("Token inválido ou ausente. Acesse pelo link do e-mail.")
        professor = Professor.find_by_convite(token)
        if not professor or professor.get("senha_hash"):
            raise PermissionError("Convite inválido ou já utilizado. Peça um novo à Coordenação.")
        if not professor.get("habilitado", True):
            raise PermissionError("Professor desativado. Procure a Coordenação.")
        expira = professor.get("convite_expira_em")
        if not expira or expira < datetime.now():
            raise PermissionError("Convite expirado. Peça um novo à Coordenação.")
        return {"email": professor["email"]}

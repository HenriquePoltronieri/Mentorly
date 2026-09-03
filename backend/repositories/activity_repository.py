"""Consultas de atividade que nao sao CRUD simples."""

from database.procedure import call_procedure
from models.utils import normalizar_lista


class ActivityRepository:
    def buscar_atividades(self, coordenacao_id, professor_id=None, termo=None,
                          ordenar_por=None, direcao=None):
        """Busca por termo no titulo, com ordenacao (procedure).

        professor_id None = visao da Coordenacao (toda a escola).
        professor_id preenchido = so as turmas vinculadas aquele professor.
        """
        return normalizar_lista(
            call_procedure(
                "sp_buscar_atividades",
                coordenacao_id, professor_id, termo, ordenar_por, direcao,
            )
        )

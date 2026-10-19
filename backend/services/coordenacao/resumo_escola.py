"""Caso de uso do resumo administrativo da escola."""

from repositories.consultas import resumo_da_escola


class ResumoEscolaService:
    def execute(self, coordenacao_id):
        return resumo_da_escola(coordenacao_id)

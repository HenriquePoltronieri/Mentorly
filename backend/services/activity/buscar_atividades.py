"""Caso de uso de busca de atividades com filtro e ordenacao no banco."""

from repositories.consultas import buscar_atividades


class BuscarAtividadesService:
    def execute(self, coordenacao_id, professor_id, termo, ordenar_por, direcao):
        return buscar_atividades(coordenacao_id, professor_id, termo,
                                ordenar_por, direcao)

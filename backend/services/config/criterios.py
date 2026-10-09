from models.criterio_model import Criterio
from models.etapa_model import Etapa
from services.config.etapas import exigir_etapa_aberta


def _exigir_etapa_do_criterio_aberta(criterio, coordenacao_id):
    """O criterio ja foi achado na escola; so entao se olha a etapa dele."""
    etapa = Etapa.find_by_id(criterio["etapa_id"], coordenacao_id)
    if etapa:
        exigir_etapa_aberta(etapa)


class ListarCriteriosService:
    def execute(self, etapa_id, coordenacao_id):
        if not Etapa.find_by_id(etapa_id, coordenacao_id):
            raise LookupError("Etapa nao encontrada")
        return [
            Criterio.to_dict(c)
            for c in Criterio.find_all_by_etapa(etapa_id, coordenacao_id)
        ]


class BuscarCriterioService:
    def execute(self, criterio_id, coordenacao_id):
        linha = Criterio.find_by_id(criterio_id, coordenacao_id)
        if not linha:
            raise LookupError("Criterio nao encontrado")
        return Criterio.to_dict(linha)


class SalvarCriterioService:
    """Cria o criterio na etapa, ou atualiza o que ja existe com o mesmo nome.

    Upsert pelo mesmo motivo das etapas: repetir o fluxo de configuracao nao
    pode encher a escola de criterios duplicados.
    """

    def execute(self, etapa_id, coordenacao_id, nome, peso=0, nota_maxima=10):
        etapa = Etapa.find_by_id(etapa_id, coordenacao_id)
        if not etapa:
            raise LookupError("Etapa nao encontrada")
        exigir_etapa_aberta(etapa)

        nome = (nome or "").strip()
        if not nome:
            raise ValueError("O nome do criterio e obrigatorio")

        criterio_id = Criterio.upsert(
            coordenacao_id, etapa_id, nome, peso or 0,
            nota_maxima if nota_maxima is not None else 10,
        )
        return Criterio.to_dict(Criterio.find_by_id(criterio_id, coordenacao_id))


class AtualizarCriterioService:
    def execute(self, criterio_id, coordenacao_id, nome=None, peso=None,
                nota_maxima=None):
        criterio = Criterio.find_by_id(criterio_id, coordenacao_id)
        if not criterio:
            raise LookupError("Criterio nao encontrado")
        _exigir_etapa_do_criterio_aberta(criterio, coordenacao_id)
        if nome is not None and not nome.strip():
            raise ValueError("O nome do criterio nao pode ficar vazio")
        Criterio.update(criterio_id, coordenacao_id, nome, peso, nota_maxima)
        return Criterio.to_dict(Criterio.find_by_id(criterio_id, coordenacao_id))


class ExcluirCriterioService:
    def execute(self, criterio_id, coordenacao_id):
        criterio = Criterio.find_by_id(criterio_id, coordenacao_id)
        if not criterio:
            raise LookupError("Criterio nao encontrado")
        _exigir_etapa_do_criterio_aberta(criterio, coordenacao_id)
        Criterio.delete(criterio_id, coordenacao_id)

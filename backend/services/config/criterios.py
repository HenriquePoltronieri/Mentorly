from models.criterio_model import Criterio
from models.etapa_model import Etapa


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
        if not Etapa.find_by_id(etapa_id, coordenacao_id):
            raise LookupError("Etapa nao encontrada")

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
        if not Criterio.find_by_id(criterio_id, coordenacao_id):
            raise LookupError("Criterio nao encontrado")
        if nome is not None and not nome.strip():
            raise ValueError("O nome do criterio nao pode ficar vazio")
        Criterio.update(criterio_id, coordenacao_id, nome, peso, nota_maxima)
        return Criterio.to_dict(Criterio.find_by_id(criterio_id, coordenacao_id))


class ExcluirCriterioService:
    def execute(self, criterio_id, coordenacao_id):
        if not Criterio.find_by_id(criterio_id, coordenacao_id):
            raise LookupError("Criterio nao encontrado")
        Criterio.delete(criterio_id, coordenacao_id)

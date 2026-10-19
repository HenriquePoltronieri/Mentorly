"""Casos de uso do painel administrativo das escolas."""

from repositories.admin_consultas import historico_recente, planos_disponiveis
from services import acesso_escola


class ListarEscolasAdminService:
    def execute(self, busca):
        busca = busca.strip().lower()[:150]
        escolas = acesso_escola.listar()
        if busca:
            escolas = [e for e in escolas if busca in (e['nome'] + ' ' + e['email']).lower()]
        historico = historico_recente()
        for escola in escolas:
            escola['valido_ate'] = escola['valido_ate'].isoformat() if escola.get('valido_ate') else None
        for registro in historico:
            for campo in ('valido_ate', 'criado_em'):
                registro[campo] = registro[campo].isoformat() if registro.get(campo) else None
        return {'escolas': escolas, 'historico': historico,
                'planos': planos_disponiveis(), 'situacoes': acesso_escola.SITUACOES}


class AlterarAcessoAdminService:
    def execute(self, escola_id, administrador_id, dados):
        return acesso_escola.alterar(escola_id, administrador_id, dados)

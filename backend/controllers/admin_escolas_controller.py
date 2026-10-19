"""HTTP do recurso escolas no painel administrativo."""

from flask import g, jsonify, request

from services.admin_escolas import AlterarAcessoAdminService, ListarEscolasAdminService
from services.excluir_escola import ExcluirEscolaService


class AdminEscolasController:
    def listar(self):
        return jsonify(ListarEscolasAdminService().execute(request.args.get('q', '')))

    def salvar_acesso(self, escola_id):
        try:
            AlterarAcessoAdminService().execute(
                escola_id, g.administrador['id'], request.get_json(silent=True) or {})
        except ValueError as erro:
            return jsonify({'error': str(erro)}), 400
        return jsonify({'mensagem': 'Acesso atualizado para a coordenação e seus professores.'})

    def excluir(self, escola_id):
        try:
            dados = request.get_json(silent=True) or {}
            ExcluirEscolaService().execute(escola_id, dados.get('email_confirmacao'))
        except ValueError as erro:
            return jsonify({'error': str(erro)}), 400
        return jsonify({'mensagem': 'Conta de coordenacao excluida definitivamente.'})

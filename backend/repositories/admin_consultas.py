"""Consultas de painel com joins de escolas, planos e auditoria."""

from database.connection import query_all


def escolas_com_acesso():
    return query_all('SELECT c.id,c.nome,c.email,a.plano_codigo,a.situacao,a.valido_ate,a.versao, '
                     'p.nome AS plano_nome FROM coordenacao c '
                     'LEFT JOIN acesso_escola a ON a.coordenacao_id=c.id '
                     'LEFT JOIN plano p ON p.codigo=a.plano_codigo ORDER BY c.nome,c.id')


def historico_recente():
    return query_all('SELECT h.*,c.nome AS escola,ad.nome AS administrador FROM acesso_historico h '
                     'JOIN coordenacao c ON c.id=h.coordenacao_id '
                     'JOIN administrador ad ON ad.id=h.administrador_id ORDER BY h.id DESC LIMIT 50')


def planos_disponiveis():
    return query_all('SELECT * FROM plano ORDER BY nome')

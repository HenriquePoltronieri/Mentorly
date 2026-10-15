"""Plano e prazo pertencem a escola. O servidor confere a cada requisicao."""
from datetime import timedelta
from services.horario import agora_brasilia

from database.connection import query_one, query_all, execute, transacao
from services import entrada

SITUACOES = {'teste': 'Teste gratuito', 'paga': 'Assinatura paga',
             'cortesia': 'Cortesia', 'suspensa': 'Suspensa', 'pendente': 'Aguardando liberação'}


def hoje():
    return agora_brasilia().date()


def apresentar(linha, data=None):
    data = data or hoje()
    if not linha:
        return {'liberado': False, 'situacao': 'pendente',
                'situacao_nome': SITUACOES['pendente'], 'valido_ate': None,
                'mensagem': 'Peça à administração do Mentorly para liberar sua escola.'}
    prazo = linha.get('valido_ate')
    liberado = (linha['situacao'] in ('teste', 'paga', 'cortesia') and
                ((prazo is not None and prazo >= data) or
                 (prazo is None and linha['situacao'] == 'cortesia')))
    return {**linha, 'valido_ate': prazo.isoformat() if prazo else None,
            'liberado': liberado, 'situacao_nome': SITUACOES[linha['situacao']],
            'mensagem': 'Acesso liberado.' if liberado else
            'O acesso da escola está suspenso ou venceu. Peça a liberação à administração do Mentorly.'}


def consultar(escola_id):
    linha = query_one('SELECT a.*, p.nome AS plano_nome FROM acesso_escola a '
                      'JOIN plano p ON p.codigo=a.plano_codigo WHERE coordenacao_id=%s', (escola_id,))
    return apresentar(linha)


def iniciar_teste(escola_id):
    # INSERT IGNORE preserva uma liberacao existente e nunca renova o teste.
    execute('INSERT IGNORE INTO acesso_escola(coordenacao_id,valido_ate) VALUES (%s,%s)',
            (escola_id, hoje() + timedelta(days=14)))


def cadastrar_escolas_existentes():
    execute('INSERT IGNORE INTO acesso_escola(coordenacao_id,valido_ate) '
            'SELECT id,%s FROM coordenacao', (hoje() + timedelta(days=14),))


def listar():
    linhas = query_all('SELECT c.id,c.nome,c.email,a.plano_codigo,a.situacao,a.valido_ate,a.versao, '
                       'p.nome AS plano_nome FROM coordenacao c '
                       'LEFT JOIN acesso_escola a ON a.coordenacao_id=c.id '
                       'LEFT JOIN plano p ON p.codigo=a.plano_codigo ORDER BY c.nome,c.id')
    return [{**l, 'acesso': apresentar(l if l.get('situacao') else None)} for l in linhas]


def alterar(escola_id, admin_id, dados):
    from datetime import date
    situacao = dados.get('situacao')
    if not isinstance(situacao, str) or situacao not in SITUACOES:
        raise ValueError('Escolha uma situação de acesso válida.')
    plano = entrada.texto(dados.get('plano_codigo'), 'O plano', 40)
    if not query_one('SELECT codigo FROM plano WHERE codigo=%s', (plano,)):
        raise ValueError('Escolha um plano cadastrado.')
    motivo = entrada.texto(dados.get('motivo'), 'O motivo', 500)
    if not motivo:
        raise ValueError('Informe o motivo da alteração para manter o histórico.')
    try:
        prazo = date.fromisoformat(dados['valido_ate']) if dados.get('valido_ate') else None
    except (ValueError, TypeError):
        raise ValueError('Informe uma data válida.')
    if prazo is not None and prazo.year < 1000:
        raise ValueError('Informe uma data a partir do ano 1000.')
    if situacao in ('teste', 'paga') and (prazo is None or prazo < hoje()):
        raise ValueError('Teste e assinatura paga precisam de validade a partir de hoje.')
    versao = entrada.inteiro(dados.get('versao'), 'A versão do acesso')
    with transacao() as c:
        c.execute('SELECT versao FROM acesso_escola WHERE coordenacao_id=%s FOR UPDATE', (escola_id,))
        atual = c.fetchone()
        if not atual or atual['versao'] != versao:
            raise ValueError('Este acesso já foi alterado. Atualize a página antes de salvar novamente.')
        c.execute('UPDATE acesso_escola SET plano_codigo=%s,situacao=%s,valido_ate=%s,versao=versao+1 '
                  'WHERE coordenacao_id=%s', (plano, situacao, prazo, escola_id))
        c.execute('INSERT INTO acesso_historico(coordenacao_id,administrador_id,situacao,plano_codigo,valido_ate,motivo) '
                  'VALUES (%s,%s,%s,%s,%s,%s)', (escola_id, admin_id, situacao, plano, prazo, motivo))

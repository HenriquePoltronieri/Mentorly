from html import escape
from flask import Blueprint, request, jsonify, Response
from auth.decorators import professor_required, usuario_atual_id, coordenacao_atual, token_na_url_so_neste_download
from services.professor.trabalho import (painel_trabalho, turma_autorizada, listar_acompanhamentos,
                                        criar_acompanhamento, concluir_acompanhamento)
from services.professor.estatisticas_turma import EstatisticasTurmaService
from models.atividade_model import Atividade
from models.ano_letivo_model import AnoLetivo
from database.connection import query_all
from services.entrada import inteiro
from erros import RecursoNaoEncontrado

trabalho_blueprint = Blueprint('trabalho', __name__, url_prefix='/api/professor')


def responder(acao):
    try:
        return jsonify(acao())
    except RecursoNaoEncontrado as erro:
        return jsonify({'error': str(erro)}), 404
    except ValueError as erro:
        return jsonify({'error': str(erro)}), 400


@trabalho_blueprint.get('/trabalho')
@professor_required
def trabalho():
    return responder(lambda: painel_trabalho(usuario_atual_id(), coordenacao_atual()))


def grade_dados(turma_id):
    turma = turma_autorizada(usuario_atual_id(), coordenacao_atual(), turma_id)
    ano = AnoLetivo.find_by_ano(coordenacao_atual(), turma['ano_letivo'])
    etapa = request.args.get('etapa_id')
    etapa = inteiro(etapa, 'Etapa') if etapa is not None else None
    dados = EstatisticasTurmaService().execute(usuario_atual_id(), coordenacao_atual(), turma_id, etapa)
    atividades = Atividade.find_all_by_professor(usuario_atual_id(), turma_id)
    situacoes = query_all('SELECT s.aluno_id,s.atividade_id,s.situacao FROM atividade_situacao s '
                         'JOIN atividade a ON a.id=s.atividade_id WHERE a.turma_id=%s', (turma_id,))
    mapa = {(s['aluno_id'], s['atividade_id']): s['situacao'] for s in situacoes}
    for aluno in dados['alunos']:
        for atividade in aluno['atividades']:
            atividade['situacao'] = mapa.get((aluno['id'], atividade['id']), atividade['status'])
    return {**dados, 'somente_leitura': bool(ano and ano['status'] == 'encerrado'), 'atividades_cadastro': [Atividade.to_dict(a) for a in atividades
                                            if etapa is None or a['etapa_id'] == etapa]}


@trabalho_blueprint.get('/turmas/<int:turma_id>/grade')
@professor_required
def grade(turma_id):
    return responder(lambda: grade_dados(turma_id))


@trabalho_blueprint.route('/turmas/<int:turma_id>/alunos/<int:aluno_id>/acompanhamentos', methods=['GET', 'POST'])
@professor_required
def acompanhamentos(turma_id, aluno_id):
    def acao():
        turma_autorizada(usuario_atual_id(), coordenacao_atual(), turma_id)
        if request.method == 'GET':
            return listar_acompanhamentos(usuario_atual_id(), coordenacao_atual(), turma_id, aluno_id)
        return criar_acompanhamento(usuario_atual_id(), coordenacao_atual(), turma_id, aluno_id, request.get_json(silent=True) or {})
    return responder(acao)


@trabalho_blueprint.put('/acompanhamentos/<int:registro_id>')
@professor_required
def concluir(registro_id):
    return responder(lambda: concluir_acompanhamento(usuario_atual_id(), coordenacao_atual(), registro_id, request.get_json(silent=True) or {}))


@trabalho_blueprint.get('/turmas/<int:turma_id>/resumo-reuniao')
@professor_required
@token_na_url_so_neste_download
def resumo_reuniao(turma_id):
    try:
        dados = grade_dados(turma_id)
        registros = listar_acompanhamentos(usuario_atual_id(), coordenacao_atual(), turma_id)
        def h(valor):
            return escape(str(valor if valor is not None else '—'))
        linhas = ''.join('<tr><td>'+h(a['nome'])+'</td><td>'+h(a['risco'])+'</td><td>'+
                         h(a['pontos_obtidos'])+' / '+h(a['pontos_avaliados'])+'</td><td>'+h(a['sem_nota'])+'</td></tr>'
                         for a in dados['alunos'])
        notas = ''.join('<li><strong>'+h(r['aluno'])+'</strong> · Retorno: '+h(r['retorno_em'])+
                        ' · '+('Concluído' if r['concluido'] else 'Em acompanhamento')+'<p>'+h(r['descricao'])+'</p></li>' for r in registros)
        etapa = next((e['nome'] for e in dados['etapas'] if str(e['id']) == request.args.get('etapa_id')), 'Todas as etapas')
        html = ('<!doctype html><html lang="pt-BR"><meta charset="utf-8"><meta name="referrer" content="no-referrer">'
                '<meta name="viewport" content="width=device-width"><title>Mentorly · Resumo pedagógico</title>'
                '<style>body{font:15px system-ui;color:#182b43;max-width:1000px;margin:40px auto;padding:24px}'
                'table{width:100%;border-collapse:collapse}td,th{text-align:left;padding:12px;border-bottom:1px solid #ddd}'
                'p{white-space:pre-wrap}button{padding:12px 20px}@media print{button{display:none}body{margin:0}}</style>'
                '<button onclick="window.print()">Imprimir / Salvar em PDF</button><h1>Mentorly · Resumo para reunião</h1><h2>'+
                h(dados['turma']['nome'])+'</h2><p>'+h(etapa)+'</p><p>Pontos referem-se à etapa selecionada ou atual. '
                'Ausência de nota indica lançamento pendente; não significa nota zero.</p>'
                '<table><thead><tr><th>Aluno</th><th>Acompanhamento</th><th>Pontos avaliados</th><th>Sem nota</th></tr></thead><tbody>'+
                linhas+'</tbody></table><h2>Intervenções registradas por você</h2><ul>'+(notas or '<li>Nenhum registro.</li>')+'</ul></html>')
        return Response(html, mimetype='text/html', headers={'Cache-Control': 'no-store',
                        'Referrer-Policy': 'no-referrer', 'X-Content-Type-Options': 'nosniff'})
    except RecursoNaoEncontrado as erro:
        return jsonify({'error': str(erro)}), 404
    except ValueError as erro:
        return jsonify({'error': str(erro)}), 400

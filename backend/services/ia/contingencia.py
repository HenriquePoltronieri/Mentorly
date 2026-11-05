"""Respostas deterministicas do motor quando o provedor externo falha."""
import unicodedata
import re

AVISO_LOCAL = (
    "A IA externa está indisponível. Esta análise foi feita localmente pelo "
    "Mentorly com os dados registrados e sugestões pedagógicas predefinidas."
)


def normalizar(texto):
    return ''.join(c for c in unicodedata.normalize('NFD', texto.casefold())
                   if unicodedata.category(c) != 'Mn')


def _nome(texto):
    numeros = {'um': '1', 'uma': '1', 'dois': '2', 'duas': '2',
               'tres': '3', 'quatro': '4', 'cinco': '5', 'seis': '6',
               'sete': '7', 'oito': '8', 'nove': '9', 'dez': '10'}
    return ' '.join(numeros.get(p, p) for p in re.findall(r'\w+', normalizar(texto)))


def alunos_mencionados(mensagem, turmas):
    texto = ' ' + _nome(mensagem) + ' '
    alunos = [(t, a) for t in turmas for a in t['alunos']]
    encontrados = [(t, a) for t, a in alunos if ' ' + _nome(a['nome']) + ' ' in texto]
    if encontrados:
        return encontrados
    return [(t, a) for t, a in alunos
            if ' ' + _nome(a['nome']).split()[0] + ' ' in texto
            and _nome(a['nome']).split()[0] not in ('aluno', 'aluna')]


def pede_outro_aluno(mensagem):
    return bool(re.search(r'\b(outr[oa]s? alun[oa]s?|alun[oa]s? diferente|sem ser ess[ea])\b', normalizar(mensagem)))


def selecao_local(mensagem, turmas, foco=None):
    texto = normalizar(mensagem)
    nomeados = alunos_mencionados(mensagem, turmas)
    medidas = any(p in texto for p in ('medida', 'ajudar', 'melhorar', 'aplicar', 'sugest', 'fazer', 'reforco'))
    if any(p in texto for p in ('dificuldade', 'revisar', 'conteudo')):
        metrica = 'dificuldade'
    elif medidas:
        metrica = 'dificuldade'
    elif any(p in texto for p in ('risco', 'atencao', 'final da etapa')):
        metrica = 'risco'
    elif any(p in texto for p in ('melhorou', 'tendencia', 'evolu')):
        metrica = 'tendencia'
    elif any(p in texto for p in ('ponto', 'pontuacao', 'minimo', 'nota')):
        metrica = 'pontuacao'
    elif any(p in texto for p in ('resumo', 'turma', 'desempenho', 'media')):
        metrica = 'resumo'
    elif nomeados:
        metrica = 'resumo'
    else:
        return {'tipo': 'esclarecer', 'fatos': [], 'medidas': []}
    alunos = [(t, a) for t in turmas for a in t['alunos']]
    alvos = nomeados
    if not alvos and foco and 'turma' not in texto:
        alvos = [(t, a) for t, a in alunos
                 if t['turma']['id'] == foco.get('turma_id') and a['id'] == foco.get('aluno_id')]
    if not alvos and metrica in ('risco', 'pontuacao', 'tendencia'):
        alvos = alunos
        if metrica == 'risco':
            ordem = {'Alto': 0, 'Médio': 1, 'Baixo': 2}
            alvos = sorted(alvos, key=lambda par: ordem.get(par[1]['risco'], 3))
        elif metrica == 'tendencia':
            alvos = [(t, a) for t, a in alvos if a['tendencia'] == 'subindo']
            if not alvos:
                return {'tipo': 'academico', 'fatos': [
                    {'turma_id': t['turma']['id'], 'metrica': 'resumo'} for t in turmas[:3]
                ], 'medidas': []}
    if medidas and not alvos:
        # Sem aluno definido, a sugestao se refere a dificuldade da turma.
        fatos = [{'turma_id': t['turma']['id'], 'metrica': 'dificuldade'} for t in turmas[:3]]
    elif alvos:
        fatos = [{'turma_id': t['turma']['id'], 'aluno_id': a['id'], 'metrica': metrica}
                 for t, a in alvos[:3]]
    else:
        fatos = [{'turma_id': t['turma']['id'], 'metrica': metrica} for t in turmas[:3]]
    return {'tipo': 'academico', 'fatos': fatos,
            'medidas': ['reforco', 'conversa'] if medidas else []}


def insights_locais(calculados):
    atencao = []
    for aluno in calculados:
        fracos = [c['nome'] for c in aluno['criterios']
                  if c['desempenhoPercentual'] is not None and c['desempenhoPercentual'] < 50]
        if fracos:
            atencao.append({
                'titulo': aluno['_nome_completo'],
                'evidencia': 'Aproveitamento abaixo de 50% nas avaliações registradas de: ' + ', '.join(fracos) + '.',
                'sugestao': 'Confira as avaliações com o aluno, identifique os objetivos a retomar e proponha revisão com devolutiva. Esse resultado isolado não determina a situação final.',
            })
    return {
        'resumo': f"Análise local de {len(calculados)} aluno(s), com base nos critérios e notas registrados. Notas ausentes não são tratadas como zero.",
        'pontosPositivos': [],
        'pontosAtencao': atencao[:10],
        'sugestoesGerais': ['Confira os lançamentos pendentes antes de concluir o desempenho da etapa.',
                            'Avalie as sugestões conforme os objetivos da atividade e as regras da escola.'],
    }

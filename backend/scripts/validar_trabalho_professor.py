"""Integração e revisão visual em QA. Os dados temporários são removidos ao terminar.

Requer build Web apontando para :5001 e servidor estático em :18080.
Não consulta IA, não envia e-mail e nunca usa a base pessoal.
"""
import os
import sys
import uuid
import json
import re
from pathlib import Path
from datetime import date, timedelta
os.environ['DB_NAME'] = 'mentorly_interface_regressao'
os.environ['MAIL_SERVER'] = ''
os.environ['SMTP_HOST'] = ''
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from database.connection import transacao, execute, query_one, install_professor_workspace
from config import DB_CONFIG
from auth.jwt_utils import gerar_token
from app import create_app
from werkzeug.security import generate_password_hash

assert DB_CONFIG['database'] == 'mentorly_interface_regressao'


def executar(visual=True):
    install_professor_workspace()
    escola = None
    try:
        with transacao() as c:
            email = 'trabalho-' + uuid.uuid4().hex + '@escola.invalid'
            c.execute('INSERT INTO coordenacao(nome,email,senha_hash) VALUES (%s,%s,%s)', ('Escola de validação', email, generate_password_hash('validacao123')))
            escola = c.lastrowid
            c.execute("INSERT INTO ano_letivo(coordenacao_id,ano,status) VALUES (%s,2026,'atual')", (escola,))
            c.execute('INSERT INTO professor(coordenacao_id,nome,email,senha_hash) VALUES (%s,%s,%s,%s)', (escola, 'Ana Silva', 'ana-'+email, generate_password_hash('validacao123')))
            professor = c.lastrowid
            turmas = []
            for nome in ['8º ano A', '9º ano B']:
                c.execute('INSERT INTO turma(coordenacao_id,nome,disciplina,turno,ano_letivo) VALUES (%s,%s,%s,%s,2026)', (escola, nome, 'Matemática', 'Manhã'))
                turmas.append(c.lastrowid)
                c.execute('INSERT INTO professor_turma(coordenacao_id,professor_id,turma_id) VALUES (%s,%s,%s)', (escola, professor, turmas[-1]))
            hoje = date.today()
            c.execute('INSERT INTO etapa(coordenacao_id,nome,ordem,ano_letivo,data_inicio,data_fim,nota_minima,nota_maxima) VALUES (%s,%s,1,2026,%s,%s,6,10)', (escola, 'Etapa atual', hoje-timedelta(days=45), hoje+timedelta(days=5)))
            etapa = c.lastrowid
            c.execute('INSERT INTO criterio(coordenacao_id,etapa_id,nome,peso,nota_maxima) VALUES (%s,%s,%s,100,10)', (escola, etapa, 'Avaliações'))
            criterio = c.lastrowid
            alunos = []
            for nome in ['Beatriz Lima', 'Caio Santos', 'Laura Oliveira']:
                c.execute('INSERT INTO aluno(turma_id,nome) VALUES (%s,%s)', (turmas[0], nome))
                alunos.append(c.lastrowid)
            atividades = []
            for titulo, dias in [('Frações e proporções', -2), ('Resolução de problemas', 3)]:
                c.execute('INSERT INTO atividade(coordenacao_id,turma_id,professor_id,etapa_id,criterio_id,titulo,nota_maxima,data_entrega) VALUES (%s,%s,%s,%s,%s,%s,10,%s)', (escola, turmas[0], professor, etapa, criterio, titulo, hoje+timedelta(days=dias)))
                atividades.append(c.lastrowid)
            c.execute('INSERT INTO nota(atividade_id,aluno_id,valor) VALUES (%s,%s,8)', (atividades[0], alunos[0]))
        token = gerar_token(professor, 'professor', escola)
        headers = {'Authorization': 'Bearer '+token}
        client = create_app().test_client()
        def get(path):
            r = client.get('/api'+path, headers=headers)
            assert r.status_code == 200, (path, r.status_code, r.json)
            return r.json
        trabalho = get('/professor/trabalho')
        assert [p['sem_nota'] for p in trabalho['pendencias']] == [2, 3]
        r = client.post(f'/api/atividades/{atividades[0]}/notas', headers=headers, json={'notas': [{'aluno_id': alunos[1], 'valor': None, 'situacao': 'Ausente'}]})
        assert r.status_code == 201, r.json
        assert query_one('SELECT id FROM nota WHERE atividade_id=%s AND aluno_id=%s', (atividades[0], alunos[1])) is None
        assert any(n['situacao'] == 'Ausente' and n['valor'] is None for n in get(f'/atividades/{atividades[0]}/notas')['notas'])
        grade = get(f'/professor/turmas/{turmas[0]}/grade')
        assert len(grade['atividades_cadastro']) == 2
        assert any(a['status'] == 'Ausente' and a['nota'] is None for al in grade['alunos'] for a in al['atividades'])
        r = client.post(f'/api/professor/turmas/{turmas[0]}/alunos/{alunos[1]}/acompanhamentos', headers=headers, json={'descricao': 'Revisar a estratégia de resolução e combinar uma nova atividade.', 'retorno_em': str(hoje+timedelta(days=7))})
        assert r.status_code == 200, r.json
        registro = r.json['id']
        r = client.put(f'/api/professor/acompanhamentos/{registro}', headers=headers, json={'concluido': True})
        assert r.status_code == 200, r.json
        r = client.put(f'/api/professor/acompanhamentos/{registro}', headers=headers, json={'concluido': False})
        assert r.status_code == 200
        r = client.get(f'/api/professor/turmas/{turmas[0]}/resumo-reuniao', headers=headers)
        assert r.status_code == 200 and 'Beatriz Lima' in r.text and 'Revisar a estratégia' in r.text
        # A mesma cópia revisada pelo formulário usa POST /activities, sem notas.
        r = client.post('/api/activities', headers=headers, json={'title': 'Frações e proporções', 'class_id': turmas[1], 'etapa_id': etapa, 'criterio_id': criterio, 'nota_maxima': 10, 'due_date': str(hoje+timedelta(days=4))})
        assert r.status_code == 201, r.json
        assert query_one('SELECT COUNT(*) AS n FROM nota WHERE atividade_id=%s', (r.json['id'],))['n'] == 0
        # Etapa fechada bloqueia escrita tanto por grade quanto por lançamento.
        execute('UPDATE etapa SET fechada=1 WHERE id=%s', (etapa,))
        r = client.post(f'/api/atividades/{atividades[0]}/notas', headers=headers, json={'notas': [{'aluno_id': alunos[2], 'situacao': 'Ausente'}]})
        assert r.status_code == 400, r.json
        execute('UPDATE etapa SET fechada=0 WHERE id=%s', (etapa,))
        print('OK: SQL de pendências; ausência sem zero; grade; intervenções; conclusão; relatório; cópia sem notas; etapa fechada.')
        if visual:
            revisar_visual(token, {'id': professor, 'nome': 'Ana Silva', 'tipo': 'professor', 'coordenacao_id': escola}, turmas[0])
    finally:
        if escola is not None:
            # Alvos fixos e limitados à escola criada nesta execução.
            for tabela in ('atividade', 'professor_turma', 'turma', 'criterio', 'etapa', 'professor', 'ano_letivo', 'coordenacao'):
                coluna = 'id' if tabela == 'coordenacao' else 'coordenacao_id'
                execute('DELETE FROM '+tabela+' WHERE '+coluna+'=%s', (escola,))


def revisar_visual(token, usuario, turma_id):
    from playwright.sync_api import sync_playwright
    origem = 'http://127.0.0.1:18080'
    with sync_playwright() as p:
        browser = p.chromium.launch(executable_path=r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe', headless=True)
        page = browser.new_page(viewport={'width': 1280, 'height': 1000})
        erros = []
        page.on('pageerror', lambda e: erros.append(str(e)))
        page.goto(origem)
        page.evaluate('(s) => {localStorage.setItem("flutter.mentorly.token",JSON.stringify(s.token)); localStorage.setItem("flutter.mentorly.usuario",JSON.stringify(JSON.stringify(s.usuario)));}', {'token': token, 'usuario': usuario})
        # SharedPreferences Web usa valores JSON no prefixo flutter.
        page.goto(origem+'/#/professor/dashboard', wait_until='networkidle')
        page.reload(wait_until='networkidle')
        page.wait_for_selector('flt-semantics-placeholder', state='attached')
        page.locator('flt-semantics-placeholder').evaluate('(e)=>e.click()')
        page.get_by_text('Olá, Ana', exact=True).wait_for()
        for largura in (1280, 768, 320):
            page.set_viewport_size({'width': largura, 'height': 1000})
            page.wait_for_timeout(400)
            page.screenshot(path=f'docs/profissional-inicio-{largura}.png')
        # Acesso direto pela navegação visível; sem depender da posição dos cards.
        page.get_by_role('button', name='Abrir minhas turmas', exact=True).click()
        page.wait_for_timeout(500)
        page.screenshot(path='docs/profissional-turmas-320.png')
        page.get_by_role('button', name=re.compile('8º ano A')).or_(page.get_by_text('8º ano A', exact=False)).first.click()
        page.get_by_role('button', name='Grade de notas', exact=True).click()
        page.get_by_text('Notas da turma', exact=True).wait_for()
        for largura in (320, 768, 1280):
            page.set_viewport_size({'width': largura, 'height': 1000})
            page.wait_for_timeout(400)
            page.screenshot(path=f'docs/profissional-grade-{largura}.png')
        assert not erros, erros
        browser.close()
        print('OK: revisão no navegador e capturas em 320/768/1280 px.')


if __name__ == '__main__':
    executar(visual='--sem-visual' not in sys.argv)

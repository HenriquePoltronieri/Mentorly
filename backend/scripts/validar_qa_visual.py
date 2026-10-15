"""Revisao real em Edge, apenas no servidor e banco exclusivos de QA."""
import os
import sys
import json
import re
from pathlib import Path
from playwright.sync_api import sync_playwright
os.environ.update(DB_NAME='mentorly_qa_completa', MAIL_SERVER='', SMTP_HOST='')
RAIZ = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(RAIZ/'backend'))
from database.connection import query_one, execute
from auth.jwt_utils import gerar_token

ORIGEM = 'http://127.0.0.1:5002'
admin = query_one('SELECT email FROM administrador WHERE nome=%s ORDER BY id DESC LIMIT 1', ('Responsável QA',))
escola = query_one('SELECT c.* FROM coordenacao c JOIN professor p ON p.coordenacao_id=c.id '
                   'WHERE p.nome=%s ORDER BY c.id DESC LIMIT 1', ('Professor QA',))
execute('UPDATE coordenacao SET nome=%s WHERE id=%s', ('Escola de Demonstração', escola['id']))
execute("UPDATE acesso_escola SET situacao='teste',valido_ate='2099-01-01' WHERE coordenacao_id=%s", (escola['id'],))
capturas = []


def capturar(page, nome):
    page.screenshot(path=str(RAIZ/'docs'/nome), full_page=True)
    assert page.evaluate('document.documentElement.scrollWidth <= innerWidth'), nome
    capturas.append(nome)


def semantica(page):
    page.wait_for_selector('flt-semantics-placeholder', state='attached')
    page.locator('flt-semantics-placeholder').evaluate('(e)=>e.click()')


def salvar_acesso(page):
    with page.expect_response(lambda r: r.request.method == 'PUT' and '/api/admin/escolas/' in r.url) as resposta:
        page.get_by_role('button', name='Salvar acesso', exact=True).click()
    assert resposta.value.status == 200, resposta.value.text()
    page.get_by_role('textbox', name='Motivo da alteração', exact=False).wait_for(state='hidden')


with sync_playwright() as p:
    browser = p.chromium.launch(executable_path=r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe', headless=True)
    contexto = browser.new_context(viewport={'width': 1280, 'height': 900})
    page = contexto.new_page()
    erros = []
    page.on('pageerror', lambda e: erros.append(str(e)))
    page.goto(ORIGEM+'/admin/login')
    semantica(page)
    page.get_by_role('textbox', name='E-mail', exact=True).click()
    page.keyboard.type(admin['email'])
    page.get_by_role('textbox', name='Senha', exact=True).click()
    page.keyboard.type('senha-segura-qa-123')
    page.get_by_role('button', name='Entrar', exact=True).click()
    page.get_by_text('Acesso das escolas', exact=True).wait_for()
    page.get_by_role('textbox', name='Buscar escola ou e-mail', exact=False).click()
    page.keyboard.type(escola['email'])
    page.get_by_role('button', name='Buscar', exact=True).click()
    capturar(page, 'qa-admin-desktop.png')
    page.set_viewport_size({'width': 320, 'height': 850})
    capturar(page, 'qa-admin-mobile.png')
    page.get_by_role('button', name='Gerenciar acesso', exact=True).click()
    page.get_by_role('button', name=re.compile('Situação')).click()
    page.get_by_role('menuitem', name='Suspensa', exact=True).click()
    page.get_by_role('textbox', name='Motivo da alteração', exact=False).click()
    page.keyboard.type('Suspensão fictícia para QA de acesso')
    salvar_acesso(page)
    app = contexto.new_page()
    app.set_viewport_size({'width': 320, 'height': 850})
    app.on('pageerror', lambda e: erros.append(str(e)))
    app.goto(ORIGEM)
    # Faz login pela tela real, sem injetar uma sessao no navegador.
    semantica(app)
    app.get_by_role('button', name='Coordenação Professores, turmas e ano letivo').click()
    app.get_by_role('textbox', name='Email', exact=True).click()
    app.keyboard.type(escola['email'])
    app.get_by_role('textbox', name='Senha', exact=True).click()
    app.keyboard.type('senha-qa-123')
    app.get_by_role('button', name='Entrar', exact=True).click()
    app.get_by_text('Plano e liberação', exact=True).wait_for()
    capturar(app, 'qa-acesso-bloqueado-mobile.png')
    app.set_viewport_size({'width': 1280, 'height': 900})
    capturar(app, 'qa-acesso-bloqueado-desktop.png')
    page.bring_to_front()
    page.get_by_role('button', name='Gerenciar acesso', exact=True).click()
    page.get_by_role('button', name=re.compile('Situação')).click()
    page.get_by_role('menuitem', name='Cortesia', exact=True).click()
    page.get_by_role('button', name='Remover prazo', exact=True).click()
    page.get_by_role('textbox', name='Motivo da alteração', exact=False).click()
    page.keyboard.type('Cortesia fictícia para demonstração de QA')
    salvar_acesso(page)
    app.bring_to_front()
    app.get_by_role('button', name='Verificar liberação', exact=True).click()
    app.get_by_role('button', name='Continuar para o Mentorly', exact=True).wait_for()
    capturar(app, 'qa-acesso-liberado-desktop.png')
    app.get_by_role('button', name='Continuar para o Mentorly', exact=True).click()
    app.get_by_text('Organização do ano', exact=True).wait_for()
    # Recarregar conserva a conta e usa a API relativa no mesmo servidor.
    app.reload(wait_until='networkidle')
    semantica(app)
    app.get_by_text('Organização do ano', exact=True).wait_for()
    assert not erros, erros
    browser.close()
print('OK: admin desktop/mobile; login real; suspensão; cortesia; liberação; recarga; sem erros JavaScript.')
print(json.dumps(capturas, ensure_ascii=False))

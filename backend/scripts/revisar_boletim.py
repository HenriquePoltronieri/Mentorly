"""Revisão visual de um professor fictício já ativado na base de QA."""
import os
import sys
import re
from playwright.sync_api import sync_playwright

os.environ['DB_NAME']='mentorly_interface_regressao'
sys.path.insert(0,os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.connection import query_one

professor=query_one('SELECT p.email,t.nome FROM professor p JOIN professor_turma pt ON pt.professor_id=p.id JOIN turma t ON t.id=pt.turma_id WHERE p.habilitado=1 ORDER BY p.id DESC LIMIT 1')
with sync_playwright() as p:
    browser=p.chromium.launch(executable_path=r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',headless=True)
    page=browser.new_page(viewport={'width':320,'height':900})
    page.goto('http://127.0.0.1:18080',wait_until='networkidle')
    page.wait_for_selector('flt-semantics-placeholder',state='attached')
    page.locator('flt-semantics-placeholder').evaluate('(e)=>e.click()')
    page.get_by_text('Professor Atividades, notas e desempenho',exact=False).click()
    page.get_by_role('textbox',name='Email',exact=True).click()
    page.keyboard.type(professor['email'])
    page.get_by_role('textbox',name='Senha',exact=True).click()
    page.keyboard.type('validacao123')
    with page.expect_response(lambda r:'/auth/login-professor' in r.url and r.request.method=='POST') as login:
        page.get_by_role('button',name='Entrar',exact=True).click()
    assert login.value.status==200
    page.get_by_role('button',name='Navegar',exact=True).wait_for()
    page.wait_for_timeout(500)
    page.screenshot(path='docs/interface-professor-turmas-mobile.png')
    turma=page.get_by_role('button',name=re.compile(re.escape(professor['nome']))).or_(page.get_by_label(re.compile(re.escape(professor['nome'])))).or_(page.get_by_text(professor['nome'],exact=False)).first
    turma.click()
    page.get_by_role('button',name='Boletim e fechamento de etapas',exact=True).click()
    page.get_by_text('Fechamento de etapas',exact=False).wait_for()
    page.screenshot(path='docs/interface-boletim-mobile.png')
    print('OK: login, turma vinculada e boletim móvel.')
    browser.close()

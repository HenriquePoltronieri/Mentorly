"""Mede Flutter Web release no Edge; apenas lê a escola isolada de QA."""
import json
import os
import re
import sys
import time
from pathlib import Path
from playwright.sync_api import sync_playwright

os.environ['DB_NAME']='mentorly_interface_regressao'
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from database.connection import query_one

professor=query_one('SELECT email FROM professor WHERE senha_hash IS NOT NULL AND email LIKE %s ORDER BY id DESC LIMIT 1',('qa-navegador-%',))
resultados={}
with sync_playwright() as p:
    browser=p.chromium.launch(executable_path=r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',headless=True)
    page=browser.new_page(viewport={'width':1280,'height':900})
    inicio=time.perf_counter()
    page.goto('http://127.0.0.1:18080',wait_until='load')
    page.wait_for_selector('flt-semantics-placeholder',state='attached')
    page.locator('flt-semantics-placeholder').evaluate('(e)=>e.click()')
    page.get_by_text(re.compile('Como deseja entrar|Qual perfil se encaixa')).first.wait_for()
    resultados['acesso_frio_ms']=round((time.perf_counter()-inicio)*1000,2)
    resultados['recursos_iniciais']=page.evaluate('''() => performance.getEntriesByType('resource')
      .filter(r => !r.name.includes('/api/')).sort((a,b)=>b.duration-a.duration).slice(0,6)
      .map(r=>({arquivo:new URL(r.name).pathname,duracao_ms:Math.round(r.duration),fim_ms:Math.round(r.responseEnd)}))''')
    resultados['fontes_externas']=page.evaluate(r'''() => performance.getEntriesByType('resource')
      .filter(r => /\.(woff2?|ttf|otf)$/.test(new URL(r.name).pathname) && new URL(r.name).origin!==location.origin)
      .map(r => new URL(r.name).origin + new URL(r.name).pathname)''')
    page.get_by_role('button',name=re.compile('^Coordenação')).first.click()
    for rotulo,valor in [('Email','validacao@escola.invalid'),('Senha','validacao123')]:
        campo=page.get_by_role('textbox',name=rotulo,exact=True)
        campo.click()
        page.wait_for_timeout(100)
        page.keyboard.type(valor,delay=20)
        assert page.evaluate('(valor) => document.activeElement?.value === valor',valor)
    inicio=time.perf_counter()
    with page.expect_response(lambda r:r.request.method=='POST' and '/auth/login-coordenacao' in r.url) as login:
        page.get_by_role('button',name='Entrar',exact=True).click()
    assert login.value.status==200
    resultados['backend_login_coordenacao']=login.value.headers.get('server-timing')
    page.get_by_text('Escola de validação',exact=True).wait_for()
    page.get_by_role('button',name=re.compile('Revisar configuração|Configurar ano letivo')).first.wait_for()
    resultados['login_painel_coordenacao_ms']=round((time.perf_counter()-inicio)*1000,2)
    if not page.get_by_role('button',name='Sair',exact=True).count():
        page.get_by_role('button',name=re.compile('Conta|validacao@escola.invalid')).first.click()
        page.wait_for_timeout(250)
        page.get_by_role('menuitem',name='Sair',exact=True).or_(page.get_by_role('button',name='Sair',exact=True)).or_(page.get_by_label('Sair',exact=True)).or_(page.get_by_text('Sair',exact=True)).first.click()
    else:
        page.get_by_role('button',name='Sair',exact=True).click()
    page.get_by_role('button',name=re.compile('^Professor')).first.click()
    for rotulo,valor in [('Email',professor['email']),('Senha','validacao123')]:
        campo=page.get_by_role('textbox',name=rotulo,exact=True)
        campo.click()
        page.wait_for_timeout(100)
        page.keyboard.type(valor,delay=20)
        assert page.evaluate('(valor) => document.activeElement?.value === valor',valor)
    inicio=time.perf_counter()
    with page.expect_response(lambda r:r.request.method=='POST' and '/auth/login-professor' in r.url) as login:
        page.get_by_role('button',name='Entrar',exact=True).click()
    assert login.value.status==200
    resultados['backend_login_professor']=login.value.headers.get('server-timing')
    page.get_by_role('button',name='Navegar',exact=True).wait_for() if page.viewport_size['width']<720 else page.get_by_role('button',name=re.compile('^(Painel|Dashboard)$')).first.wait_for()
    page.get_by_role('button',name=re.compile('^(Painel|Dashboard)$')).first.click()
    risco=re.compile('Alunos abaixo do mínimo|Alunos em risco')
    page.get_by_label(risco).or_(page.get_by_text(risco)).first.wait_for()
    resultados['login_painel_professor_ms']=round((time.perf_counter()-inicio)*1000,2)
    intervalos=page.evaluate('''() => new Promise(resolve => {
      const amostras=[]; let anterior; function medir(t) {
        if(anterior!==undefined) amostras.push(t-anterior); anterior=t;
        if(amostras.length<120) requestAnimationFrame(medir); else resolve(amostras);
      } requestAnimationFrame(medir);
    })''')
    resultados['frame_mediano_ms']=round(sorted(intervalos)[len(intervalos)//2],2)
    resultados['frames_acima_33ms']=sum(t>33 for t in intervalos)
    browser.close()
Path(sys.argv[1]).write_text(json.dumps(resultados,indent=2),encoding='utf-8')
print(json.dumps(resultados))

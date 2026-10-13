"""Revisão do redesign release em 320/768/1280 px, somente na escola de QA."""
import re
import time
from pathlib import Path
from playwright.sync_api import sync_playwright

ORIGEM='http://127.0.0.1:18080'
API='http://127.0.0.1:5001/api'

def clicar(page,texto):
    page.wait_for_timeout(350)
    menu=page.get_by_role('menuitem',name=texto,exact=True).first
    if menu.count():
        menu.click();return
    alvo=page.get_by_role('button',name=texto,exact=True).first
    if not alvo.count(): alvo=page.get_by_label(texto,exact=True).first
    if not alvo.count(): alvo=page.get_by_text(texto,exact=True).first
    alvo.scroll_into_view_if_needed()
    alvo.click()

def imagem(page,nome):
    page.screenshot(path=str(Path('docs')/('vidro-'+nome+'.png')))

def preencher(page,rotulo,valor):
    page.bring_to_front()
    campo=page.get_by_role('textbox',name=rotulo,exact=True)
    campo.click()
    page.wait_for_timeout(100)
    page.keyboard.press('Control+A')
    page.keyboard.type(valor,delay=20)
    page.wait_for_timeout(100)
    # Durante a edição Flutter usa um input próprio; o nó semântico pode ficar vazio.
    assert page.evaluate('(valor) => document.activeElement?.value === valor',valor)

def iniciar(page,url=ORIGEM):
    page.goto(url,wait_until='networkidle')
    page.wait_for_selector('flt-semantics-placeholder',state='attached')
    page.locator('flt-semantics-placeholder').evaluate('(e)=>e.click()')

with sync_playwright() as p:
    browser=p.chromium.launch(executable_path=r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',headless=True)
    page=browser.new_page(viewport={'width':1280,'height':1000})
    erros=[]
    page.on('pageerror',lambda e:erros.append(str(e)))
    iniciar(page)
    imagem(page,'perfil-desktop')
    escolha=page.get_by_role('button',name=re.compile('^Coordenação')).first
    escolha.focus()
    page.keyboard.press('Enter')
    page.get_by_role('textbox',name='Email',exact=True).wait_for()
    assert page.get_by_text('Sign in with Google',exact=True).count()==0
    assert page.get_by_text('Esqueceu a senha?',exact=True).count()==0
    imagem(page,'login-desktop')
    clicar(page,'Criar conta')
    page.get_by_role('textbox',name='Nome',exact=True).wait_for()
    imagem(page,'cadastro-desktop')
    clicar(page,'Já tenho conta')
    for largura in (768,320):
        page.set_viewport_size({'width':largura,'height':900})
        imagem(page,'login-'+str(largura))
        clicar(page,'Criar conta')
        page.get_by_role('textbox',name='Nome',exact=True).wait_for()
        imagem(page,'cadastro-'+str(largura))
        clicar(page,'Criar conta')
        page.wait_for_timeout(350)
        page.get_by_role('textbox',name=re.compile('Email')).first.wait_for()
        imagem(page,'cadastro-erros-'+str(largura))
        assert page.get_by_role('textbox',name=re.compile('Email')).first.get_attribute('aria-invalid') == 'true'
        clicar(page,'Já tenho conta')
        page.wait_for_timeout(350)
    page.set_viewport_size({'width':1280,'height':1000})
    page.wait_for_timeout(350)
    for rotulo,valor in [('Email','validacao@escola.invalid'),('Senha','validacao123')]:
        preencher(page,rotulo,valor)
    with page.expect_response(lambda r:r.request.method=='POST' and '/auth/login-coordenacao' in r.url) as login:
        clicar(page,'Entrar')
    assert login.value.status==200
    token=login.value.json()['token']
    page.get_by_text('Escola de validação',exact=True).wait_for()
    for largura in (1280,768,320):
        page.set_viewport_size({'width':largura,'height':1000})
        imagem(page,'coordenacao-'+str(largura))
    # Leitura das telas administrativas pelo menu compacto.
    for aba,nome in [('Professores','professores'),('Turmas','turmas'),('Ano letivo','anos')]:
        clicar(page,'Navegar');clicar(page,aba)
        page.wait_for_timeout(300)
        imagem(page,nome+'-mobile')
    clicar(page,'Navegar');clicar(page,'Início')
    clicar(page,'Revisar configuração')
    page.get_by_text('Quantas etapas',exact=False).wait_for()
    imagem(page,'etapas-mobile')
    clicar(page,'Salvar e continuar')
    page.get_by_role('textbox',name='Pontos da etapa',exact=True).wait_for()
    imagem(page,'notas-mobile')
    for i in range(1,4):
        clicar(page,'Salvar e continuar' if i==3 else 'Salvar e ir para a etapa '+str(i+1))
    page.get_by_role('textbox',name='Peso').first.wait_for()
    imagem(page,'criterios-mobile')
    for peso in page.get_by_role('textbox',name='Peso').all():
        caixa=peso.bounding_box();assert caixa['x']>=0 and caixa['x']+caixa['width']<=320
    email='visual-'+str(time.time_ns())+'@escola.invalid'
    cadastro=page.request.post(API+'/coordenacao/professores',headers={'Authorization':'Bearer '+token},data={'nome':'Professor Teste Visual','email':email,'disciplina':'Matemática'})
    assert cadastro.status==201
    convite=cadastro.json()
    nova=browser.new_page(viewport={'width':320,'height':900})
    with nova.expect_response(lambda r:'/auth/consultar-convite' in r.url and r.request.method=='POST') as consulta:
        iniciar(nova,convite['conviteLink'])
    assert consulta.value.status==200 and consulta.value.json()=={'email':email}
    assert nova.get_by_role('textbox',name='Email',exact=True).count()==0
    nova.get_by_role('textbox',name='Nova senha',exact=True).wait_for()
    imagem(nova,'convite-mobile')
    for rotulo in ('Nova senha','Confirmar senha'):
        preencher(nova,rotulo,'validacao123')
    with nova.expect_response(lambda r:'/auth/criar-senha-professor' in r.url and r.request.method=='POST') as ativacao:
        clicar(nova,'Criar senha e entrar')
    assert ativacao.value.status==200
    clicar(nova,'Navegar');clicar(nova,'Dashboard')
    nova.get_by_label(re.compile('Alunos em risco')).or_(nova.get_by_text('Alunos em risco',exact=False)).first.wait_for()
    for largura in (320,768,1280):
        nova.set_viewport_size({'width':largura,'height':1000})
        imagem(nova,'professor-'+str(largura))
    # Token consumido volta como erro claro, sem e-mail editável ou envio de senha.
    invalido=browser.new_page(viewport={'width':320,'height':900})
    iniciar(invalido,convite['conviteLink'])
    invalido.get_by_label(re.compile('Se o convite expirou ou já foi usado')).or_(invalido.get_by_text('Se o convite expirou ou já foi usado',exact=False)).first.wait_for()
    imagem(invalido,'convite-usado-mobile')
    assert not erros,erros
    print('OK: teclado; login/cadastro nos três tamanhos; navegação administrativa; assistente; convite somente leitura; ativação; dashboard; token usado.')
    browser.close()

"""Fluxos reais do Flutter Web no Edge, usando somente a escola de QA."""
import re
import time
from pathlib import Path
from playwright.sync_api import sync_playwright

ORIGEM = 'http://127.0.0.1:18080'
API = 'http://127.0.0.1:5001/api'

def ativar(page):
    page.goto(ORIGEM, wait_until='networkidle')
    page.wait_for_selector('flt-semantics-placeholder', state='attached')
    page.locator('flt-semantics-placeholder').evaluate('(e) => e.click()')
    page.get_by_text('Como deseja entrar?', exact=True).wait_for()

def clicar(page, texto):
    alvo = page.get_by_role('button', name=texto, exact=True).first
    if not alvo.count():
        alvo = page.get_by_label(texto, exact=True).first
    if not alvo.count():
        alvo = page.get_by_text(texto, exact=True).first
    if not alvo.count():
        alvo = page.get_by_text(re.compile('^' + re.escape(texto))).first
    alvo.scroll_into_view_if_needed()
    alvo.click()

def capturar(page, nome):
    page.screenshot(path=str(Path('docs') / (nome + '.png')))

def ver_linha(page, texto):
    padrao=re.compile(re.escape(texto))
    linha=page.get_by_role('button',name=padrao).or_(page.get_by_label(padrao)).or_(page.get_by_text(texto,exact=False)).first
    for _ in range(20):
        if linha.count():
            linha.scroll_into_view_if_needed()
            return linha
        tamanho=page.viewport_size
        page.mouse.move(tamanho['width']/2,tamanho['height']/2)
        page.mouse.wheel(0,500)
        page.wait_for_timeout(150)
    linha.wait_for()
    return linha

with sync_playwright() as p:
    browser = p.chromium.launch(executable_path=r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe', headless=True)
    page = browser.new_page(viewport={'width':1280,'height':900})
    page.on('pageerror', lambda e: print('Erro de página:', str(e)))
    ativar(page)
    capturar(page, 'interface-acesso')
    page.get_by_text('Coordenação', exact=False).first.click()
    page.get_by_role('textbox', name='Email', exact=True).click()
    page.keyboard.type('validacao@escola.invalid')
    page.get_by_role('textbox', name='Senha', exact=True).click()
    page.keyboard.type('validacao123')
    capturar(page, 'interface-login-desktop')
    with page.expect_response(lambda r:r.request.method=='POST' and '/auth/login-coordenacao' in r.url) as login_coordenacao:
        clicar(page, 'Entrar')
    assert login_coordenacao.value.status==200, 'Login de QA recusado; confira o limite de tentativas antes de repetir.'
    page.get_by_text('Escola de validação', exact=True).wait_for()
    capturar(page, 'interface-coordenacao-desktop')
    assert not page.get_by_text('Desempenho Acadêmico', exact=True).count()
    for largura in (768,320):
        page.set_viewport_size({'width':largura,'height':900})
        capturar(page, 'interface-coordenacao-'+str(largura))
    page.set_viewport_size({'width':320,'height':900})
    alvo = page.get_by_text(re.compile('^(Configurar ano letivo|Revisar configuração)$')).first
    alvo.click()
    page.get_by_text('Quantas etapas',exact=False).wait_for()
    clicar(page, '3 Etapas')
    clicar(page, 'Salvar e continuar')
    for i in range(1,4):
        page.get_by_role('textbox', name='Mínimo para aprovação').fill('6')
        page.get_by_role('textbox', name='Pontos da etapa').fill('10')
        clicar(page, 'Salvar e continuar' if i==3 else 'Salvar e ir para a etapa '+str(i+1))
    page.get_by_text('Como as notas dos seus alunos são calculadas?', exact=True).wait_for()
    # A primeira execução prepara o ano; as seguintes editam os dados salvos.
    if page.get_by_role('textbox', name='Peso').count()==0:
        clicar(page,'Provas'); clicar(page,'Trabalhos')
    pesos=page.get_by_role('textbox', name='Peso')
    pesos.nth(0).fill('60'); pesos.nth(1).fill('40')
    pesos.nth(0).scroll_into_view_if_needed()
    capturar(page,'interface-criterios-mobile')
    for peso in (pesos.nth(0),pesos.nth(1)):
        caixa=peso.bounding_box()
        assert caixa['x']>=0 and caixa['x']+caixa['width']<=320
    clicar(page,'Concluir configuração')
    page.get_by_text('Escola de validação', exact=True).wait_for()
    page.get_by_role('button',name=re.compile('^Turmas e alunos')).first.click()
    clicar(page,'Adicionar turma')
    nome_turma='Turma QA '+str(time.time_ns())
    page.get_by_text('Adicionar Turma',exact=True).wait_for()
    page.get_by_role('textbox').first.click()
    page.keyboard.type(nome_turma)
    capturar(page,'interface-turma-formulario-mobile')
    clicar(page,'Adicionar')
    linha_turma=ver_linha(page,nome_turma)
    capturar(page,'interface-turmas-mobile')
    linha_turma.click()
    clicar(page,'Adicionar alunos')
    clicar(page,'Adicionar um aluno manualmente')
    page.get_by_role('textbox').first.click()
    page.keyboard.type('Aluno de validação')
    clicar(page,'Adicionar')
    page.get_by_text('Aluno adicionado com sucesso',exact=True).wait_for()
    with page.expect_response(lambda r: r.request.method=='GET' and '/alunos' in r.url) as alunos:
        page.keyboard.press('Escape')
    assert any(a['nome']=='Aluno de validação' for a in alunos.value.json())
    page.wait_for_timeout(300)
    capturar(page,'interface-alunos-mobile')
    # Voltar ao painel antes de revisar os professores.
    page.get_by_role('button',name='Voltar',exact=True).click()
    page.get_by_role('button',name='Voltar',exact=True).click()
    page.set_viewport_size({'width':1280,'height':900})
    page.get_by_role('button',name=re.compile('^Professores')).first.click()
    clicar(page,'Cadastrar professor')
    nome_professor='Professor de validação '+str(time.time_ns())
    page.get_by_role('textbox',name='Nome completo',exact=True).fill(nome_professor)
    email='qa-navegador-'+str(time.time_ns())+'@escola.invalid'
    page.get_by_role('textbox',name='Email',exact=True).fill(email)
    page.get_by_role('textbox',name='Disciplina',exact=True).fill('Matemática')
    with page.expect_response(lambda r: r.request.method=='POST' and r.url==API+'/coordenacao/professores') as emissao:
        clicar(page,'Cadastrar')
    convite=emissao.value.json()
    assert convite['conviteEnviado'] is False
    page.get_by_text('O e-mail não foi enviado.',exact=False).wait_for()
    clicar(page,'Concluir')
    page.get_by_role('button',name='Cadastrar professor',exact=True).wait_for()
    page.get_by_label(re.compile('Professor de validação')).first.wait_for()
    assert page.get_by_text('Reenviar convite',exact=True).count()>0
    capturar(page, 'interface-professores-desktop')
    page.get_by_role('button',name='Voltar',exact=True).click()
    page.get_by_role('button',name=re.compile('^Vincular professores')).first.click()
    page.get_by_role('button',name='Gerenciar',exact=True).first.wait_for()
    linha_professor=page.get_by_label(re.compile(re.escape(nome_professor)))
    for _ in range(6):
        if linha_professor.count():
            break
        page.mouse.move(640,500)
        page.mouse.wheel(0,600)
        page.wait_for_timeout(200)
    linha_professor.first.scroll_into_view_if_needed()
    page.get_by_role('button',name='Gerenciar',exact=True).last.click()
    page.get_by_text('Turmas de '+nome_professor,exact=True).wait_for()
    page.get_by_label(re.compile(re.escape(nome_turma))).click()
    with page.expect_response(lambda r: r.request.method=='POST' and r.url==API+'/coordenacao/professores/'+str(convite['id'])+'/turmas') as vinculo:
        clicar(page,'Salvar')
    assert vinculo.value.status in (200,201), vinculo.value.json()
    page.set_viewport_size({'width':320,'height':900})
    capturar(page,'interface-vinculos-mobile')
    # Apenas este cadastro fictício é ativado; mantém o convite recebido por Luca.
    nova=browser.new_page(viewport={'width':320,'height':800})
    nova.goto(convite['conviteLink'],wait_until='networkidle')
    nova.wait_for_selector('flt-semantics-placeholder',state='attached')
    nova.locator('flt-semantics-placeholder').evaluate('(e) => e.click()')
    nova.get_by_role('textbox',name='Nova senha',exact=True).wait_for()
    capturar(nova,'interface-senha-mobile')
    assert not nova.get_by_role('textbox',name='Email',exact=True).count()
    nova.get_by_role('textbox',name='Nova senha',exact=True).click()
    nova.keyboard.type('validacao123')
    nova.get_by_role('textbox',name='Confirmar senha',exact=True).click()
    nova.keyboard.type('validacao123')
    with nova.expect_response(lambda r: r.request.method=='POST' and r.url==API+'/auth/criar-senha-professor') as ativacao:
        clicar(nova,'Definir senha e entrar')
    print('Ativação:',ativacao.value.status,flush=True)
    assert ativacao.value.status==200
    nova.get_by_role('button',name='Navegar',exact=True).wait_for()
    nova.wait_for_timeout(400)
    capturar(nova,'interface-professor-turmas-mobile')
    turma_professor=ver_linha(nova,nome_turma)
    capturar(nova,'interface-professor-turmas-mobile')
    turma_professor.click()
    clicar(nova,'Boletim e fechamento de etapas')
    nova.get_by_text('Fechamento de etapas',exact=False).wait_for()
    capturar(nova,'interface-boletim-mobile')
    clicar(nova,'Sair')
    nova.get_by_text('Professor Atividades, notas e desempenho',exact=False).click()
    nova.get_by_role('textbox',name='Email',exact=True).click()
    nova.keyboard.type(email)
    nova.get_by_role('textbox',name='Senha',exact=True).click()
    nova.keyboard.type('validacao123')
    with nova.expect_response(lambda r: r.request.method=='POST' and r.url==API+'/auth/login-professor') as login:
        clicar(nova,'Entrar')
    print('Login:',login.value.status,flush=True)
    assert login.value.status==200
    nova.get_by_role('button',name='Navegar',exact=True).wait_for()
    clicar(nova,'Navegar'); clicar(nova,'Painel')
    nova.get_by_text('Olá, '+nome_professor+'.',exact=True).wait_for()
    capturar(nova,'interface-professor-mobile')
    # Acessar a área de professor com a sessão de coordenação é negado no frontend.
    page.goto(ORIGEM+'/#/professor/dashboard',wait_until='networkidle')
    page.reload(wait_until='networkidle')
    page.wait_for_selector('flt-semantics-placeholder',state='attached')
    page.locator('flt-semantics-placeholder').evaluate('(e) => e.click()')
    page.get_by_text('Acesso restrito',exact=True).wait_for()
    print('OK: configuração completa; falha SMTP com lista recuperada; token da URL; senha; login; papéis; telas 320/768/1280.')
    browser.close()

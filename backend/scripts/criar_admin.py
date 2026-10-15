"""Conta administrativa apenas pelo terminal. Nenhuma senha padrao ou publica."""
import sys
from pathlib import Path
from getpass import getpass
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from database.connection import query_one, execute
from werkzeug.security import generate_password_hash


def criar_admin():
    print('\nCriar ou redefinir administrador do Mentorly')
    nome = input('Seu nome: ').strip()
    email = input('Seu e-mail: ').strip().lower()
    if not nome or len(nome) > 150 or '@' not in email or len(email) > 150:
        raise SystemExit('Informe nome e e-mail válidos.')
    senha = getpass('Crie sua senha: ')
    confirmar = getpass('Repita a senha: ')
    if not senha:
        raise SystemExit('Digite uma senha.')
    if senha != confirmar:
        raise SystemExit('As senhas precisam ser iguais.')
    if len(senha) > 128:
        raise SystemExit('A senha pode ter até 128 caracteres.')
    existente = query_one('SELECT id FROM administrador WHERE email=%s', (email,))
    if existente:
        execute('UPDATE administrador SET nome=%s,senha_hash=%s,ativo=1,versao_sessao=versao_sessao+1 WHERE id=%s',
                (nome, generate_password_hash(senha), existente['id']))
    else:
        execute('INSERT INTO administrador(nome,email,senha_hash) VALUES (%s,%s,%s)',
                (nome, email, generate_password_hash(senha)))
    print('Administrador pronto. Entre em /admin com esse e-mail e senha.')


if __name__ == '__main__':
    criar_admin()

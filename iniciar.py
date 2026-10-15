"""Um endereco para o aplicativo e a administracao, sem dois terminais."""
import argparse
import os
import shutil
import subprocess
import sys
import webbrowser
from pathlib import Path

RAIZ = Path(__file__).resolve().parent


def executar():
    parser = argparse.ArgumentParser(description='Iniciar Mentorly localmente')
    parser.add_argument('--recompilar', action='store_true', help='Atualizar aplicativo apos alterar Dart')
    parser.add_argument('--sem-navegador', action='store_true')
    args = parser.parse_args()
    os.chdir(RAIZ)
    sys.path.insert(0, str(RAIZ / 'backend'))
    import config
    from cryptography.fernet import Fernet
    import secrets
    # Persiste apenas chaves ausentes, sem sobrescrever banco, SMTP ou chaves do usuario.
    novas = {}
    if not os.environ.get('SECRET_KEY'):
        novas['SECRET_KEY'] = secrets.token_hex(32)
    if not os.environ.get('BACKUP_KEY'):
        novas['BACKUP_KEY'] = Fernet.generate_key().decode()
    if novas:
        with (RAIZ / 'backend' / '.env').open('a', encoding='utf-8') as arquivo:
            for chave, valor in novas.items():
                arquivo.write('\n' + chave + '=' + valor + '\n')
                os.environ[chave] = valor
        if 'SECRET_KEY' in novas:
            config.SECRET_KEY = novas['SECRET_KEY']
    if config.PRODUCAO:
        raise SystemExit('Este iniciador é local. Na hospedagem use backend/wsgi.py, conforme o guia.')
    build = RAIZ / 'frontend' / 'app_mentorly' / 'build' / 'web'
    marcador = build / '.mentorly-unificado'
    versao_build = 'API_URL=/api;ADMIN_FLUTTER=1'
    if args.recompilar or not marcador.exists() or marcador.read_text(encoding='utf-8').strip() != versao_build:
        flutter = shutil.which('flutter')
        if not flutter:
            raise SystemExit('Flutter não encontrado no PATH.')
        print('Preparando aplicativo. A primeira execução pode demorar alguns minutos.', flush=True)
        subprocess.run([flutter, 'build', 'web', '--release', '--no-web-resources-cdn',
                        '--dart-define=API_URL=/api'], cwd=build.parents[1], check=True)
        marcador.write_text(versao_build+'\n', encoding='utf-8')
    config.WEB_BUILD_DIR = str(build)
    config.APP_BASE_URL = 'http://localhost:5000'
    from services import email_service
    email_service.APP_BASE_URL = config.APP_BASE_URL
    from database.connection import init_database, install_schema, install_procedures, query_one
    print('Conferindo banco de dados e preparando acessos...', flush=True)
    init_database()
    if query_one('SELECT 1 AS ok FROM information_schema.TABLES WHERE TABLE_SCHEMA=%s '
                 "AND TABLE_NAME='coordenacao'", (config.DB_CONFIG['database'],)):
        from scripts.backup import criar_backup
        print('Salvando backup antes de atualizar o banco...', flush=True)
        criar_backup()
    install_schema()
    install_procedures()
    if not query_one('SELECT id FROM administrador WHERE ativo=1 LIMIT 1'):
        from scripts.criar_admin import criar_admin
        criar_admin()
    from app import create_app
    from servidor_local import servir
    print('\nAplicativo: http://localhost:5000\nAdministração: http://localhost:5000/admin\n'
          'Mantenha este terminal aberto. Para encerrar: Ctrl+C.\n', flush=True)
    if not args.sem_navegador:
        import threading
        threading.Timer(1.5, lambda: webbrowser.open('http://localhost:5000')).start()
    servir(create_app(), host='127.0.0.1', port=5000)


if __name__ == '__main__':
    executar()

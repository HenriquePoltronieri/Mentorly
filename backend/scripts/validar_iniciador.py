"""Inicializacao unificada real, com banco exclusivo e servidor substituido."""
import os
import sys
from pathlib import Path
from unittest.mock import patch
from cryptography.fernet import Fernet

RAIZ = Path(__file__).resolve().parents[2]
os.environ.update(DB_NAME='mentorly_qa_completa', MAIL_SERVER='', SMTP_HOST='', APP_ENV='development',
                  SECRET_KEY='chave-efemera-exclusiva-do-teste-de-iniciador',
                  BACKUP_KEY=Fernet.generate_key().decode(), BACKUP_DIR=str(RAIZ/'backups'/'qa-iniciador'))
sys.path.insert(0, str(RAIZ))
sys.path.insert(0, str(RAIZ/'backend'))
import iniciar


def servir(app, **opcoes):
    client = app.test_client()
    assert client.get('/').status_code == 200
    assert client.get('/health').status_code == 200
    assert client.get('/api/acesso').status_code == 401
    assert client.get('/admin').status_code == 302
    assert opcoes['host'] == '127.0.0.1'


marcador = RAIZ/'frontend/app_mentorly/build/web/.mentorly-unificado'
assert (marcador.parent/'index.html').exists(), 'Compile a versao Web antes deste teste.'
marcador.write_text('API_URL=/api;ADMIN_FLUTTER=1\n', encoding='utf-8')
with patch.object(sys, 'argv', ['iniciar.py', '--sem-navegador']), patch('servidor_local.servir', side_effect=servir):
    iniciar.executar()
# Os backups deste teste usam chave efemera, nunca a chave do usuario.
for backup in (RAIZ/'backups'/'qa-iniciador').glob('mentorly-*.sql.gz.enc'):
    backup.unlink()
print('OK: iniciador gera backup, prepara banco e serve app, admin e API no mesmo endereco.')

"""Servidor exclusivo para revisao visual, sem SMTP e sem a base pessoal."""
import os
import sys
from pathlib import Path
RAIZ = Path(__file__).resolve().parents[2]
os.environ.update(DB_NAME='mentorly_qa_completa', MAIL_SERVER='', SMTP_HOST='', APP_ENV='development',
                  WEB_BUILD_DIR=str(RAIZ/'frontend/app_mentorly/build/web'), DEV_EXPOSE_AUTH_CODES='false')
sys.path.insert(0, str(RAIZ/'backend'))
from app import create_app
from servidor_local import servir

if __name__ == '__main__':
    servir(create_app(), host='127.0.0.1', port=5002)

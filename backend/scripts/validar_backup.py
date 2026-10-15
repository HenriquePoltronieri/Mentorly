"""Prova backup e restauracao com dados ficticios em dois bancos exclusivos."""
import os
import sys
import uuid
from pathlib import Path
from cryptography.fernet import Fernet
os.environ.update(DB_NAME='mentorly_qa_completa', BACKUP_KEY=Fernet.generate_key().decode(),
                  BACKUP_DIR=str(Path(__file__).resolve().parents[2]/'backups'/'qa'))
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from scripts.backup import criar_backup
from scripts.restaurar_backup import restaurar
from database.connection import query_one, get_connection
from config import DB_CONFIG

assert DB_CONFIG['database'] == 'mentorly_qa_completa'
backup = criar_backup()
destino = 'mentorly_restauracao_qa_' + uuid.uuid4().hex[:10]
restaurar(backup, destino)
conexao = get_connection(com_banco=False)
try:
    with conexao.cursor() as c:
        for tabela in ('coordenacao', 'nota', 'administrador', 'acesso_escola', 'acesso_historico'):
            original = query_one('SELECT COUNT(*) AS n FROM ' + tabela)['n']
            c.execute('SELECT COUNT(*) AS n FROM `%s`.`%s`' % (destino, tabela))
            assert c.fetchone()['n'] == original, tabela
        c.execute('SELECT COUNT(*) AS n FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA=%s', (destino,))
        assert c.fetchone()['n'] == 5
        # Apenas o banco descartavel recem-criado por este teste.
        assert destino.startswith('mentorly_restauracao_qa_') and destino != DB_CONFIG['database']
        c.execute('DROP DATABASE `%s`' % destino)
    conexao.commit()
finally:
    conexao.close()
    backup.unlink(missing_ok=True)  # chave efemera: nao deixa arquivo inutil
print('OK: notas, escolas, administradores, acessos, histórico e 5 procedures restaurados.')

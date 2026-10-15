"""Restaura em banco NOVO; nunca sobrescreve a base em uso."""
import argparse
import os
import re
import subprocess
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from config import DB_CONFIG
from database.connection import get_connection
from scripts.backup import descriptografar, localizar_dump


def restaurar(arquivo, banco):
    if not re.fullmatch(r'mentorly_restauracao_[a-zA-Z0-9_]{1,40}', banco):
        raise ValueError('Use um banco novo com prefixo mentorly_restauracao_.')
    sql = descriptografar(Path(arquivo).read_bytes(), os.environ['BACKUP_KEY'].encode())
    # O dump deve ser de um banco unico sem instrucoes para selecionar outro.
    if re.search(rb'^\s*(?:USE\s|CREATE\s+DATABASE\s)', sql, flags=re.MULTILINE | re.IGNORECASE):
        raise ValueError('O backup seleciona outro banco. Restauração automática recusada.')
    conexao = get_connection(com_banco=False)
    try:
        with conexao.cursor() as c:
            c.execute('SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME=%s', (banco,))
            if c.fetchone():
                raise ValueError('Esse banco já existe. Escolha um nome novo para preservar seus dados.')
            c.execute('CREATE DATABASE `%s` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci' % banco)
        conexao.commit()
    finally:
        conexao.close()
    dump = Path(localizar_dump())
    cliente = str(dump.with_name('mysql.exe' if os.name == 'nt' else 'mysql'))
    comando = [cliente, '--host='+DB_CONFIG['host'], '--port='+str(DB_CONFIG['port']),
               '--user='+DB_CONFIG['user'], '--database='+banco]
    resultado = subprocess.run(comando, input=sql, capture_output=True, timeout=300,
                               env=dict(os.environ, MYSQL_PWD=DB_CONFIG['password']))
    if resultado.returncode:
        raise RuntimeError('A restauração falhou. O banco novo foi preservado para conferência; a base original não foi alterada.')
    print('Backup restaurado em banco novo:', banco)
    return banco


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('arquivo')
    parser.add_argument('--banco', required=True)
    args = parser.parse_args()
    restaurar(args.arquivo, args.banco)

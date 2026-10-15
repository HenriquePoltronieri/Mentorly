"""Backup MySQL comprimido e criptografado. Agende diariamente na hospedagem.

Guarde BACKUP_KEY separada dos arquivos .enc; sem ela nao existe restauracao.
"""
import gzip
import os
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from config import DB_CONFIG
from cryptography.fernet import Fernet


def localizar_dump():
    configurado = os.environ.get('MYSQLDUMP_PATH')
    if configurado:
        return configurado
    caminho = shutil.which('mysqldump')
    if caminho:
        return caminho
    candidatos = list(Path(os.environ.get('ProgramFiles', 'C:/Program Files')).glob('MySQL/*/bin/mysqldump.exe'))
    if candidatos:
        return str(candidatos[-1])
    raise RuntimeError('mysqldump não encontrado. Configure MYSQLDUMP_PATH.')


def criptografar(conteudo, chave):
    return Fernet(chave).encrypt(gzip.compress(conteudo))


def descriptografar(conteudo, chave):
    return gzip.decompress(Fernet(chave).decrypt(conteudo))


def criar_backup():
    chave = os.environ.get('BACKUP_KEY', '').encode()
    if not chave:
        raise RuntimeError('Configure BACKUP_KEY antes de gerar o backup.')
    Fernet(chave)  # valida antes de consultar o banco
    from database.connection import execute, query_one
    if query_one('SELECT 1 AS ok FROM information_schema.TABLES WHERE TABLE_SCHEMA=%s '
                 "AND TABLE_NAME='limite_requisicao'", (DB_CONFIG['database'],)):
        execute('DELETE FROM limite_requisicao WHERE expira_em < %s', (datetime.now(timezone.utc).timestamp(),))
    pasta = Path(os.environ.get('BACKUP_DIR', str(Path(__file__).resolve().parents[2] / 'backups')))
    pasta.mkdir(parents=True, exist_ok=True)
    # A senha nao aparece nos argumentos, logs, arquivo SQL ou nome do backup.
    ambiente = dict(os.environ, MYSQL_PWD=DB_CONFIG['password'])
    comando = [localizar_dump(), '--host='+DB_CONFIG['host'], '--port='+str(DB_CONFIG['port']),
               '--user='+DB_CONFIG['user'], '--single-transaction', '--quick', '--routines',
               '--triggers', '--no-tablespaces', '--set-gtid-purged=OFF', DB_CONFIG['database']]
    resultado = subprocess.run(comando, env=ambiente, capture_output=True, timeout=300)
    if resultado.returncode:
        # stderr do driver pode conter detalhes de infraestrutura; nao publica.
        raise RuntimeError('Backup recusado pelo MySQL. Confira conexão e permissões do usuário de backup.')
    conteudo = criptografar(resultado.stdout, chave)
    nome = 'mentorly-' + datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ') + '.sql.gz.enc'
    destino = pasta / nome
    with tempfile.NamedTemporaryFile(dir=pasta, suffix='.tmp', delete=False) as arquivo:
        temporario = Path(arquivo.name)
        arquivo.write(conteudo)
    try:
        if descriptografar(temporario.read_bytes(), chave) != resultado.stdout:
            raise RuntimeError('A verificação do backup falhou.')
        temporario.replace(destino)
    finally:
        temporario.unlink(missing_ok=True)
    # Retencao apenas dos backups deste script, dentro da pasta explicitamente configurada.
    retencao = max(2, int(os.environ.get('BACKUP_RETENCAO', '14')))
    for antigo in sorted(pasta.glob('mentorly-*.sql.gz.enc'), reverse=True)[retencao:]:
        if antigo.parent.resolve() == pasta.resolve():
            antigo.unlink()
    print('Backup criptografado e verificado:', destino)
    return destino


if __name__ == '__main__':
    criar_backup()

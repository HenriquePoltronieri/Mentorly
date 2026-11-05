"""Identifica o codigo carregado no inicio do processo, sem expor configuracao."""
import hashlib
from pathlib import Path


def versao_codigo():
    raiz = Path(__file__).resolve().parents[2]
    arquivos = sorted((raiz / 'services' / 'ia').glob('*.py'))
    arquivos += [raiz / 'routes' / 'professor_routes.py', raiz / 'app.py']
    resumo = hashlib.sha256()
    for arquivo in arquivos:
        resumo.update(arquivo.name.encode())
        resumo.update(arquivo.read_bytes())
    return resumo.hexdigest()[:12]


VERSAO_IA = versao_codigo()

"""Diagnostico seguro: nao consulta alunos nem imprime chaves.

Execute no MESMO terminal do Flask: python scripts/diagnosticar_ia.py
O teste externo usa exclusivamente dados ficticios.
"""
import logging
import sys
from pathlib import Path
from urllib.request import urlopen
from urllib.error import URLError

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from config import AI_CONFIG
from services.ia.client import AIClient, AIError
from services.ia.versao import VERSAO_IA


def main():
    logging.basicConfig(level=logging.INFO)
    if '--servidor' in sys.argv:
        try:
            with urlopen('http://127.0.0.1:5000/', timeout=5) as resposta:
                ativa = resposta.headers.get('X-Mentorly-IA-Version')
        except (URLError, OSError):
            print('FALHOU: backend local inacessivel na porta 5000.')
            return 1
        if ativa != VERSAO_IA:
            print('FALHOU: servidor desatualizado. Pare o Flask e execute python app.py novamente neste backend.')
            return 1
        print('OK: servidor local carregou a versao atual (%s).' % ativa)
    print('Chave: %s | Modelo: %s | Timeout: %ss' % (
        'configurada' if AI_CONFIG['api_key'] else 'AUSENTE',
        AI_CONFIG['model'], AI_CONFIG['timeout']))
    try:
        AIClient().gerar({
            'turma': {'nome': 'Turma ficticia'},
            'resumoNumerico': {'totalAlunos': 1, 'emAndamento': 1},
            'alunos': [{'referencia': 'Aluno 1', 'situacao': 'em_andamento',
                        'percentual': None, 'atividadesAvaliadas': 1}],
        })
    except AIError as erro:
        print('FALHOU: %s. Confira backend/.env e variaveis AI_* herdadas pelo terminal.' % erro.codigo)
        return 1
    print('OK: provedor respondeu e o formato foi validado (dados ficticios).')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

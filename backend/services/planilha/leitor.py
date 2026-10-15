"""Leitura de planilhas CSV e XLSX enviadas por upload.

Devolve sempre a mesma estrutura, independente do formato: uma lista de
dicts com as chaves em minusculo, mais o numero da linha no arquivo (para a
mensagem de erro apontar exatamente onde o usuario errou).
"""

import csv
import io
import zipfile

from openpyxl import load_workbook

EXTENSOES_ACEITAS = (".csv", ".xlsx")
MAX_LINHAS = 5001  # cabecalho + 5000 registros
MAX_COLUNAS = 50
MAX_DESCOMPACTADO = 40 * 1024 * 1024


class PlanilhaInvalida(Exception):
    """Arquivo que nem chega a ser processado linha a linha."""


def _normalizar_cabecalho(valor):
    return str(valor or "").strip().lower()


def _ler_csv(conteudo):
    # Planilha exportada do Excel no Brasil costuma vir em cp1252 e com ';'.
    for codificacao in ("utf-8-sig", "utf-8", "cp1252", "latin-1"):
        try:
            texto = conteudo.decode(codificacao)
            break
        except UnicodeDecodeError:
            continue
    else:
        raise PlanilhaInvalida("Nao foi possivel ler o arquivo CSV")

    amostra = texto[:2048]
    try:
        dialeto = csv.Sniffer().sniff(amostra, delimiters=",;\t")
        delimitador = dialeto.delimiter
    except csv.Error:
        delimitador = ";" if amostra.count(";") > amostra.count(",") else ","

    leitor = csv.reader(io.StringIO(texto), delimiter=delimitador)
    return _limitar_linhas(leitor)


def _limitar_linhas(linhas):
    resultado = []
    for numero, linha in enumerate(linhas, 1):
        if numero > MAX_LINHAS or len(linha) > MAX_COLUNAS:
            raise PlanilhaInvalida('A planilha aceita até 5000 registros e 50 colunas.')
        if any(len(str(c or '')) > 16000 for c in linha):
            raise PlanilhaInvalida('Uma célula da planilha excede o tamanho permitido.')
        resultado.append(list(linha))
    return resultado


def _ler_xlsx(conteudo):
    try:
        with zipfile.ZipFile(io.BytesIO(conteudo)) as arquivo:
            itens = arquivo.infolist()
            if len(itens) > 1000 or sum(i.file_size for i in itens) > MAX_DESCOMPACTADO:
                raise PlanilhaInvalida('Planilha XLSX muito grande após descompactar.')
            for item in itens:
                if item.filename.lower().endswith('.xml'):
                    # Remove os bytes nulos de XML UTF-16/32 antes de procurar DTD.
                    xml = arquivo.read(item).replace(b'\x00', b'').upper()
                    if b'<!DOCTYPE' in xml or b'<!ENTITY' in xml:
                        raise PlanilhaInvalida('A planilha contém declarações XML não permitidas.')
        planilha = load_workbook(io.BytesIO(conteudo), read_only=True, data_only=True)
    except PlanilhaInvalida:
        raise
    except Exception:
        raise PlanilhaInvalida("Nao foi possivel abrir a planilha XLSX")

    try:
        aba = planilha.active
        if aba is None or (aba.max_column or 0) > MAX_COLUNAS or (aba.max_row or 0) > MAX_LINHAS:
            raise PlanilhaInvalida('A planilha aceita até 5000 registros e 50 colunas.')
        return _limitar_linhas(aba.iter_rows(values_only=True))
    except PlanilhaInvalida:
        raise
    except Exception:
        raise PlanilhaInvalida('Não foi possível ler o conteúdo da planilha XLSX.')
    finally:
        planilha.close()


def ler_planilha(nome_arquivo, conteudo):
    """Le o arquivo e devolve [(numero_da_linha, {coluna: valor}), ...].

    A primeira linha nao vazia e tratada como cabecalho.
    """
    nome = (nome_arquivo or "").lower()
    if not isinstance(conteudo, bytes) or len(conteudo) > 5 * 1024 * 1024:
        raise PlanilhaInvalida('Envie uma planilha de até 5 MB.')
    if nome.endswith(".xlsx"):
        linhas = _ler_xlsx(conteudo)
    elif nome.endswith(".csv"):
        linhas = _ler_csv(conteudo)
    else:
        raise PlanilhaInvalida("Envie um arquivo .csv ou .xlsx")

    # Descarta linhas totalmente vazias, mas guarda o numero original para
    # que o erro devolvido aponte a linha certa do arquivo do usuario.
    numeradas = [
        (numero, linha)
        for numero, linha in enumerate(linhas, start=1)
        if any(str(c or "").strip() for c in linha)
    ]
    if not numeradas:
        raise PlanilhaInvalida("A planilha esta vazia")

    _, cabecalho_bruto = numeradas[0]
    colunas = [_normalizar_cabecalho(c) for c in cabecalho_bruto]
    preenchidas = [c for c in colunas if c]
    if len(set(preenchidas)) != len(preenchidas):
        raise PlanilhaInvalida('A planilha tem colunas repetidas. Use o modelo de importação.')
    if not any(colunas):
        raise PlanilhaInvalida("A planilha nao tem cabecalho")

    registros = []
    for numero, linha in numeradas[1:]:
        registro = {}
        for indice, coluna in enumerate(colunas):
            if not coluna:
                continue
            valor = linha[indice] if indice < len(linha) else None
            registro[coluna] = "" if valor is None else str(valor).strip()
        registros.append((numero, registro))

    return colunas, registros


def exigir_colunas(colunas, obrigatorias):
    faltando = [c for c in obrigatorias if c not in colunas]
    if faltando:
        raise PlanilhaInvalida(
            "A planilha precisa ter a(s) coluna(s): %s" % ", ".join(faltando)
        )

"""Documentos legais versionados e historico das decisoes dos usuarios."""

from hashlib import sha256
from pathlib import Path

from database.connection import query_all, query_one, transacao


_PASTA = Path(__file__).resolve().parents[1] / "termos_docs"
_ARQUIVOS = {
    "uso": ("Termo de Uso", "uso-81d729fd7f66.txt"),
    "consentimento": ("Termo de Consentimento", "consentimento-fd24e1dc9900.txt"),
}


def documentos_atuais(incluir_texto=True):
    documentos = {}
    for tipo, (titulo, arquivo) in _ARQUIVOS.items():
        conteudo = (_PASTA / arquivo).read_text(encoding="utf-8")
        digest = sha256(conteudo.encode("utf-8")).hexdigest()
        documento = {"tipo": tipo, "titulo": titulo, "versao": digest[:12],
                     "sha256": digest}
        if incluir_texto:
            documento["texto"] = conteudo
        documentos[tipo] = documento
    return documentos


def validar_escolhas(dados, exigir_uso=True):
    if not isinstance(dados, dict):
        raise ValueError("Informe as duas decisoes sobre os termos")
    escolhas = dados.get("decisoes")
    versoes = dados.get("versoes")
    if not isinstance(escolhas, dict) or not isinstance(versoes, dict):
        raise ValueError("Informe as duas decisoes e as versoes dos documentos")
    atuais = documentos_atuais(False)
    for tipo in _ARQUIVOS:
        if type(escolhas.get(tipo)) is not bool:
            raise ValueError("Escolha aceitar ou recusar cada documento")
        if versoes.get(tipo) != atuais[tipo]["sha256"]:
            raise ValueError("Os documentos foram atualizados. Leia a versao atual.")
    if exigir_uso and not escolhas["uso"]:
        raise ValueError("Para criar a conta, e necessario aceitar o Termo de Uso")
    return escolhas, atuais


def _filtro_usuario(usuario):
    if usuario["tipo"] == "coordenacao":
        return "coordenacao_id=%s AND professor_id IS NULL", (usuario["coordenacao_id"],)
    return "coordenacao_id=%s AND professor_id=%s", (
        usuario["coordenacao_id"], usuario["id"])


def _ultima_decisao(usuario, tipo):
    filtro, parametros = _filtro_usuario(usuario)
    return query_one(
        "SELECT id, documento, versao, sha256, decisao, registrado_em "
        "FROM decisao_termo WHERE " + filtro + " AND documento=%s "
        "ORDER BY id DESC LIMIT 1", parametros + (tipo,))


def situacao(usuario):
    atuais = documentos_atuais(False)
    decisoes = {}
    for tipo in _ARQUIVOS:
        linha = _ultima_decisao(usuario, tipo)
        decisao = linha["decisao"] if linha and linha["sha256"] == atuais[tipo]["sha256"] else None
        decisoes[tipo] = decisao
    return {
        "documentos": atuais,
        "decisoes": decisoes,
        "pendente": decisoes["uso"] != "aceito" or decisoes["consentimento"] is None,
        "iaPermitida": decisoes["uso"] == "aceito" and decisoes["consentimento"] == "aceito",
    }


def inserir_decisoes(cursor, coordenacao_id, professor_id, escolhas, atuais):
    for tipo in _ARQUIVOS:
        documento = atuais[tipo]
        cursor.execute(
            "INSERT INTO decisao_termo "
            "(coordenacao_id, professor_id, documento, versao, sha256, decisao, registrado_em) "
            "VALUES (%s,%s,%s,%s,%s,%s,UTC_TIMESTAMP(6))",
            (coordenacao_id, professor_id, tipo, documento["versao"],
             documento["sha256"], "aceito" if escolhas[tipo] else "recusado"),
        )


def registrar_decisoes(usuario, dados):
    escolhas, atuais = validar_escolhas(dados, exigir_uso=False)
    anteriores = {tipo: _ultima_decisao(usuario, tipo) for tipo in _ARQUIVOS}
    professor_id = usuario["id"] if usuario["tipo"] == "professor" else None
    with transacao() as cursor:
        for tipo in _ARQUIVOS:
            anterior = anteriores[tipo]
            if tipo == "consentimento" and not escolhas[tipo] and anterior and \
                    anterior["sha256"] == atuais[tipo]["sha256"] and anterior["decisao"] == "aceito":
                decisao = "revogado"
            else:
                decisao = "aceito" if escolhas[tipo] else "recusado"
            if anterior and anterior["sha256"] == atuais[tipo]["sha256"] and (
                    anterior["decisao"] == decisao or
                    (tipo == "consentimento" and not escolhas[tipo] and
                     anterior["decisao"] == "revogado")):
                continue
            documento = atuais[tipo]
            cursor.execute(
                "INSERT INTO decisao_termo "
                "(coordenacao_id, professor_id, documento, versao, sha256, decisao, registrado_em) "
                "VALUES (%s,%s,%s,%s,%s,%s,UTC_TIMESTAMP(6))",
                (usuario["coordenacao_id"], professor_id, tipo, documento["versao"],
                 documento["sha256"], decisao),
            )
    return situacao(usuario)


def historico(usuario):
    filtro, parametros = _filtro_usuario(usuario)
    linhas = query_all(
        "SELECT documento, versao, sha256, decisao, registrado_em "
        "FROM decisao_termo WHERE " + filtro + " ORDER BY id DESC LIMIT 100", parametros)
    return [dict(documento=linha["documento"], versao=linha["versao"],
                 sha256=linha["sha256"], decisao=linha["decisao"],
                 registradoEm=linha["registrado_em"].isoformat() + "Z")
            for linha in linhas]

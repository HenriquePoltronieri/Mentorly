"""Anexos privados de atividades, com validacao de tipo e de acesso."""

import io
import zipfile
from pathlib import PurePath

from erros import RecursoNaoEncontrado
from models.atividade_anexo_model import AtividadeAnexo
from models.atividade_model import Atividade
from models.etapa_model import Etapa
from models.professor_turma_model import ProfessorTurma


MAXIMO_BYTES = 8 * 1024 * 1024
MAXIMO_ANEXOS = 10
TIPOS = {
    ".pdf": "application/pdf",
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    ".xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    ".pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
    ".txt": "text/plain; charset=utf-8",
    ".csv": "text/csv; charset=utf-8",
}


def _atividade_acessivel(atividade_id, professor_id, coordenacao_id):
    atividade = Atividade.find_by_id(atividade_id)
    if (not atividade or atividade.get("coordenacao_id") != coordenacao_id or
            not ProfessorTurma.professor_leciona_na_turma(
                professor_id, atividade["turma_id"])):
        raise RecursoNaoEncontrado("Atividade nao encontrada")
    return atividade


def _exigir_editavel(atividade, coordenacao_id):
    if atividade.get("etapa_id") and Etapa.esta_fechada(
            atividade["etapa_id"], coordenacao_id):
        raise ValueError(
            "Esta atividade pertence a uma etapa fechada. Reabra a etapa "
            "antes de alterar seus anexos.")


def _nome_seguro(nome):
    nome = PurePath(str(nome or "").replace("\\", "/")).name.strip()
    if not nome or len(nome) > 200 or any(ord(c) < 32 for c in nome):
        raise ValueError("Nome de arquivo invalido")
    return nome


def _validar_zip_office(conteudo, extensao):
    pasta = {".docx": "word/", ".xlsx": "xl/", ".pptx": "ppt/"}[extensao]
    try:
        with zipfile.ZipFile(io.BytesIO(conteudo)) as pacote:
            itens = pacote.infolist()
            if (len(itens) > 2000 or
                    sum(item.file_size for item in itens) > 50 * 1024 * 1024 or
                    not any(item.filename.startswith(pasta) for item in itens)):
                raise ValueError
    except (zipfile.BadZipFile, ValueError, OSError):
        raise ValueError("O arquivo do Office esta invalido ou corrompido")


def validar_arquivo(nome, conteudo):
    nome = _nome_seguro(nome)
    if not isinstance(conteudo, bytes) or not conteudo:
        raise ValueError("O arquivo esta vazio")
    if len(conteudo) > MAXIMO_BYTES:
        raise ValueError("O arquivo ultrapassa o limite de 8 MB")
    extensao = PurePath(nome).suffix.casefold()
    if extensao not in TIPOS:
        raise ValueError(
            "Formato nao permitido. Use PDF, imagem, DOCX, XLSX, PPTX, TXT ou CSV.")
    if extensao == ".pdf" and not conteudo.startswith(b"%PDF-"):
        raise ValueError("O PDF esta invalido ou corrompido")
    if extensao == ".png" and not conteudo.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError("A imagem PNG esta invalida")
    if extensao in (".jpg", ".jpeg") and not conteudo.startswith(b"\xff\xd8\xff"):
        raise ValueError("A imagem JPEG esta invalida")
    if extensao in (".docx", ".xlsx", ".pptx"):
        _validar_zip_office(conteudo, extensao)
    if extensao in (".txt", ".csv"):
        try:
            conteudo.decode("utf-8")
        except UnicodeDecodeError:
            raise ValueError("O arquivo de texto precisa estar em UTF-8")
    return nome, TIPOS[extensao]


class AnexosAtividadeService:
    def listar(self, atividade_id, professor_id, coordenacao_id):
        _atividade_acessivel(atividade_id, professor_id, coordenacao_id)
        return [AtividadeAnexo.to_dict(a) for a in
                AtividadeAnexo.listar(atividade_id, coordenacao_id)]

    def enviar(self, atividade_id, professor_id, coordenacao_id, nome,
               conteudo):
        atividade = _atividade_acessivel(
            atividade_id, professor_id, coordenacao_id)
        _exigir_editavel(atividade, coordenacao_id)
        if len(AtividadeAnexo.listar(atividade_id, coordenacao_id)) >= MAXIMO_ANEXOS:
            raise ValueError(
                "A atividade atingiu o limite de 10 arquivos anexados")
        nome, mime = validar_arquivo(nome, conteudo)
        anexo_id = AtividadeAnexo.criar(
            coordenacao_id, atividade_id, professor_id, nome, mime, conteudo)
        return AtividadeAnexo.to_dict(AtividadeAnexo.buscar(
            anexo_id, atividade_id, coordenacao_id))

    def baixar(self, atividade_id, anexo_id, professor_id, coordenacao_id):
        _atividade_acessivel(atividade_id, professor_id, coordenacao_id)
        anexo = AtividadeAnexo.buscar(
            anexo_id, atividade_id, coordenacao_id, com_conteudo=True)
        if not anexo:
            raise RecursoNaoEncontrado("Anexo nao encontrado")
        return anexo

    def excluir(self, atividade_id, anexo_id, professor_id, coordenacao_id):
        atividade = _atividade_acessivel(
            atividade_id, professor_id, coordenacao_id)
        _exigir_editavel(atividade, coordenacao_id)
        if not AtividadeAnexo.buscar(anexo_id, atividade_id, coordenacao_id):
            raise RecursoNaoEncontrado("Anexo nao encontrado")
        AtividadeAnexo.excluir(anexo_id, atividade_id, coordenacao_id)

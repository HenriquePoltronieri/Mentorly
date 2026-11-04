"""Metadados e conteudo privado dos arquivos anexados a uma atividade."""

from database.connection import execute, insert, query_all, query_one
from database.orm import db
from models.utils import iso


class AtividadeAnexo(db.Model):
    __tablename__ = "atividade_anexo"

    id = db.Column(db.Integer, primary_key=True)
    coordenacao_id = db.Column(db.Integer, nullable=False)
    atividade_id = db.Column(db.Integer, nullable=False)
    professor_id = db.Column(db.Integer, nullable=False)
    nome_original = db.Column(db.String(200), nullable=False)
    tipo_mime = db.Column(db.String(100), nullable=False)
    tamanho_bytes = db.Column(db.Integer, nullable=False)
    conteudo = db.Column(db.LargeBinary, nullable=False)
    created_at = db.Column(db.DateTime)

    @staticmethod
    def criar(coordenacao_id, atividade_id, professor_id, nome, mime,
              conteudo):
        return insert(
            "INSERT INTO atividade_anexo "
            "(coordenacao_id,atividade_id,professor_id,nome_original,"
            "tipo_mime,tamanho_bytes,conteudo) VALUES (%s,%s,%s,%s,%s,%s,%s)",
            (coordenacao_id, atividade_id, professor_id, nome, mime,
             len(conteudo), conteudo),
        )

    @staticmethod
    def listar(atividade_id, coordenacao_id):
        return query_all(
            "SELECT id,coordenacao_id,atividade_id,professor_id,nome_original,"
            "tipo_mime,tamanho_bytes,created_at FROM atividade_anexo "
            "WHERE atividade_id=%s AND coordenacao_id=%s ORDER BY created_at,id",
            (atividade_id, coordenacao_id),
        )

    @staticmethod
    def buscar(anexo_id, atividade_id, coordenacao_id, com_conteudo=False):
        colunas = ("id,coordenacao_id,atividade_id,professor_id,nome_original,"
                   "tipo_mime,tamanho_bytes,created_at")
        if com_conteudo:
            colunas += ",conteudo"
        return query_one(
            "SELECT %s FROM atividade_anexo WHERE id=%%s AND atividade_id=%%s "
            "AND coordenacao_id=%%s" % colunas,
            (anexo_id, atividade_id, coordenacao_id),
        )

    @staticmethod
    def excluir(anexo_id, atividade_id, coordenacao_id):
        return execute(
            "DELETE FROM atividade_anexo WHERE id=%s AND atividade_id=%s "
            "AND coordenacao_id=%s", (anexo_id, atividade_id, coordenacao_id))

    @staticmethod
    def to_dict(linha):
        return {
            "id": linha["id"],
            "atividade_id": linha["atividade_id"],
            "nome": linha["nome_original"],
            "tipo_mime": linha["tipo_mime"],
            "tamanho_bytes": linha["tamanho_bytes"],
            "created_at": iso(linha.get("created_at")),
        }

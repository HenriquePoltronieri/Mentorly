"""Model da Coordenacao (a escola)."""

from database.connection import execute, insert, query_all, query_one, transacao
from database.orm import db
from models.utils import iso


class Coordenacao(db.Model):
    __tablename__ = "coordenacao"
    id = db.Column(db.Integer, primary_key=True)
    nome = db.Column(db.String(150), nullable=False)
    email = db.Column(db.String(150), nullable=False, unique=True)
    senha_hash = db.Column(db.String(255), nullable=False)
    telefone = db.Column(db.String(30))
    created_at = db.Column(db.DateTime)
    updated_at = db.Column(db.DateTime)
    TABELA = "coordenacao"

    @staticmethod
    def excluir_com_dependencias(escola_id, email_confirmacao):
        """Exclusao atomica; o e-mail e conferido na mesma transacao bloqueada."""
        with transacao() as cursor:
            cursor.execute('SELECT id,email FROM coordenacao WHERE id=%s FOR UPDATE', (escola_id,))
            escola = cursor.fetchone()
            if not escola:
                raise ValueError('Esta escola ja nao existe. Atualize a lista.')
            if email_confirmacao != escola['email']:
                raise ValueError('Digite exatamente o e-mail da escola para confirmar a exclusao.')

            cursor.execute('DELETE FROM codigo_verificacao WHERE email=%s', (escola['email'],))
            cursor.execute(
                'DELETE cv FROM codigo_verificacao cv '
                'INNER JOIN professor p ON p.email=cv.email '
                'WHERE p.coordenacao_id=%s', (escola_id,))
            cursor.execute('DELETE FROM atividade WHERE coordenacao_id=%s', (escola_id,))
            cursor.execute(
                'DELETE al FROM aluno al INNER JOIN turma t ON t.id=al.turma_id '
                'WHERE t.coordenacao_id=%s', (escola_id,))
            cursor.execute('DELETE FROM professor_turma WHERE coordenacao_id=%s', (escola_id,))
            cursor.execute('DELETE FROM professor WHERE coordenacao_id=%s', (escola_id,))
            cursor.execute('DELETE FROM criterio WHERE coordenacao_id=%s', (escola_id,))
            cursor.execute('DELETE FROM etapa WHERE coordenacao_id=%s', (escola_id,))
            cursor.execute('DELETE FROM turma WHERE coordenacao_id=%s', (escola_id,))
            cursor.execute('DELETE FROM ano_letivo WHERE coordenacao_id=%s', (escola_id,))
            cursor.execute('DELETE FROM coordenacao WHERE id=%s', (escola_id,))

    # -----------------------------------------------------------------
    # Leitura
    # -----------------------------------------------------------------
    @staticmethod
    def find_all():
        return query_all(
            "SELECT id, nome, email, telefone, created_at, updated_at "
            "FROM coordenacao ORDER BY nome ASC"
        )

    @staticmethod
    def find_by_id(coordenacao_id):
        return query_one(
            "SELECT id, nome, email, telefone, created_at, updated_at "
            "FROM coordenacao WHERE id = %s",
            (coordenacao_id,),
        )

    @staticmethod
    def find_by_email(email):
        """Traz o senha_hash junto: e a unica consulta que precisa dele."""
        return query_one(
            "SELECT id, nome, email, senha_hash, telefone, created_at, updated_at "
            "FROM coordenacao WHERE email = %s",
            (email,),
        )

    # -----------------------------------------------------------------
    # Escrita
    # -----------------------------------------------------------------
    @staticmethod
    def create(nome, email, senha_hash, telefone=None):
        from datetime import timedelta
        from services.horario import agora_brasilia
        prazo = agora_brasilia().date() + timedelta(days=14)
        # Escola e teste nascem juntos: uma falha nao deixa cadastro sem acesso.
        with transacao() as cursor:
            cursor.execute('INSERT INTO coordenacao(nome,email,senha_hash,telefone) VALUES (%s,%s,%s,%s)',
                           (nome, email, senha_hash, telefone))
            escola_id = cursor.lastrowid
            cursor.execute('INSERT INTO acesso_escola(coordenacao_id,valido_ate) VALUES (%s,%s)',
                           (escola_id, prazo))
        return escola_id

    @staticmethod
    def update(coordenacao_id, nome=None, telefone=None, senha_hash=None):
        campos = []
        valores = []
        if nome is not None:
            campos.append("nome = %s")
            valores.append(nome)
        if telefone is not None:
            campos.append("telefone = %s")
            valores.append(telefone)
        if senha_hash is not None:
            campos.append("senha_hash = %s")
            valores.append(senha_hash)
        if not campos:
            return 0
        valores.append(coordenacao_id)
        return execute(
            "UPDATE coordenacao SET %s WHERE id = %%s" % ", ".join(campos),
            tuple(valores),
        )

    @staticmethod
    def delete(coordenacao_id):
        return execute("DELETE FROM coordenacao WHERE id = %s", (coordenacao_id,))

    # -----------------------------------------------------------------
    # Serializacao
    # -----------------------------------------------------------------
    @staticmethod
    def to_dict(linha):
        """Formato que o UserModel do Flutter espera: id, nome, email, tipo."""
        if not linha:
            return None
        return {
            "id": linha["id"],
            "nome": linha["nome"],
            "email": linha["email"],
            "telefone": linha.get("telefone"),
            "tipo": "coordenacao",
            "created_at": iso(linha.get("created_at")),
            "updated_at": iso(linha.get("updated_at")),
        }

"""Entidades comerciais e persistencia do acesso administrativo."""

from database.orm import db
from database.connection import query_one, transacao


class Plano(db.Model):
    __tablename__ = 'plano'
    codigo = db.Column(db.String(40), primary_key=True)
    nome = db.Column(db.String(100), nullable=False)

    @staticmethod
    def existe(codigo):
        return bool(query_one('SELECT codigo FROM plano WHERE codigo=%s', (codigo,)))


class AcessoEscola(db.Model):
    __tablename__ = 'acesso_escola'
    coordenacao_id = db.Column(db.Integer, db.ForeignKey('coordenacao.id'), primary_key=True)
    plano_codigo = db.Column(db.String(40), db.ForeignKey('plano.codigo'), nullable=False)
    situacao = db.Column(db.Enum('teste', 'paga', 'cortesia', 'suspensa', 'pendente'), nullable=False)
    valido_ate = db.Column(db.Date)
    versao = db.Column(db.Integer, nullable=False)
    atualizado_em = db.Column(db.DateTime)

    @staticmethod
    def atualizar_com_historico(escola_id, admin_id, versao, plano, situacao,
                               prazo, motivo):
        """Atualizacao concorrente com registro de auditoria na mesma transacao."""
        with transacao() as cursor:
            cursor.execute('SELECT versao FROM acesso_escola WHERE coordenacao_id=%s FOR UPDATE',
                           (escola_id,))
            atual = cursor.fetchone()
            if not atual or atual['versao'] != versao:
                raise ValueError('Este acesso já foi alterado. Atualize a página antes de salvar novamente.')
            cursor.execute('UPDATE acesso_escola SET plano_codigo=%s,situacao=%s,valido_ate=%s,versao=versao+1 '
                           'WHERE coordenacao_id=%s', (plano, situacao, prazo, escola_id))
            cursor.execute('INSERT INTO acesso_historico(coordenacao_id,administrador_id,situacao,plano_codigo,valido_ate,motivo) '
                           'VALUES (%s,%s,%s,%s,%s,%s)',
                           (escola_id, admin_id, situacao, plano, prazo, motivo))


class AcessoHistorico(db.Model):
    __tablename__ = 'acesso_historico'
    id = db.Column(db.Integer, primary_key=True)
    coordenacao_id = db.Column(db.Integer, db.ForeignKey('coordenacao.id'), nullable=False)
    administrador_id = db.Column(db.Integer, db.ForeignKey('administrador.id'), nullable=False)
    situacao = db.Column(db.String(20), nullable=False)
    plano_codigo = db.Column(db.String(40), nullable=False)
    valido_ate = db.Column(db.Date)
    motivo = db.Column(db.String(500), nullable=False)
    criado_em = db.Column(db.DateTime)


class Administrador(db.Model):
    __tablename__ = 'administrador'
    id = db.Column(db.Integer, primary_key=True)
    nome = db.Column(db.String(150), nullable=False)
    email = db.Column(db.String(150), nullable=False)
    senha_hash = db.Column(db.String(255), nullable=False)
    ativo = db.Column(db.Boolean, nullable=False)
    versao_sessao = db.Column(db.Integer, nullable=False)

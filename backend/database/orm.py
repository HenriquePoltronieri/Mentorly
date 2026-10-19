"""Mapeamento ORM do dominio sobre o schema MySQL existente.

O schema SQL continua sendo a fonte das constraints e procedures. Nao chamar
create_all(): a instalacao e feita por database.connection.install_schema().
"""

from flask_sqlalchemy import SQLAlchemy


db = SQLAlchemy()

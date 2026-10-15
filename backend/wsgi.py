"""Entrada para hospedagem WSGI. Migracoes sao executadas separadamente."""
from app import create_app

app = create_app()

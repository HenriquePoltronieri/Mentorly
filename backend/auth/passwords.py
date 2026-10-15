"""Verifica senha sem revelar a existencia da conta pelo custo do hash."""
import secrets
from werkzeug.security import check_password_hash, generate_password_hash

HASH_INEXISTENTE = generate_password_hash(secrets.token_urlsafe(32))


def conferir_senha(senha_hash, senha):
    confere = check_password_hash(senha_hash or HASH_INEXISTENTE, senha)
    return bool(senha_hash and confere)

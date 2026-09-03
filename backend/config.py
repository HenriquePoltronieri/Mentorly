import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# Conexao com o MySQL. Tudo vem de variavel de ambiente, com um default
# que funciona no XAMPP local (root sem senha).
DB_CONFIG = {
    "host": os.environ.get("DB_HOST", "localhost"),
    "port": int(os.environ.get("DB_PORT", 3306)),
    "user": os.environ.get("DB_USER", "root"),
    "password": os.environ.get("DB_PASSWORD", ""),
    "database": os.environ.get("DB_NAME", "mentorly_db"),
}

# Chave usada para assinar o JWT. Em producao precisa vir do ambiente:
# se o default abaixo for usado, qualquer um consegue forjar um token.
SECRET_KEY = os.environ.get("SECRET_KEY", "mentorly-dev-secret-trocar-em-producao")

# Validade do token de login e do convite que o professor recebe por email.
TOKEN_EXPIRACAO_HORAS = int(os.environ.get("TOKEN_EXPIRACAO_HORAS", 12))
CONVITE_EXPIRACAO_HORAS = int(os.environ.get("CONVITE_EXPIRACAO_HORAS", 72))
CODIGO_EXPIRACAO_MINUTOS = int(os.environ.get("CODIGO_EXPIRACAO_MINUTOS", 15))

# Envio de email. Sem SMTP_HOST configurado o email_service entra em modo
# dev: imprime o codigo/link no console em vez de tentar enviar.
SMTP_CONFIG = {
    "host": os.environ.get("SMTP_HOST", ""),
    "port": int(os.environ.get("SMTP_PORT", 587)),
    "user": os.environ.get("SMTP_USER", ""),
    "password": os.environ.get("SMTP_PASSWORD", ""),
    "remetente": os.environ.get("SMTP_FROM", "nao-responda@mentorly.local"),
    "usar_tls": os.environ.get("SMTP_TLS", "1") == "1",
}

# Base do app Flutter, usada para montar o link do convite do professor.
APP_BASE_URL = os.environ.get("APP_BASE_URL", "http://localhost:3000")

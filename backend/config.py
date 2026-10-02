import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))


def _carregar_env():
    """Le backend/.env, se existir, para dentro de os.environ.

    Serve para a senha do MySQL local nao precisar ser exportada a mao a
    cada terminal novo. O arquivo e ignorado pelo git; uma variavel ja
    definida no ambiente sempre vence a do arquivo.
    """
    caminho = os.path.join(BASE_DIR, ".env")
    if not os.path.exists(caminho):
        return

    with open(caminho, "r", encoding="utf-8") as arquivo:
        for linha in arquivo:
            linha = linha.strip()
            if not linha or linha.startswith("#") or "=" not in linha:
                continue
            chave, _, valor = linha.partition("=")
            chave = chave.strip()
            valor = valor.strip().strip('"').strip("'")
            if chave and chave not in os.environ:
                os.environ[chave] = valor


_carregar_env()

# Conexao com o MySQL. Tudo vem de variavel de ambiente (ou de backend/.env),
# com um default que funciona em um MySQL local de root sem senha.
DB_CONFIG = {
    "host": os.environ.get("DB_HOST", "localhost"),
    "port": int(os.environ.get("DB_PORT", 3306)),
    "user": os.environ.get("DB_USER", "root"),
    "password": os.environ.get("DB_PASSWORD", ""),
    "database": os.environ.get("DB_NAME", "mentorly_db"),
}

# Chave usada para assinar o JWT. Nunca tem um valor padrao fixo: uma chave
# conhecida no codigo permitiria forjar qualquer token. Sem SECRET_KEY no
# ambiente (ou em backend/.env), geramos uma chave aleatoria para esta
# execucao - segura, mas trocada a cada reinicio, entao todas as sessoes
# expiram no restart. E um aviso impossivel de ignorar em vez de uma falha
# silenciosa: quem depender de sessao persistente vai notar e configurar
# SECRET_KEY antes de usar o sistema de verdade.
SECRET_KEY = os.environ.get("SECRET_KEY")
if not SECRET_KEY:
    import secrets as _secrets

    SECRET_KEY = _secrets.token_hex(32)
    print(
        "AVISO: SECRET_KEY nao definida (nem no ambiente, nem em backend/.env). "
        "Uma chave temporaria foi gerada so para esta execucao - todas as "
        "sessoes (tokens JWT) serao invalidadas ao reiniciar o servidor. "
        "Defina SECRET_KEY antes de qualquer uso real."
    )

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

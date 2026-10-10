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

def _booleano_env(nome):
    """True so para um valor explicito ("1", "true", "sim", "yes", "on").

    Variavel ausente, vazia ou com qualquer outro valor e False: o padrao dos
    dois interruptores de desenvolvimento abaixo e sempre o lado seguro.
    """
    return os.environ.get(nome, "").strip().lower() in (
        "1", "true", "sim", "yes", "on"
    )


# Interruptores de DESENVOLVIMENTO. Ambos desligados por padrao; nada no codigo
# os liga. Para usar localmente, ponha-os em backend/.env.
#
# FLASK_DEBUG: liga o modo debug do Flask (recarga automatica e depurador
#   interativo no navegador) ao rodar `python app.py`.
# DEV_EXPOSE_AUTH_CODES: permite que as respostas da API tragam o codigo de
#   verificacao e o token de convite do professor (e que o email que nao e
#   enviado seja impresso no console). Existe so porque localmente nao ha
#   SMTP; sem SMTP, com isto desligado, nada disso vaza.
DEBUG = _booleano_env("FLASK_DEBUG")
DEV_EXPOSE_AUTH_CODES = _booleano_env("DEV_EXPOSE_AUTH_CODES")

# Envio de email. Sem SMTP_HOST o email nao e enviado (o envio devolve False e
# a API responde conviteEnviado/enviado = false); isso NAO libera nenhum codigo
# ou token na resposta: quem decide e DEV_EXPOSE_AUTH_CODES.
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


def _float_positivo_env(nome, padrao):
    try:
        valor = float(os.environ.get(nome, str(padrao)))
        return valor if valor > 0 else float(padrao)
    except (TypeError, ValueError):
        return float(padrao)


# Integracao opcional com um provedor de modelo de linguagem que exponha o
# contrato de chat completions. Sem estas variaveis, apenas o recurso de
# insights fica indisponivel; o restante da aplicacao continua funcionando.
AI_CONFIG = {
    "base_url": (
        os.environ.get("AI_BASE_URL") or "https://api.groq.com/openai/v1"
    ).rstrip("/"),
    "api_key": os.environ.get("AI_API_KEY", ""),
    "model": os.environ.get("AI_MODEL") or "openai/gpt-oss-20b",
    "timeout": _float_positivo_env("AI_TIMEOUT", 15),
}

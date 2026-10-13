"""SMTP com prazo curto, STARTTLS verificado e fallback manual do convite."""
import html
import logging
import smtplib
import ssl
from email.message import EmailMessage
from urllib.parse import quote
import config
from config import APP_BASE_URL, SMTP_CONFIG

logger = logging.getLogger(__name__)


def expor_codigos_dev():
    return bool(config.DEV_EXPOSE_AUTH_CODES)


def link_convite(token):
    # Estratégia hash padrão do Flutter Web, preservando subdiretórios.
    base = APP_BASE_URL.split("#", 1)[0].rstrip("/")
    return "%s/#/definir-senha?token=%s" % (base, quote(token, safe=""))


def _enviar(destinatario, assunto, corpo, corpo_html=None):
    if not SMTP_CONFIG["host"]:
        if expor_codigos_dev():
            print("[EMAIL - MODO DEV] Não enviado por SMTP.\n" + corpo)
            return True
        logger.warning("E-mail não enviado: MAIL_SERVER/SMTP_HOST ausente")
        return False
    if SMTP_CONFIG["host"] == "smtp.gmail.com" and not SMTP_CONFIG["password"]:
        logger.warning("E-mail não enviado: MAIL_PASSWORD ausente. Configure uma senha de app do Google.")
        return False
    mensagem = EmailMessage()
    mensagem["From"] = SMTP_CONFIG["remetente"]
    mensagem["To"] = destinatario
    mensagem["Subject"] = assunto
    mensagem.set_content(corpo)
    if corpo_html:
        mensagem.add_alternative(corpo_html, subtype="html")
    contexto = ssl.create_default_context()
    usar_ssl = SMTP_CONFIG.get("usar_ssl", False)
    cliente = smtplib.SMTP_SSL if usar_ssl else smtplib.SMTP
    argumentos = {"timeout": SMTP_CONFIG.get("timeout", 3)}
    if usar_ssl:
        argumentos["context"] = contexto
    etapa = "conexão"
    try:
        with cliente(SMTP_CONFIG["host"], SMTP_CONFIG["port"], **argumentos) as smtp:
            etapa = "EHLO"
            smtp.ehlo()
            if not usar_ssl and SMTP_CONFIG["usar_tls"]:
                etapa = "STARTTLS"
                smtp.starttls(context=contexto)
                etapa = "EHLO após TLS"
                smtp.ehlo()
            if SMTP_CONFIG["user"]:
                etapa = "autenticação"
                smtp.login(SMTP_CONFIG["user"], SMTP_CONFIG["password"])
            etapa = "envio"
            smtp.send_message(mensagem)
            etapa = "encerramento"
        return True
    except (smtplib.SMTPException, OSError) as erro:
        # Motivo real, sem credenciais, corpo ou link do convite.
        detalhe = str(erro)
        for segredo in (SMTP_CONFIG.get("password"), SMTP_CONFIG.get("user")):
            if segredo:
                detalhe = detalhe.replace(segredo, "[oculto]")
        logger.error("Falha SMTP servidor=%s porta=%s etapa=%s tipo=%s motivo=%s",
                     SMTP_CONFIG["host"], SMTP_CONFIG["port"], etapa, type(erro).__name__, detalhe)
        return False


def enviar_convite_professor(nome, email, token, nome_escola):
    link = link_convite(token)
    corpo = ("Olá, %s.\n\nA coordenação da %s convidou você para o Mentorly.\n"
             "Crie sua senha pelo link:\n%s\n\nO convite expira em %s horas e só pode ser usado uma vez.\n"
             "Se você não esperava este convite, ignore a mensagem.") % (
                 nome, nome_escola, link, config.CONVITE_EXPIRACAO_HORAS)
    corpo_html = (
        '<div style="font-family:Arial,sans-serif;color:#253746;max-width:560px">'
        '<h2>Seu acesso ao Mentorly</h2><p>Olá, %s.</p><p>A coordenação da %s convidou você.</p>'
        '<p><a href="%s" style="display:inline-block;padding:14px 20px;background:#405e73;color:white;'
        'text-decoration:none;border-radius:6px">Criar minha senha</a></p>'
        '<p>O convite expira em %s horas e só pode ser usado uma vez.</p>'
        '<p>Você também pode copiar este endereço:</p><p style="overflow-wrap:anywhere">%s</p></div>'
    ) % (html.escape(nome), html.escape(nome_escola), html.escape(link, quote=True),
         config.CONVITE_EXPIRACAO_HORAS, html.escape(link))
    return _enviar(email, "Seu acesso ao Mentorly", corpo, corpo_html)


def enviar_codigo_verificacao(email, codigo):
    return _enviar(email, "Código de verificação — Mentorly",
                   "Seu código de verificação é %s. Ele expira em alguns minutos. "
                   "Se você não pediu este código, ignore este e-mail." % codigo)

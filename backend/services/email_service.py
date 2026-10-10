"""Envio de email do convite do professor e do codigo de duas etapas.

Sem SMTP_HOST o email nao e enviado e o envio devolve False (a API responde
"enviado"/"conviteEnviado" = false). Quem libera expor o codigo/token na
resposta, ou imprimir o email no console, e SOMENTE o interruptor explicito
DEV_EXPOSE_AUTH_CODES (config.py): ausencia de SMTP nao e permissao.
"""

import logging
import smtplib
from email.message import EmailMessage

import config
from config import APP_BASE_URL, SMTP_CONFIG

logger = logging.getLogger(__name__)


def expor_codigos_dev():
    """True so quando DEV_EXPOSE_AUTH_CODES foi ligado de forma explicita.

    Lido de config a cada chamada (e nao copiado no import) para o valor
    refletir sempre a configuracao vigente.
    """
    return bool(config.DEV_EXPOSE_AUTH_CODES)


def _smtp_configurado():
    return bool(SMTP_CONFIG["host"])


def _enviar(destinatario, assunto, corpo):
    if not _smtp_configurado():
        if expor_codigos_dev():
            # Caixa de saida de desenvolvimento: o email vai para o console.
            print("\n" + "=" * 62)
            print("[EMAIL - MODO DEV] SMTP_HOST nao configurado, nada foi enviado.")
            print("Para: %s" % destinatario)
            print("Assunto: %s" % assunto)
            print("-" * 62)
            print(corpo)
            print("=" * 62 + "\n", flush=True)
            return True
        # Sem SMTP e sem modo dev: nada e enviado e o conteudo (que carrega
        # codigo ou token) nao vai para lugar nenhum, nem para o log.
        logger.warning(
            "SMTP_HOST nao configurado: email para %s nao foi enviado",
            destinatario,
        )
        return False

    mensagem = EmailMessage()
    mensagem["From"] = SMTP_CONFIG["remetente"]
    mensagem["To"] = destinatario
    mensagem["Subject"] = assunto
    mensagem.set_content(corpo)

    try:
        with smtplib.SMTP(SMTP_CONFIG["host"], SMTP_CONFIG["port"], timeout=15) as smtp:
            if SMTP_CONFIG["usar_tls"]:
                smtp.starttls()
            if SMTP_CONFIG["user"]:
                smtp.login(SMTP_CONFIG["user"], SMTP_CONFIG["password"])
            smtp.send_message(mensagem)
        return True
    except (smtplib.SMTPException, OSError) as erro:
        # Nao derruba a requisicao: o professor foi cadastrado mesmo que o
        # email falhe, e a coordenacao pode reenviar o convite depois.
        print("[EMAIL] Falha ao enviar para %s: %s" % (destinatario, erro))
        return False


def enviar_convite_professor(nome, email, token, nome_escola):
    """Convite para o professor criar a propria senha."""
    link = "%s/#/definir-senha?token=%s" % (APP_BASE_URL.rstrip("/"), token)
    corpo = (
        "Ola, %s.\n\n"
        "A coordenacao da %s cadastrou voce no Mentorly.\n"
        "Para criar sua senha e acessar suas turmas, use o link abaixo:\n\n"
        "%s\n\n"
        "Se o link nao abrir, informe este codigo na tela de primeiro acesso:\n"
        "%s\n"
    ) % (nome, nome_escola, link, token)
    return _enviar(email, "Seu acesso ao Mentorly", corpo)


def enviar_codigo_verificacao(email, codigo):
    """Codigo de 6 digitos da verificacao em duas etapas."""
    corpo = (
        "Seu codigo de verificacao do Mentorly e:\n\n"
        "    %s\n\n"
        "Ele expira em alguns minutos. Se voce nao pediu este codigo, "
        "ignore este email.\n"
    ) % codigo
    return _enviar(email, "Codigo de verificacao - Mentorly", corpo)

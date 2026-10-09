from auth.jwt_utils import gerar_codigo_verificacao
from models.codigo_model import CodigoVerificacao
from services import entrada
from services.email_service import enviar_codigo_verificacao, modo_dev


class EnviarCodigoService:
    """Gera e envia o codigo de verificacao em duas etapas."""

    def execute(self, email):
        email = entrada.texto(email, "O email", entrada.LIMITE_EMAIL).lower()
        if not email:
            raise ValueError("Informe o email")

        codigo = gerar_codigo_verificacao()
        CodigoVerificacao.criar(email, codigo)
        enviado = enviar_codigo_verificacao(email, codigo)

        resposta = {"enviado": enviado}
        if modo_dev():
            # Sem SMTP configurado nao ha como o usuario receber o codigo.
            # Devolver aqui mantem o fluxo testavel em desenvolvimento.
            resposta["modo"] = "dev"
            resposta["codigo"] = codigo
        return resposta


class ConfirmarCodigoService:
    def execute(self, email, codigo):
        email = entrada.texto(email, "O email", entrada.LIMITE_EMAIL).lower()
        codigo = entrada.texto(codigo, "O codigo", entrada.LIMITE_CODIGO)
        if not email or not codigo:
            raise ValueError("Informe o email e o codigo")
        return {"valido": CodigoVerificacao.validar(email, codigo)}

from auth.jwt_utils import gerar_codigo_verificacao
from models.codigo_model import CodigoVerificacao
from services import entrada
from services.email_service import enviar_codigo_verificacao, expor_codigos_dev


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
        if expor_codigos_dev():
            # So com DEV_EXPOSE_AUTH_CODES ligado (uso local): devolver o
            # codigo mantem o fluxo testavel sem email.
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

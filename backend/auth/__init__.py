"""Autenticacao por JWT e validacao de papel (coordenacao / professor)."""

from auth.decorators import (  # noqa: F401
    auth_required,
    coordenacao_atual,
    coordenacao_required,
    eh_professor,
    professor_required,
    usuario_atual_id,
)
from auth.jwt_utils import (  # noqa: F401
    TIPO_COORDENACAO,
    TIPO_PROFESSOR,
    gerar_codigo_verificacao,
    gerar_token,
    gerar_token_convite,
)

"""Limite de requisicoes sensiveis, em memoria e por processo (M-08).

Janela deslizante: guarda os instantes das ultimas requisicoes de cada chave e
recusa (429) a que passaria do limite dentro da janela. E a protecao simples do
MVP contra tentativa de senha/codigo em massa, spam de envio e consumo da cota
da IA; nao e uma solucao distribuida.

LIMITACOES (aceitas para o MVP):
  - o estado vive na memoria do processo: reiniciar o backend zera os
    contadores;
  - varias instancias/processos NAO compartilham limites (cada um conta o seu);
  - o IP e o remote_addr da conexao: atras de um proxy reverso todos parecem o
    mesmo IP ate que ele seja configurado para repassar o endereco real.

O QUE CONTA: toda requisicao que CHEGA ao fluxo protegido, ja identificada
(login/codigo: IP + identificador digitado; IA e convite: o usuario autenticado).
Tentativa invalida conta; falha de autenticacao do JWT acontece antes e nao
consome nada de ninguem. Uma requisicao recusada pelo limite nao e registrada
(nao estende o bloqueio) e nunca chega ao servico protegido: a IA nao e chamada.

Nao e desligado em modo debug: o desenvolvimento tambem deve notar abuso
acidental. Os testes usam reset() e relogio injetado.
"""

import math
import threading
import time
from collections import deque

JANELA_PADRAO = 15 * 60  # 15 minutos

# escopo -> (maximo de requisicoes, janela em segundos). Constantes simples:
# sem variavel de ambiente, para os padroes funcionarem em dev e na demo.
LIMITES = {
    # Login: IP + e-mail digitado.
    "login": (10, JANELA_PADRAO),
    # Confirmar codigo: o codigo tem so 6 digitos, limite mais apertado.
    "codigo_confirmar": (6, JANELA_PADRAO),
    # Pedir/reenviar codigo: evita spam de e-mail.
    "codigo_enviar": (5, JANELA_PADRAO),
    # Reenviar (ou renovar) convite de professor: por escola + professor.
    "convite_reenviar": (5, JANELA_PADRAO),
    # IA (9A, 9B, 9C e 9D COMPARTILHAM este limite): por Professor.
    "ia": (20, JANELA_PADRAO),
    # Teto da IA somando todos os professores do processo (protege a cota
    # global da Groq); alto o bastante para nao atrapalhar uma demonstracao.
    "ia_global": (100, JANELA_PADRAO),
}

MENSAGEM_PADRAO = "Muitas tentativas. Aguarde alguns minutos e tente novamente."
MENSAGEM_IA = (
    "Muitas solicitacoes de IA em pouco tempo. "
    "Aguarde alguns minutos e tente novamente."
)

# A limpeza oportunista roda quando o limiter e consultado, no maximo a cada
# INTERVALO_LIMPEZA segundos.
INTERVALO_LIMPEZA = 60


class LimiteExcedido(Exception):
    """Limite de requisicoes atingido (vira HTTP 429 com Retry-After)."""

    def __init__(self, mensagem, retry_after):
        super().__init__(mensagem)
        self.mensagem = mensagem
        self.retry_after = max(1, int(retry_after))


class RateLimiter:
    def __init__(self, relogio=time.monotonic):
        self._relogio = relogio
        self._trava = threading.Lock()
        # (escopo, chave) -> [deque de instantes, janela]
        self._janelas = {}
        self._ultima_limpeza = relogio()

    def consumir(self, escopo, chave, mensagem=MENSAGEM_PADRAO, limites=None):
        """Registra a requisicao ou levanta LimiteExcedido se passaria do limite.

        A consulta e o registro acontecem sob uma trava: requisicoes
        simultaneas nunca passam de `maximo` por janela.
        """
        maximo, janela = (limites or LIMITES)[escopo]
        with self._trava:
            agora = self._relogio()
            self._limpar_se_preciso(agora)
            instantes, _ = self._janelas.setdefault(
                (escopo, chave), [deque(), janela]
            )
            while instantes and instantes[0] <= agora - janela:
                instantes.popleft()
            if len(instantes) >= maximo:
                espera = math.ceil(instantes[0] + janela - agora)
                raise LimiteExcedido(mensagem, espera)
            instantes.append(agora)

    def reset(self):
        """Zera todos os contadores (testes; reiniciar o processo faz o mesmo)."""
        with self._trava:
            self._janelas.clear()
            self._ultima_limpeza = self._relogio()

    def total_de_chaves(self):
        with self._trava:
            return len(self._janelas)

    def _limpar_se_preciso(self, agora):
        """Descarta as chaves cuja ultima requisicao ja saiu da janela."""
        if agora - self._ultima_limpeza < INTERVALO_LIMPEZA:
            return
        self._ultima_limpeza = agora
        vencidas = [
            chave for chave, (instantes, janela) in self._janelas.items()
            if not instantes or instantes[-1] <= agora - janela
        ]
        for chave in vencidas:
            del self._janelas[chave]


# Instancia unica do processo.
limiter = RateLimiter()


def _normalizar(identificador):
    """E-mail/login normalizado para a chave; tipo estranho vira vazio."""
    if not isinstance(identificador, str):
        return ""
    return identificador.strip().lower()[:150]


def limitar_por_origem(escopo, ip, identificador):
    """Login e codigos: IP + identificador (nao so IP, nao so identificador)."""
    limiter.consumir(escopo, "%s|%s" % (ip or "?", _normalizar(identificador)))


def limitar_ia(professor_id):
    """Qualquer uma das quatro funcoes de IA: um unico limite por Professor,
    mais o teto global do processo."""
    limiter.consumir("ia", "professor:%s" % professor_id, MENSAGEM_IA)
    limiter.consumir("ia_global", "todos", MENSAGEM_IA)


def limitar_convite(coordenacao_id, professor_id):
    limiter.consumir("convite_reenviar", "%s|%s" % (coordenacao_id, professor_id))

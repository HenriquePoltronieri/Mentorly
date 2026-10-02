"""Migracoes idempotentes para bancos que ja existem.

O schema.sql usa CREATE TABLE IF NOT EXISTS, entao um banco ja criado nunca
recebe uma coluna nova - o arquivo passa batido. Este modulo cobre esse caso:
cada migracao olha o information_schema antes de agir, e roda tanto em base
nova (onde nao acha nada para fazer) quanto em base antiga.

Chamado por install_schema(), logo depois do schema.sql.
"""

from config import DB_CONFIG
from database.connection import execute, query_all, query_one

_BANCO = DB_CONFIG["database"]


# ---------------------------------------------------------------------
# Inspecao do catalogo
# ---------------------------------------------------------------------

def _coluna_existe(tabela, coluna):
    return query_one(
        "SELECT 1 FROM information_schema.columns "
        "WHERE table_schema = %s AND table_name = %s AND column_name = %s",
        (_BANCO, tabela, coluna),
    ) is not None


def _colunas_da_fk(tabela, constraint):
    """Colunas que formam a FK, na ordem. Vazio se a constraint nao existe.

    O alias precisa ser explicito: o MySQL devolve o nome da coluna do
    information_schema em maiusculo (COLUMN_NAME), e o DictCursor usa
    exatamente o que o servidor manda.
    """
    linhas = query_all(
        "SELECT column_name AS coluna FROM information_schema.key_column_usage "
        "WHERE table_schema = %s AND table_name = %s "
        "AND constraint_name = %s ORDER BY ordinal_position",
        (_BANCO, tabela, constraint),
    )
    return [linha["coluna"] for linha in linhas]


def _dropar_fk(tabela, constraint):
    if _colunas_da_fk(tabela, constraint):
        execute("ALTER TABLE %s DROP FOREIGN KEY %s" % (tabela, constraint))


def _dropar_indice(tabela, indice):
    existe = query_one(
        "SELECT 1 FROM information_schema.statistics "
        "WHERE table_schema = %s AND table_name = %s AND index_name = %s",
        (_BANCO, tabela, indice),
    )
    if existe:
        execute("ALTER TABLE %s DROP INDEX %s" % (tabela, indice))


# ---------------------------------------------------------------------
# Marco 1: atividade passa a carregar a escola
# ---------------------------------------------------------------------

def _atividade_ganha_coordenacao_id():
    """Adiciona atividade.coordenacao_id e troca as FKs simples por compostas.

    Sem isso, o MySQL aceitaria uma atividade da escola A apontando para a
    etapa da escola B: as FKs antigas eram REFERENCES etapa (id), sem passar
    pela coordenacao. Depois desta migracao o cruzamento e recusado pelo
    proprio banco, como ja acontece em professor_turma.

    A ordem importa: a coluna nasce NULL para o backfill caber, so depois
    vira NOT NULL. Fazer o contrario falha em qualquer tabela com linhas.
    """
    # Ja aplicada? A checagem e pelas colunas da FK, e nao so pela coluna
    # nova, para uma execucao interrompida no meio conseguir continuar.
    if _colunas_da_fk("atividade", "fk_atividade_etapa") == \
            ["coordenacao_id", "etapa_id"]:
        return False

    if not _coluna_existe("atividade", "coordenacao_id"):
        print("  [migracao] atividade.coordenacao_id")
        execute(
            "ALTER TABLE atividade ADD COLUMN coordenacao_id INT NULL AFTER id"
        )

    # Backfill: a escola da atividade e a escola da turma dela.
    execute(
        "UPDATE atividade a INNER JOIN turma t ON t.id = a.turma_id "
        "SET a.coordenacao_id = t.coordenacao_id "
        "WHERE a.coordenacao_id IS NULL"
    )

    # Base suja: atividade cuja etapa ou criterio e de outra escola. Sao
    # justamente as linhas que a FK nova vai barrar. Em vez de apagar a
    # atividade (dado do usuario), so soltamos o vinculo invalido - e por
    # isso que a coluna e NULL-avel.
    soltas = execute(
        "UPDATE atividade a LEFT JOIN etapa e "
        "  ON e.id = a.etapa_id AND e.coordenacao_id = a.coordenacao_id "
        "SET a.etapa_id = NULL "
        "WHERE a.etapa_id IS NOT NULL AND e.id IS NULL"
    )
    soltas += execute(
        "UPDATE atividade a LEFT JOIN criterio c "
        "  ON c.id = a.criterio_id AND c.coordenacao_id = a.coordenacao_id "
        "SET a.criterio_id = NULL "
        "WHERE a.criterio_id IS NOT NULL AND c.id IS NULL"
    )
    if soltas:
        print("  [migracao] %d vinculo(s) de etapa/criterio entre escolas "
              "diferentes foram desfeitos" % soltas)

    execute("ALTER TABLE atividade MODIFY coordenacao_id INT NOT NULL")

    # As FKs antigas seguram os indices antigos; dropar na ordem certa.
    for constraint in ("fk_atividade_turma", "fk_atividade_etapa",
                       "fk_atividade_criterio"):
        _dropar_fk("atividade", constraint)
    _dropar_indice("atividade", "idx_atividade_turma")
    _dropar_indice("atividade", "etapa_id")
    _dropar_indice("atividade", "criterio_id")

    execute(
        "ALTER TABLE atividade "
        "  ADD KEY idx_atividade_turma (coordenacao_id, turma_id), "
        "  ADD KEY idx_atividade_etapa (coordenacao_id, etapa_id), "
        "  ADD KEY idx_atividade_criterio (coordenacao_id, criterio_id), "
        "  ADD CONSTRAINT fk_atividade_turma "
        "      FOREIGN KEY (coordenacao_id, turma_id) "
        "      REFERENCES turma (coordenacao_id, id) "
        "      ON DELETE CASCADE ON UPDATE CASCADE, "
        "  ADD CONSTRAINT fk_atividade_etapa "
        "      FOREIGN KEY (coordenacao_id, etapa_id) "
        "      REFERENCES etapa (coordenacao_id, id) "
        "      ON DELETE RESTRICT ON UPDATE CASCADE, "
        "  ADD CONSTRAINT fk_atividade_criterio "
        "      FOREIGN KEY (coordenacao_id, criterio_id) "
        "      REFERENCES criterio (coordenacao_id, id) "
        "      ON DELETE RESTRICT ON UPDATE CASCADE"
    )
    print("  [migracao] FKs compostas de atividade instaladas")
    return True


# ---------------------------------------------------------------------
# Marco 3: fechamento de etapa
# ---------------------------------------------------------------------

def _etapa_ganha_fechada():
    """Adiciona etapa.fechada, para o schema.sql nao alcancar em banco antigo."""
    if _coluna_existe("etapa", "fechada"):
        return False
    print("  [migracao] etapa.fechada")
    execute(
        "ALTER TABLE etapa ADD COLUMN fechada TINYINT(1) NOT NULL DEFAULT 0 "
        "AFTER ativa"
    )
    return True


_MIGRACOES = (
    _atividade_ganha_coordenacao_id,
    _etapa_ganha_fechada,
)


def aplicar_migracoes():
    """Roda tudo que ainda falta. Devolve quantas migracoes agiram."""
    return sum(1 for migracao in _MIGRACOES if migracao())

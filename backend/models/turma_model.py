"""Model da Turma. SQL direto, sem ORM.

A tabela e `turma` (portugues), mas a API continua expondo /api/classes com
as chaves name/description porque as telas de coordenacao ja leem assim.
A traducao acontece no to_dict, nao no banco.

Nenhum metodo de listagem existe sem coordenacao_id: uma escola nunca ve
turma de outra.
"""

from database.connection import execute, insert, query_all, query_one
from models.utils import iso


# Colunas lidas em toda consulta de turma.
_COLUNAS = (
    "id, coordenacao_id, nome, descricao, disciplina, turno, ano_letivo, "
    "created_at, updated_at"
)


class Turma:
    TABELA = "turma"

    # -----------------------------------------------------------------
    # Leitura
    # -----------------------------------------------------------------
    @staticmethod
    def find_all_by_coordenacao(coordenacao_id):
        return query_all(
            "SELECT %s FROM turma WHERE coordenacao_id = %%s ORDER BY nome ASC"
            % _COLUNAS,
            (coordenacao_id,),
        )

    @staticmethod
    def find_by_id(turma_id, coordenacao_id):
        """Sempre exige a escola: turma de outra coordenacao vira None (404)."""
        return query_one(
            "SELECT %s FROM turma WHERE id = %%s AND coordenacao_id = %%s"
            % _COLUNAS,
            (turma_id, coordenacao_id),
        )

    @staticmethod
    def find_by_nome(nome, coordenacao_id):
        """Checagem de nome duplicado, restrita a escola."""
        return query_one(
            "SELECT %s FROM turma WHERE nome = %%s AND coordenacao_id = %%s"
            % _COLUNAS,
            (nome, coordenacao_id),
        )

    @staticmethod
    def find_by_id_para_professor(turma_id, professor_id):
        """Turma so e devolvida se a Coordenacao vinculou este professor a ela."""
        return query_one(
            "SELECT t.id, t.coordenacao_id, t.nome, t.descricao, t.disciplina, "
            "       t.turno, t.ano_letivo, t.created_at, t.updated_at "
            "FROM turma t "
            "INNER JOIN professor_turma pt ON pt.turma_id = t.id "
            "WHERE t.id = %s AND pt.professor_id = %s",
            (turma_id, professor_id),
        )

    @staticmethod
    def contar_alunos(turma_id):
        linha = query_one(
            "SELECT COUNT(*) AS total FROM aluno WHERE turma_id = %s", (turma_id,)
        )
        return linha["total"] if linha else 0

    # -----------------------------------------------------------------
    # Escrita
    # -----------------------------------------------------------------
    @staticmethod
    def create(coordenacao_id, nome, descricao=None, disciplina=None,
               turno=None, ano_letivo=None):
        return insert(
            "INSERT INTO turma "
            "(coordenacao_id, nome, descricao, disciplina, turno, ano_letivo) "
            "VALUES (%s, %s, %s, %s, %s, %s)",
            (coordenacao_id, nome, descricao, disciplina, turno, ano_letivo),
        )

    @staticmethod
    def update(turma_id, coordenacao_id, nome=None, descricao=None,
               disciplina=None, turno=None, ano_letivo=None):
        campos = []
        valores = []
        for coluna, valor in (
            ("nome", nome),
            ("descricao", descricao),
            ("disciplina", disciplina),
            ("turno", turno),
            ("ano_letivo", ano_letivo),
        ):
            if valor is not None:
                campos.append("%s = %%s" % coluna)
                valores.append(valor)
        if not campos:
            return 0
        valores.extend([turma_id, coordenacao_id])
        return execute(
            "UPDATE turma SET %s WHERE id = %%s AND coordenacao_id = %%s"
            % ", ".join(campos),
            tuple(valores),
        )

    @staticmethod
    def delete(turma_id, coordenacao_id):
        return execute(
            "DELETE FROM turma WHERE id = %s AND coordenacao_id = %s",
            (turma_id, coordenacao_id),
        )

    # -----------------------------------------------------------------
    # Serializacao
    # -----------------------------------------------------------------
    @staticmethod
    def to_dict(linha):
        """Devolve as chaves em ingles (name/description) que as telas atuais
        de coordenacao leem, e tambem as em portugues usadas pelas telas do
        professor. Manter as duas evita mexer em tela que ja funciona."""
        if not linha:
            return None
        return {
            "id": linha["id"],
            "name": linha["nome"],
            "nome": linha["nome"],
            "description": linha.get("descricao"),
            "descricao": linha.get("descricao"),
            "disciplina": linha.get("disciplina"),
            "turno": linha.get("turno"),
            "anoLetivo": linha.get("ano_letivo"),
            "totalAlunos": linha.get("total_alunos"),
            "created_at": iso(linha.get("created_at")),
            "updated_at": iso(linha.get("updated_at")),
        }

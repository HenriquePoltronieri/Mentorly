# Banco de Dados e Procedures

## Banco utilizado

O projeto usa **MySQL 8**. O acesso é feito em **SQL puro**, com o driver PyMySQL —
não há ORM. O schema fica versionado em `backend/database/schema.sql`, e as consultas
ficam escritas à mão nas Models e nos Repositories.

Quando o backend sobe com `python app.py`, ele cria o banco caso não exista, aplica o
`schema.sql` e instala as procedures do `backend/database/procedures.sql`. O mesmo pode
ser feito sem subir o Flask:

```bash
cd backend
python scripts/init_db.py
```

## A regra central do desenho: cada Coordenação é uma escola

Todo dado pedagógico pendura, direta ou indiretamente, em uma `coordenacao_id`. É isso
que impede uma escola de ver os dados da outra.

| Tabela | O que guarda | Como chega na escola |
|---|---|---|
| `coordenacao` | A escola em si (login da Coordenação) | é a raiz |
| `professor` | Professores da escola | `coordenacao_id` |
| `turma` | Turmas da escola | `coordenacao_id` |
| `professor_turma` | O vínculo que a Coordenação cria | `coordenacao_id` (FK composta) |
| `aluno` | Alunos de uma turma | `turma_id` → `turma.coordenacao_id` |
| `etapa` | Etapas do ano letivo (padrão da escola) | `coordenacao_id` |
| `criterio` | Critérios de avaliação de cada etapa | `coordenacao_id` + `etapa_id` |
| `atividade` | Atividades criadas pelo Professor | `turma_id` → `turma.coordenacao_id` |
| `nota` | Nota de um aluno em uma atividade | `atividade_id` / `aluno_id` |
| `codigo_verificacao` | Códigos da verificação em duas etapas | — |

### Por que `professor_turma` carrega `coordenacao_id`

Parece redundante, e é de propósito. As duas chaves estrangeiras da tabela são
**compostas** e passam pela escola:

```sql
FOREIGN KEY (coordenacao_id, turma_id)     REFERENCES turma (coordenacao_id, id)
FOREIGN KEY (coordenacao_id, professor_id) REFERENCES professor (coordenacao_id, id)
```

O efeito prático: vincular um professor da escola A a uma turma da escola B é recusado
pelo **próprio MySQL**, não só pela cláusula `WHERE` da query. O isolamento vira uma
invariante do banco — um bug no service não consegue misturar escolas. O script
`backend/scripts/smoke_db.py` prova isso, inclusive tentando forjar a `coordenacao_id`.

Isso exige os índices `UNIQUE (coordenacao_id, id)` em `turma` e `professor`, que
existem no schema só para servir de alvo dessas FKs.

## Autenticação

O login devolve um JWT (HS256) cujo payload carrega `{sub, tipo, coordenacao_id, exp}`.
**Toda consulta lê a escola desse token, nunca de um parâmetro enviado pelo cliente** —
não existe endpoint que aceite `coordenacao_id` na URL ou no corpo.

Os decorators ficam em `backend/auth/decorators.py`:

- `@auth_required` — qualquer usuário autenticado;
- `@coordenacao_required` — cadastro de turma/aluno, vínculo de professor, configuração
  do ano letivo;
- `@professor_required` — criar/editar/excluir atividade e lançar nota.

É `@professor_required` que garante, no backend, que a Coordenação **não** cria
atividade nem lança nota: um token de coordenação recebe 403 mesmo que a chamada seja
feita fora do app.

## CRUD simples e consultas especiais

**CRUD simples** (criar, listar, buscar por id, atualizar, excluir) fica na própria
Model, em `backend/models/`, com o SQL escrito à mão.

**Consultas especiais** — relatórios, contagens, buscas com filtro e ordenação — ficam
no Repository.

SQL e chamadas de procedure (`CALL`) não aparecem no Controller nem no Service. O `CALL`
fica em um único arquivo, `backend/database/procedure.py`, e só os Repositories o
chamam. A função valida o nome contra uma lista de procedures permitidas, já que o nome
da procedure não pode ir como placeholder.

## Procedures existentes

Todas recebem `p_coordenacao_id`: nenhuma enxerga o sistema inteiro.

| Procedure | O que faz | Usada por |
|---|---|---|
| `sp_relatorio_turmas_atividades(coordenacao_id)` | Turmas da escola com a contagem de atividades, da que tem mais para a que tem menos. LEFT JOIN + GROUP BY. | `TurmaRepository` |
| `sp_buscar_atividades(coordenacao_id, professor_id, termo, ordenar_por, direcao)` | Busca atividades por termo no título, com ordenação. `professor_id` nulo = visão da Coordenação; preenchido = só as turmas vinculadas àquele professor. | `ActivityRepository` |
| `sp_professores_por_coordenacao(coordenacao_id)` | Professores da escola, em ordem alfabética, com a contagem de turmas. Substitui a antiga `sp_usuarios_por_role`, que devolvia todos os professores do sistema sem filtro. | `ProfessorRepository` |
| `sp_resumo_sistema(coordenacao_id)` | Totais da escola: turmas, professores, atividades, alunos. Subconsultas agregadas. | `ReportRepository` |
| `sp_turmas_do_professor(professor_id)` | Turmas vinculadas ao professor, com a contagem de alunos. É a fonte de `GET /api/professor/turmas`. | `TurmaRepository` |
| `sp_alunos_em_risco(professor_id, ano_letivo)` | Alunos com média abaixo da `nota_minima` configurada pela Coordenação, só nas turmas do professor. | `ProfessorRepository` |

## Sobre o instalador de procedures

O `procedures.sql` usa `DROP PROCEDURE IF EXISTS` + `CREATE PROCEDURE`, em vez de
`CREATE PROCEDURE IF NOT EXISTS`. A diferença importa: a segunda forma só existe a
partir do MySQL 8.0.29, e além disso não atualizaria uma procedure já instalada.

O parser de `backend/database/connection.py` respeita a diretiva `DELIMITER $$`. A
versão anterior dividia o arquivo no texto `END;`, o que quebrava em qualquer procedure
que tivesse um `IF ... END IF` dentro — e as procedures atuais têm.

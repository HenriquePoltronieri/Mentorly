# Banco de Dados e Procedures

## Banco utilizado

O projeto usa **MySQL**. O acesso é feito com SQLAlchemy (a biblioteca
Flask-SQLAlchemy) e o driver PyMySQL.

Quando o backend sobe com `python app.py`, ele cria o banco caso não exista, cria as
tabelas e instala as procedures do arquivo `backend/database/procedures.sql`.

## Entidades atuais

São três tabelas:

| Tabela | Model | Campos principais |
|---|---|---|
| `users` | `User` | id, name, email, password_hash, role, created_at, updated_at |
| `classes` | `Class` | id, name, description, created_at, updated_at |
| `activities` | `Activity` | id, title, description, class_id, due_date, created_at, updated_at |

A tabela `activities` tem uma chave estrangeira `class_id` apontando para `classes`, ou
seja, toda atividade pertence a uma turma.

Vale explicar um detalhe de nome: no banco e no código do backend a turma se chama
`Class` (tabela `classes`), porque foi assim que a entidade nasceu. No aplicativo a gente
usa "turma" em português. A tradução dos nomes acontece no `fromJson`/`toJson` dos Models
em Dart, então o backend continua em inglês e a tela continua em português.

As funcionalidades desta entrega usam `classes` e `activities`. A tabela `users` existe e
tem CRUD pronto no backend, mas não tem tela ligada a ela nesta entrega.

## CRUD simples e consultas especiais

A gente separou o acesso ao banco em dois tipos:

**CRUD simples** é o básico de uma entidade: criar, listar todos, buscar por ID, atualizar
e excluir. Isso fica dentro da própria Model. Por exemplo, `Class.create`, `Class.find_all`
e `Class.delete` estão em `backend/models/class_model.py`.

**Consultas especiais** são as que não se resolvem com um CRUD comum: relatórios,
contagens, buscas com filtro e ordenação. Essas ficam no Repository.

Foi um dos pontos que o professor apontou: o Repository não deve repetir o que a Model já
faz. Hoje os Repositories do projeto têm poucos métodos, só o que realmente não é CRUD.

## Por que as procedures ficam no Repository

A regra da disciplina é que SQL e chamadas de procedure (`CALL`) não podem aparecer no
Controller nem no Service. O motivo é manter cada camada com uma responsabilidade: o
Controller cuida do HTTP, o Service cuida da regra de negócio, e quem conversa com o
banco é a Model ou o Repository.

No projeto, o `CALL` fica em um único arquivo, `backend/database/procedure.py`, que tem a
função `call_procedure`. Só os Repositories chamam essa função.

## Procedures existentes

O arquivo `backend/database/procedures.sql` tem quatro procedures:

| Procedure | O que faz | Usada por |
|---|---|---|
| `sp_relatorio_turmas_atividades` | Lista as turmas com a quantidade de atividades de cada uma, ordenando da que tem mais para a que tem menos. Usa LEFT JOIN e GROUP BY. | `TurmaRepository` (funcionalidade 10) |
| `sp_buscar_atividades` | Busca atividades cujo título contenha um termo, e ordena por título, data de entrega ou nome da turma, em ordem crescente ou decrescente. | `ActivityRepository` (funcionalidade 9) |
| `sp_usuarios_por_role` | Lista os usuários de um determinado papel (por exemplo, todos os professores), em ordem alfabética. | `UserRepository` |
| `sp_resumo_sistema` | Devolve totais gerais do sistema: quantas turmas, quantas atividades, quantos usuários e quantas turmas já têm atividade. | `ReportRepository` |

As duas primeiras são as que aparecem nas funcionalidades da entrega. As outras duas
existem no backend e têm endpoint, mas não têm tela ligada nesta entrega.

## Observação sobre a versão do MySQL

O `procedures.sql` usa `CREATE PROCEDURE IF NOT EXISTS`, que só existe a partir do
**MySQL 8.0.29**. Em versão mais antiga, ou no MariaDB, o arquivo dá erro na primeira
procedure.

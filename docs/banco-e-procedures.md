# Banco de Dados e Procedures

## Banco utilizado

O projeto usa **MySQL 8**. O acesso é feito em **SQL puro**, com o driver PyMySQL —
não há ORM. O schema fica versionado em `backend/database/schema.sql`, e as consultas
ficam escritas à mão nas Models e em `repositories/consultas.py`.

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
| `etapa` | Etapas do ano letivo (padrão da escola), com a flag `fechada` | `coordenacao_id` |
| `criterio` | Critérios de avaliação de cada etapa | `coordenacao_id` + `etapa_id` |
| `atividade` | Atividades criadas pelo Professor | `coordenacao_id` (FK composta) |
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

### O mesmo vale para `atividade`

`atividade` carrega `coordenacao_id` pela mesma razão, e com **três** FKs compostas:

```sql
FOREIGN KEY (coordenacao_id, turma_id)    REFERENCES turma (coordenacao_id, id)
FOREIGN KEY (coordenacao_id, etapa_id)    REFERENCES etapa (coordenacao_id, id)
FOREIGN KEY (coordenacao_id, criterio_id) REFERENCES criterio (coordenacao_id, id)
```

Antes disso as FKs eram simples (`REFERENCES etapa (id)`), e o banco aceitaria uma atividade
da escola A apontando para a etapa da escola B — bastava adulterar o `etapa_id` no corpo da
requisição. Agora o próprio MySQL recusa. Os índices-alvo `uk_etapa_escola` e
`uk_criterio_escola` existem no schema exatamente para isso.

**`etapa_id` e `criterio_id` continuam NULL-áveis**, por causa das atividades criadas antes
dessa regra. Em FK composta o MySQL não checa a constraint quando alguma coluna da chave é
NULL, então a linha antiga segue válida: nenhum dado precisou ser apagado. As atividades
**novas** exigem etapa, critério e valor — isso é validado no service, em
`backend/services/activity/validacao.py`.

`backend/scripts/smoke_db.py` prova os dois lados: recusa a atividade cruzada e aceita tanto
a legada (sem etapa) quanto a coerente.

## Autenticação

O login devolve um JWT (HS256) cujo payload carrega `{sub, tipo, coordenacao_id, exp}`.
**Toda consulta lê a escola desse token, nunca de um parâmetro enviado pelo cliente** —
não existe endpoint que aceite `coordenacao_id` na URL ou no corpo.

Os decorators ficam em `backend/auth/decorators.py`:

- `@auth_required` — qualquer usuário autenticado;
- `@coordenacao_required` — cadastro de turma/aluno, vínculo de professor, configuração
  do ano letivo, fechamento e reabertura de etapa;
- `@professor_required` — criar/editar/excluir atividade, lançar, importar e excluir nota.

É `@professor_required` que garante, no backend, que a Coordenação **não** cria
atividade nem lança nota: um token de coordenação recebe 403 mesmo que a chamada seja
feita fora do app.

## CRUD simples e consultas especiais

**CRUD simples** (criar, listar, buscar por id, atualizar, excluir) fica na própria
Model, em `backend/models/`, com o SQL escrito à mão.

**Consultas especiais** — relatórios, contagens, buscas com filtro e ordenação — ficam
no Repository, que hoje é um único arquivo, `backend/repositories/consultas.py`, com uma função
por consulta.

SQL e chamadas de procedure (`CALL`) não aparecem no Controller nem no Service. O `CALL`
fica em um único arquivo, `backend/database/procedure.py`, e só o
`repositories/consultas.py` o chama (fora dos scripts de teste). A função valida o nome contra uma lista de procedures permitidas, já que o nome
da procedure não pode ir como placeholder.

## Procedures existentes

Todas recebem `p_coordenacao_id`: nenhuma enxerga o sistema inteiro.

| Procedure | O que faz | Usada por |
|---|---|---|
| `sp_relatorio_turmas_atividades(coordenacao_id)` | Turmas da escola com a contagem de atividades, da que tem mais para a que tem menos. LEFT JOIN + GROUP BY. | `consultas.relatorio_turmas_atividades` |
| `sp_buscar_atividades(coordenacao_id, professor_id, termo, ordenar_por, direcao)` | Busca atividades por termo no título, com ordenação. `professor_id` nulo = visão da Coordenação; preenchido = só as turmas vinculadas àquele professor. | `consultas.buscar_atividades` |
| `sp_professores_por_coordenacao(coordenacao_id)` | Professores da escola, em ordem alfabética, com a contagem de turmas. Substitui a antiga `sp_usuarios_por_role`, que devolvia todos os professores do sistema sem filtro. | `consultas.professores_por_coordenacao` |
| `sp_resumo_sistema(coordenacao_id)` | Totais da escola: turmas, professores, atividades, alunos. Subconsultas agregadas. | `consultas.resumo_da_escola` |
| `sp_turmas_do_professor(professor_id)` | Turmas vinculadas ao professor, com a contagem de alunos. É a fonte de `GET /api/professor/turmas`. | `consultas.turmas_do_professor` |

`sp_alunos_em_risco` existiu até o Marco 2 e foi removida: ela fazia `AVG()` de
**todas** as notas do aluno, misturando etapas, contra a nota mínima fixa da etapa de
ordem 1 — sempre, mesmo quando o aluno já estava em outra etapa. "Aluno em risco" agora
é calculado em Python, em `services/professor/dashboard.py`, usando o motor central do
Marco 2 (ver abaixo) na etapa atual de verdade da escola.

## Marco 2 — o motor de cálculo acadêmico

`backend/services/academico/calculo.py` é a única fonte de verdade para desempenho de
aluno: nem o Flutter, nem nenhum outro service do backend calculam nota por conta
própria. Dashboard (`alunos em risco`) e a tela de estatísticas do aluno passam por lá.

A regra, por etapa: cada critério pondera `pontos_obtidos / pontos_possiveis` das
atividades **daquele critério que já têm nota lançada para o aluno** — uma atividade sem
nota não entra como zero, fica de fora do cálculo até ser avaliada. O critério só é
"completo" quando todas as atividades dele têm nota; a etapa só ganha `nota_calculada`
quando todos os critérios com peso maior que zero estão completos. Enquanto isso, a
situação é `"em_andamento"` — nunca um número inventado.

`criterio.peso` é um valor de 0 a 100 (pontos percentuais). Os pesos ativos de uma etapa
precisam somar 100 (tolerância 0,01) para ela poder ser calculada; se não somarem, a
situação vira `"configuracao_invalida"` com uma mensagem explicando o motivo, em vez de
calcular silenciosamente com uma configuração que a Coordenação nunca validou. `GET
/api/config/etapas` já devolve `pesoTotal`/`pesoValido` por etapa, para a tela de
configuração avisar antes mesmo de alguém tentar ver o desempenho de um aluno.

Arredondamento acontece uma vez só, na saída — o cálculo interno usa float cheio do
início ao fim, para não acumular erro de arredondamentos intermediários. A soma das
contribuições usa o valor **exato** de cada critério (`contribuicao_exata`); o campo
`contribuicao` devolvido por critério continua arredondado, só para exibição. Essa correção
(achado A02, Marco 4) evita casos de fronteira em que somar parcelas já arredondadas
(por exemplo 33,33% + 33,33%) fazia a nota final virar 33,34 em vez de 33,33 e mudava a situação
do aluno de `abaixo_do_minimo` para `adequado`.

## Marco 3 — fechamento de etapa, boletim e consolidado

**`etapa.fechada`.** A tabela `etapa` tem a coluna `fechada TINYINT(1) NOT NULL DEFAULT 0`. Ela
está no `schema.sql` e também em uma migração (`_etapa_ganha_fechada` em
`backend/database/migrations.py`), para chegar a bancos que já existiam. Só a Coordenação fecha ou
reabre uma etapa (`POST /api/config/etapas/<id>/fechar` e `/reabrir`).

**O que uma etapa fechada bloqueia.** Criar, editar e excluir atividade nessa etapa, e lançar,
importar e excluir nota nas atividades dela. O bloqueio vive nos Services
(`services/activity/validacao.py`, `update_activity.py`, `delete_activity.py` e
`services/professor/notas.py`, `planilha/importar_notas.py`), que consultam o estado da etapa
(`Etapa.esta_fechada` ou o campo `fechada`) antes de aceitar a escrita. A etapa só volta a aceitar alterações quando a Coordenação a reabre.

**Aviso de alunos incompletos (Marco 4).** Ao fechar, a resposta informa `alunosIncompletos`:
quantos alunos da escola ainda têm atividade sem nota naquela etapa. O fechamento não é impedido
por isso, porque a Coordenação pode ter motivo para fechar mesmo assim.

**Boletim.** `services/academico/boletim.py` monta o boletim de uma turma chamando o motor de
cálculo uma vez por aluno. Não recalcula nada por conta própria. Professor e Coordenação usam a
mesma função, por rotas diferentes (`/api/professor/turmas/<id>/boletim` e
`/api/coordenacao/turmas/<id>/boletim`).

**Consolidado.** `calcular_consolidado_geral` considera **somente etapas fechadas e completas**:
etapa aberta ou em andamento nunca entra, porque isso equivaleria a tratá-la como zero. Sem
nenhuma etapa fechada e completa, a situação é `em_andamento` e não há percentual. Com resultado,
o percentual é a média das etapas consideradas, e a situação é `abaixo_do_minimo` se qualquer uma
delas estiver abaixo do mínimo.

## Sobre o instalador de procedures

O `procedures.sql` usa `DROP PROCEDURE IF EXISTS` + `CREATE PROCEDURE`, em vez de
`CREATE PROCEDURE IF NOT EXISTS`. A diferença importa: a segunda forma só existe a
partir do MySQL 8.0.29, e além disso não atualizaria uma procedure já instalada.

O parser de `backend/database/connection.py` respeita a diretiva `DELIMITER $$`. A
versão anterior dividia o arquivo no texto `END;`, o que quebrava em qualquer procedure
que tivesse um `IF ... END IF` dentro — e as procedures atuais têm.

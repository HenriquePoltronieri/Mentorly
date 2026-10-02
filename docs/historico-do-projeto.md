# Histórico do Projeto

Um resumo de como o Mentorly evoluiu, da primeira entrega ao estado atual.

## Etapa inicial

O grupo começou pelo frontend, desenhando as telas de um sistema escolar mais completo:
coordenação, professores, alunos, notas, etapas do ano letivo, critérios de avaliação,
importação por planilha e login em duas etapas.

Nessa fase o backend ainda não existia. As telas foram feitas com os campos que a gente
imaginava que seriam necessários, e em vários arquivos ficaram comentários do tipo
`// IMPORTANTE PRO BACKEND: endpoint esperado -> ...`, indicando o que precisaria ser
criado depois.

## Primeira implementação do backend

> As seções desta fase (até "Correções realizadas") descrevem a primeira entrega, em turmas e
> atividades. Os nomes de arquivos e a organização citados nelas mudaram depois; ver
> "Do ORM ao SQL direto" e os Marcos mais abaixo.

Depois veio o backend em Flask. Foram criadas as três Models (`User`, `Class` e
`Activity`), os Controllers, os Services e os Repositories, e o projeto migrou do MySQL
puro para SQLAlchemy.

Nessa primeira versão a organização ainda não estava do jeito que a disciplina pedia:
os Repositories tinham o CRUD completo (create, update, delete, find_all, find_by_id),
os Controllers eram funções soltas com o Blueprint dentro deles, e cada entidade tinha um
único Service grande com todos os casos de uso juntos.

## Feedback do professor

Os pontos que recebemos foram:

1. A persistência básica deveria ficar concentrada nas Models, não nos Repositories.
2. Os Controllers deveriam ser classes e apenas receber a requisição e chamar o Service.
3. O `ClassRepository` deveria se chamar `TurmaRepository`.
4. CRUD simples não deveria ficar no Repository — lá só entram consultas especiais.
5. O Flutter deveria consumir a API através de uma camada de Service, e não chamar
   `http` direto nas telas.

## Correções realizadas

O que o grupo mudou a partir desses pontos:

- **CRUD passou para as Models.** `create`, `find_all`, `find_by_id`, `update` e `delete`
  hoje estão dentro de `user_model.py`, `class_model.py` e `activity_model.py`, e as três
  herdam de `db.Model`.
- **Repositories foram limpos.** Sobraram só as consultas que não são CRUD: busca por
  nome, busca por e-mail, atividades de uma turma e as chamadas de procedure.
- **Controllers viraram classes.** Os Blueprints saíram deles e foram para a pasta
  `backend/routes/`. Hoje o Controller só lê a requisição, chama o Service e devolve a
  resposta.
- **Services foram separados por caso de uso.** Os arquivos grandes (`user_service.py`,
  `class_service.py`, `activity_service.py`) foram divididos. Agora cada caso de uso tem
  a sua classe com um método `execute()`, organizados em pastas por entidade:
  `services/user/`, `services/class_/`, `services/activity/` e `services/dashboard/`.
  São 19 no total.
- **`ClassRepository` virou `TurmaRepository`.** O arquivo foi renomeado para
  `turma_repository.py` e os três imports que usavam a classe foram atualizados.
  Não renomeamos a Model `Class`, a rota `/api/classes`, a tabela `classes` nem as
  procedures, porque o pedido era só sobre o Repository.
- **Telas conectadas por Services Dart.** Criamos o `TurmasService` e ampliamos o
  `AtividadesService`. As seis telas da entrega deixaram de importar `package:http` e
  passaram a chamar esses Services, que usam o `ApiService`.
- **Contrato JSON alinhado.** As telas antigas esperavam campos que a API não tem
  (`nome`, `disciplina`, `turno`, `professorId`). Ajustamos os Models em Dart para ler o
  que a API realmente manda: `name` e `description` na turma, e `title`, `description`,
  `class_id` e `due_date` na atividade. A tradução para português ficou no
  `fromJson`/`toJson`.
- **Busca e relatório usam procedures.** As duas funcionalidades que não são CRUD passam
  pelo Repository, que chama `sp_buscar_atividades` e `sp_relatorio_turmas_atividades`.
- **CORS liberado no Flask.** Foi preciso para testar o aplicativo rodando no navegador,
  já que o Flutter Web e a API ficam em portas diferentes.

## Do ORM ao SQL direto

A migração para SQLAlchemy foi uma etapa transitória. No início de setembro de 2026 (commit de
03/09, "Estrutura domínio escolar"), o projeto passou a ter um domínio escolar de verdade
(Coordenação, Professor, Turma, Aluno, Etapa, Critério, Atividade e Nota) e o ORM foi
abandonado: o acesso ao banco voltou a ser SQL puro, com PyMySQL, escrito à mão nos Models e
organizado por `schema.sql`, `migrations.py` e `procedures.sql`. Os arquivos citados nas seções acima (`user_model.py`, `class_model.py`, `activity_model.py`,
`services/class_/` e os repositories antigos) descrevem aquela fase e não existem mais.

## Autenticação e isolamento entre escolas

Na mesma virada, o sistema ganhou login de verdade:

- cadastro e login da Coordenação, e convite por link para o Professor criar a própria senha;
- token JWT com `{sub, tipo, coordenacao_id, exp}`, validado por decorators de papel
  (`@coordenacao_required` e `@professor_required`);
- **cada Coordenação é uma escola independente**: o `coordenacao_id` vem sempre do token, nunca
  da requisição, e o banco reforça o isolamento com chaves estrangeiras compostas.

O atalho "Entrar no painel da coordenação", que existia só para chegar nas telas enquanto o login
não tinha backend, foi removido.

## Marcos 1 a 6

A partir daí o desenvolvimento passou a ser organizado por marcos, descritos em
[roadmap.md](roadmap.md):

| Marco | O que entregou |
|---|---|
| 1 — Avaliação | Atividade ligada a etapa e critério, com valor máximo; lançamento e importação de notas |
| 2 — Desempenho | Motor de cálculo único (`calculo.py`), média ponderada por etapa, nota ausente diferente de zero, alunos abaixo do mínimo |
| 3 — Ciclo escolar | Boletim da turma, consolidado, fechamento e reabertura de etapa, bloqueio de alterações em etapa fechada |
| 4 — Alunos e correções | Editar e excluir aluno; importação de notas sem ambiguidade por nome; `SECRET_KEY` sem valor padrão; correção do arredondamento intermediário; aviso de alunos incompletos no fechamento |
| 5 — Exclusão de nota | Excluir uma nota lançada, com confirmação e bloqueio em etapa fechada |
| 6 — Ano letivo | Cadastro de anos letivos por escola (`planejamento`, `atual`, `encerrado`), turma e etapa presas a um ano da escola por chave estrangeira, um único ano atual garantido pelo banco, migração dos dados existentes e fim do ano assumido pelo relógio no boletim, dashboard e etapa atual |

## Simplificação técnica

Antes do Marco 3, o grupo revisou o que havia de repasse sem regra e de código sem uso. O
resultado, descrito em [simplificacao-tecnica.md](simplificacao-tecnica.md), foi: cinco
consultas que apenas chamavam uma procedure passaram a viver em `repositories/consultas.py`; o
CRUD de turma, que eram cinco classes de um método, virou o módulo `services/turmas.py`; e foram
removidos arquivos Dart e Python sem nenhuma referência, entre eles o `GradeCalculator`, o
`AuthController` do Flutter e um service de IA que era só um placeholder. A regra de negócio, as
URLs e os status HTTP foram preservados.

## Estado atual

Os Marcos 1 a 6 estão concluídos e o projeto tem 20 funcionalidades demonstráveis, listadas em
[funcionalidades.md](funcionalidades.md). A verificação mais recente (02/10/2026):

- `py_compile`: 88 arquivos, OK;
- `smoke_db`: OK;
- `smoke_api`: 251 verificações, 0 falhas;
- `test_calculo`: 13 testes, OK;
- `test_migracao_ano_letivo`: 24 verificações, 0 falhas;
- `flutter analyze`: 0 warnings e 0 errors;
- `flutter test`: 13 testes, OK.

Faltam, para o MVP, a transferência de aluno com histórico, a gestão completa de professores e a
IA. O plano, com datas, está em [roadmap.md](roadmap.md).

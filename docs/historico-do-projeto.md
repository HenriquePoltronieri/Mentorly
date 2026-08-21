# Histórico do Projeto

Um resumo de como o Mentorly evoluiu até esta entrega.

## Etapa inicial

O grupo começou pelo frontend, desenhando as telas de um sistema escolar mais completo:
coordenação, professores, alunos, notas, etapas do ano letivo, critérios de avaliação,
importação por planilha e login em duas etapas.

Nessa fase o backend ainda não existia. As telas foram feitas com os campos que a gente
imaginava que seriam necessários, e em vários arquivos ficaram comentários do tipo
`// IMPORTANTE PRO BACKEND: endpoint esperado -> ...`, indicando o que precisaria ser
criado depois.

## Primeira implementação do backend

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

## Estado atual

A entrega são as 10 funcionalidades de turmas e atividades, descritas em
[funcionalidades.md](funcionalidades.md).

As 10 funcionalidades foram testadas pela interface do aplicativo. As de número 9 e 10
foram validadas com MySQL 8.4 e as Stored Procedures instaladas.

As demais áreas que estavam na ideia inicial (professores, alunos, notas, etapas,
critérios, planilha, login e IA) continuam sem backend e não fazem parte desta entrega.

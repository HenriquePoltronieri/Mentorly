# Arquitetura

A disciplina pediu que o projeto seguisse esta sequência de camadas:

```
Tela Flutter
  → Service Dart
  → ApiService
  → API Flask
  → Controller
  → Service
  → Model ou Repository
  → Banco de Dados
```

A regra principal é que cada camada faz uma coisa só e conversa apenas com a camada
seguinte.

## No Flutter

- **Tela** — é o que o usuário vê e usa. Ela cuida dos botões, campos e listas, mas não
  sabe qual é o endereço da API nem como montar uma requisição.
- **Service Dart** — é quem chama a API. No projeto temos dois: `TurmasService` e
  `AtividadesService`. Eles recebem os dados da tela e devolvem o resultado já pronto.
- **ApiService** — fica em `lib/core/services/apiService.dart` e concentra as requisições
  (`get`, `post`, `put`, `delete`) e o endereço da API. Assim, se o endereço mudar,
  a gente altera em um lugar só.

## No Flask

- **Route** — define o endereço do endpoint. Ficam em `backend/routes/`, usando Blueprint.
- **Controller** — é uma classe. Ele lê os dados que vieram na requisição, chama o Service
  e devolve a resposta com o código HTTP certo. Não acessa banco e não tem regra de negócio.
- **Service** — cada caso de uso tem a sua classe, com um método `execute()`. É onde ficam
  as validações e as regras.
- **Model** — representa a entidade e faz o CRUD simples: criar, listar, buscar por ID,
  atualizar e excluir. As Models herdam de `db.Model`.
- **Repository** — usamos só para as consultas que não são CRUD, como o relatório e a
  busca, que chamam Stored Procedures.
- **Banco** — MySQL, onde os dados ficam guardados.

---

## Exemplo 1 — Cadastrar Turma

Este é o caminho completo quando alguém cadastra uma turma pelo aplicativo:

```
adicionarTurmaModal.dart          (tela: formulário com nome e descrição)
  → TurmasService.cadastrarTurma  (lib/features/coordenacao/services/turmasService.dart)
  → ApiService.post('/classes')   (lib/core/services/apiService.dart)
  → POST /api/classes             (backend/routes/class_routes.py)
  → ClassController.create_class  (backend/controllers/class_controller.py)
  → CreateClassService.execute    (backend/services/class_/create_class.py)
  → Class.create                  (backend/models/class_model.py)
  → tabela classes no MySQL
```

Repare na divisão:

- o `ClassController` só pega `name` e `description` do corpo da requisição e repassa;
- o `CreateClassService` é quem valida: confere se o nome não está vazio e usa o
  `TurmaRepository.find_by_name` para ver se já não existe outra turma com aquele nome;
- quem realmente salva é a Model, no método `Class.create`.

## Exemplo 2 — Buscar Atividades

A busca não é um CRUD, então ela passa pelo Repository e usa uma Stored Procedure:

```
buscarAtividadesScreen.dart               (tela: campo de busca e ordenação)
  → AtividadesService.buscarAtividades    (lib/features/professor/services/atividadesService.dart)
  → ApiService.get('/activities/buscar')  (lib/core/services/apiService.dart)
  → GET /api/activities/buscar            (backend/routes/activity_routes.py)
  → ActivityController.buscar_atividades  (backend/controllers/activity_controller.py)
  → SearchActivitiesService.execute       (backend/services/activity/search_activities.py)
  → ActivityRepository.buscar_atividades  (backend/repositories/activity_repository.py)
  → call_procedure("sp_buscar_atividades")
  → MySQL
```

A diferença para o exemplo 1 é o final: em vez de chamar a Model, o Service chama o
Repository, que executa a procedure. O `CALL` fica só no arquivo
`backend/database/procedure.py`, que tem a função `call_procedure`. Nenhum Controller
ou Service escreve SQL.

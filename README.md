# Mentorly

## Sobre o Projeto

O Mentorly começou como uma ideia para ajudar a coordenação e os professores no
acompanhamento de turmas e atividades escolares.

No começo a gente pensou num sistema bem maior, que também trataria de professores,
alunos, notas, etapas do ano letivo e critérios de avaliação. Várias telas desse plano
inicial chegaram a ser feitas no Flutter antes de o backend correspondente existir, e
por isso elas ainda não conversam com a API.

Para esta entrega o grupo decidiu concentrar o trabalho em turmas e atividades, que são
as partes que já funcionam do início ao fim: da tela em Flutter, passando pela API em
Flask, até o banco de dados MySQL.

---

## Equipe de Desenvolvimento

- Bruno Guiero
- Henrique Poltronieri
- Luca Piovezan
- Lucas Santiago
- Roger Eduardo

---

## Tecnologias Utilizadas

### Backend
- Python 3
- Flask 3.0.3
- Flask-SQLAlchemy 3.1.1 (ORM)
- PyMySQL 1.1.1
- MySQL (com Stored Procedures)

### Frontend
- Flutter (SDK ^3.11.5)
- Dart

---

## Models Implementadas

### User (`/backend/models/user_model.py`)
| Campo | Tipo | Descrição |
|-------|------|-----------|
| id | Integer (PK) | Identificador único |
| name | String(120) | Nome do usuário |
| email | String(120) | Email (único) |
| password_hash | String(255) | Hash da senha |
| role | String(20) | Função (mentee, mentor, coordinator) |
| created_at | DateTime | Data de criação |
| updated_at | DateTime | Data de atualização |

### Class (`/backend/models/class_model.py`)
| Campo | Tipo | Descrição |
|-------|------|-----------|
| id | Integer (PK) | Identificador único |
| name | String(120) | Nome da turma |
| description | Text | Descrição (opcional) |
| created_at | DateTime | Data de criação |
| updated_at | DateTime | Data de atualização |

### Activity (`/backend/models/activity_model.py`)
| Campo | Tipo | Descrição |
|-------|------|-----------|
| id | Integer (PK) | Identificador único |
| title | String(200) | Título da atividade |
| description | Text | Descrição (opcional) |
| class_id | Integer (FK) | Referência à turma |
| due_date | DateTime | Data de entrega (opcional) |
| created_at | DateTime | Data de criação |
| updated_at | DateTime | Data de atualização |

---

## Repositories Utilizados

### UserRepository (`/backend/repositories/user_repository.py`)
- `find_by_email(email)` — busca usuário por email
- `usuarios_por_role(role)` — usuários filtrados por papel (procedure)

### TurmaRepository (`/backend/repositories/turma_repository.py`)
- `find_by_name(name)` — busca turma por nome
- `relatorio_turmas_atividades()` — relatório de turmas com contagem de atividades (procedure)

### ActivityRepository (`/backend/repositories/activity_repository.py`)
- `find_by_class_id(class_id)` — atividades de uma turma
- `buscar_atividades(termo, ordenar_por, direcao)` — busca de atividades com filtro e ordenação (procedure)

### ReportRepository (`/backend/repositories/report_repository.py`)
- `resumo_sistema()` — resumo geral do sistema (procedure)

---

## Procedures Criadas

As procedures estão definidas em `/backend/database/procedures.sql` e são instaladas automaticamente na inicialização do backend.

| Procedure | Descrição | Consultas Utilizadas |
|-----------|-----------|----------------------|
| `sp_relatorio_turmas_atividades` | Relatório de turmas com contagem de atividades | LEFT JOIN, GROUP BY, ORDER BY |
| `sp_buscar_atividades` | Busca de atividades por termo com ordenação | WHERE (LIKE), ORDER BY, LEFT JOIN |
| `sp_usuarios_por_role` | Usuários filtrados por papel | WHERE, ORDER BY |
| `sp_resumo_sistema` | Resumo geral do sistema (dashboard) | Subconsultas agregadas (COUNT) |

---

## Rotas Disponíveis

### Users (`/api/users`)

| Método | Rota | Descrição | Códigos HTTP |
|--------|------|-----------|-------------|
| POST | `/api/users` | Criar usuário | 201, 400, 409 |
| GET | `/api/users` | Listar todos | 200 |
| GET | `/api/users/role/:role` | Listar por papel (procedure) | 200 |
| GET | `/api/users/:id` | Buscar por ID | 200, 404 |
| PUT | `/api/users/:id` | Atualizar | 200, 400, 404 |
| DELETE | `/api/users/:id` | Excluir | 204, 404 |

### Classes (`/api/classes`)

| Método | Rota | Descrição | Códigos HTTP |
|--------|------|-----------|-------------|
| POST | `/api/classes` | Criar turma | 201, 400, 409 |
| GET | `/api/classes` | Listar todas | 200 |
| GET | `/api/classes/relatorio/atividades` | Relatório de turmas (procedure) | 200 |
| GET | `/api/classes/:id` | Buscar por ID | 200, 404 |
| PUT | `/api/classes/:id` | Atualizar | 200, 400, 404 |
| DELETE | `/api/classes/:id` | Excluir | 204, 404 |

### Activities (`/api/activities`)

| Método | Rota | Descrição | Códigos HTTP |
|--------|------|-----------|-------------|
| POST | `/api/activities` | Criar atividade | 201, 400, 409 |
| GET | `/api/activities` | Listar todas (filtro: `?class_id=`) | 200 |
| GET | `/api/activities/buscar` | Buscar atividades (procedure) | 200 |
| GET | `/api/activities/:id` | Buscar por ID | 200, 404 |
| PUT | `/api/activities/:id` | Atualizar | 200, 400, 404 |
| DELETE | `/api/activities/:id` | Excluir | 204, 404 |

### Dashboard (`/api/dashboard`)

| Método | Rota | Descrição | Códigos HTTP |
|--------|------|-----------|-------------|
| GET | `/api/dashboard/resumo` | Resumo geral do sistema (procedure) | 200 |

---

## Funcionalidades Implementadas

Estas são as 10 funcionalidades que entram nesta entrega. Todas funcionam do início ao
fim, ou seja, dá para usar pela tela do aplicativo e o dado realmente vai parar no banco.

| # | Funcionalidade | Tela | Endpoint |
|---|----------------|------|----------|
| 1 | Cadastrar Turma | Turmas → Adicionar turma | `POST /api/classes` |
| 2 | Listar Turmas | Turmas | `GET /api/classes` |
| 3 | Atualizar Turma | Turmas → ícone de editar | `PUT /api/classes/<id>` |
| 4 | Excluir Turma | Turmas → ícone de excluir | `DELETE /api/classes/<id>` |
| 5 | Cadastrar Atividade | Atividades da Turma → Adicionar atividade | `POST /api/activities` |
| 6 | Listar Atividades por Turma | Turmas → toque na turma | `GET /api/activities?class_id=<id>` |
| 7 | Atualizar Atividade | Atividades da Turma → ícone de editar | `PUT /api/activities/<id>` |
| 8 | Excluir Atividade | Atividades da Turma → ícone de excluir | `DELETE /api/activities/<id>` |
| 9 | Buscar Atividades | Buscar Atividades | `GET /api/activities/buscar` |
| 10 | Relatório de Turmas/Atividades | Relatório de Turmas | `GET /api/classes/relatorio/atividades` |

As funcionalidades 9 e 10 não são CRUD. Elas usam procedures do MySQL
(`sp_buscar_atividades` e `sp_relatorio_turmas_atividades`), então o filtro, a ordenação
e a contagem são feitos direto no banco.

**O que ficou de fora desta entrega:** as telas de professores, alunos, notas, etapas,
critérios de avaliação, login e importação por planilha. Elas existem no aplicativo
porque foram feitas na primeira parte do projeto, mas o backend delas não foi
desenvolvido, então ainda não funcionam. Como o login também não tem backend, na tela
inicial existe um atalho "Entrar no painel da coordenação" para conseguir chegar nas
telas de turmas e atividades.

---

## Arquitetura

```
Tela Flutter
  → Service Dart          (TurmasService, AtividadesService)
  → ApiService            (centraliza a URL da API)
  → API Flask             (Blueprints em routes/)
  → Controller            (classe, só HTTP)
  → Service               (1 caso de uso = 1 classe)
  → Model ou Repository
  → MySQL
```

A ideia é que cada camada tenha uma responsabilidade só:

- **Controller** — recebe a requisição, pega os dados que vieram, chama o Service e
  devolve a resposta. Ele não mexe no banco nem tem regra de negócio. Por exemplo,
  o `ClassController` lê o `name` e a `description` do corpo da requisição e repassa.
- **Service** — cada caso de uso tem a sua própria classe, com um método `execute()`.
  É onde ficam as validações. Por exemplo, o `CreateClassService` confere se o nome não
  está vazio e se já não existe outra turma com o mesmo nome antes de mandar salvar.
- **Model** — é onde fica o CRUD simples: criar, listar, buscar por ID, atualizar e
  excluir. As Models `User`, `Class` e `Activity` herdam de `db.Model`.
- **Repository** — usamos só para as consultas que não são CRUD, como o relatório e a
  busca, que chamam procedures. O `TurmaRepository`, por exemplo, tem só a busca por
  nome e a chamada da procedure do relatório.
- **No Flutter** as telas não chamam a API direto. Elas usam um Service em Dart
  (`TurmasService` e `AtividadesService`), que por sua vez usa o `ApiService`, onde fica
  o endereço da API.

---

## Estrutura do Projeto

```
backend/
├── controllers/
│   ├── __init__.py
│   ├── activity_controller.py
│   ├── class_controller.py
│   ├── dashboard_controller.py
│   └── user_controller.py
├── database/
│   ├── __init__.py
│   ├── connection.py
│   ├── procedure.py
│   └── procedures.sql
├── models/
│   ├── __init__.py
│   ├── activity_model.py
│   ├── class_model.py
│   └── user_model.py
├── repositories/
│   ├── __init__.py
│   ├── activity_repository.py
│   ├── report_repository.py
│   ├── turma_repository.py
│   └── user_repository.py
├── routes/
│   ├── __init__.py
│   ├── activity_routes.py
│   ├── class_routes.py
│   ├── dashboard_routes.py
│   └── user_routes.py
├── services/
│   ├── __init__.py
│   ├── activity/
│   │   ├── __init__.py
│   │   ├── create_activity.py
│   │   ├── delete_activity.py
│   │   ├── get_activities.py
│   │   ├── get_activity.py
│   │   ├── search_activities.py
│   │   └── update_activity.py
│   ├── class_/
│   │   ├── __init__.py
│   │   ├── create_class.py
│   │   ├── delete_class.py
│   │   ├── get_class.py
│   │   ├── get_class_report.py
│   │   ├── get_classes.py
│   │   └── update_class.py
│   ├── dashboard/
│   │   ├── __init__.py
│   │   └── get_system_summary.py
│   └── user/
│       ├── __init__.py
│       ├── create_user.py
│       ├── delete_user.py
│       ├── get_user.py
│       ├── get_users.py
│       ├── get_users_by_role.py
│       └── update_user.py
├── app.py
├── config.py
└── requirements.txt

docs/
├── arquitetura.md
├── banco-e-procedures.md
├── como-executar.md
├── funcionalidades.md
├── historico-do-projeto.md
├── roteiro-video.md
└── visao-geral.md

frontend/app_mentorly/
├── android/
├── ios/
├── lib/
│   ├── app/
│   │   ├── routes.dart
│   │   └── theme.dart
│   ├── core/
│   │   ├── services/
│   │   │   ├── apiService.dart
│   │   │   ├── authService.dart
│   │   │   └── planilhaService.dart
│   │   ├── utils/
│   │   │   ├── gradeCalculator.dart
│   │   │   └── validators.dart
│   │   └── widgets/
│   │       ├── customButton.dart
│   │       ├── customTextfield.dart
│   │       ├── loadingIndicator.dart
│   │       └── successModal.dart
│   ├── features/
│   │   ├── auth/
│   │   │   ├── controllers/
│   │   │   │   └── authController.dart
│   │   │   ├── models/
│   │   │   │   └── userModel.dart
│   │   │   └── screens/
│   │   │       ├── cadastroScreen.dart
│   │   │       ├── loginScreen.dart
│   │   │       ├── perfilSelectionScreen.dart
│   │   │       ├── professorLoginScreen.dart
│   │   │       └── twoFactorScreen.dart
│   │   ├── coordenacao/
│   │   │   ├── controllers/
│   │   │   │   ├── alunosController.dart
│   │   │   │   ├── configAnoLetivoController.dart
│   │   │   │   ├── professoresController.dart
│   │   │   │   └── turmasController.dart
│   │   │   ├── models/
│   │   │   │   ├── alunoModel.dart
│   │   │   │   ├── criterioAvaliacaoModel.dart
│   │   │   │   ├── escolaModel.dart
│   │   │   │   ├── etapaModel.dart
│   │   │   │   ├── professorModel.dart
│   │   │   │   └── turmaModel.dart
│   │   │   ├── screens/
│   │   │   │   ├── alunos/
│   │   │   │   │   ├── adicionarAlunosModal.dart
│   │   │   │   │   └── listaAlunosTurmaScreen.dart
│   │   │   │   ├── config/
│   │   │   │   │   ├── configCriteriosScreen.dart
│   │   │   │   │   ├── configEtapasScreen.dart
│   │   │   │   │   └── configNotasEtapaScreen.dart
│   │   │   │   ├── professores/
│   │   │   │   │   ├── cadastroProfessorScreen.dart
│   │   │   │   │   └── listaProfessoresScreen.dart
│   │   │   │   ├── relatorios/
│   │   │   │   │   └── relatorioTurmasScreen.dart
│   │   │   │   ├── turmas/
│   │   │   │   │   ├── adicionarTurmaModal.dart
│   │   │   │   │   ├── gerenciarTurmasScreen.dart
│   │   │   │   │   └── listaTurmasProfessorScreen.dart
│   │   │   │   └── coordenacaoHomeScreen.dart
│   │   │   ├── services/
│   │   │   │   ├── professoresService.dart
│   │   │   │   └── turmasService.dart
│   │   │   └── widgets/
│   │   │       ├── professorCard.dart
│   │   │       └── turmaCard.dart
│   │   └── professor/
│   │       ├── controllers/
│   │       │   ├── alunoDetailController.dart
│   │       │   ├── atividadesController.dart
│   │       │   ├── dashboardController.dart
│   │       │   └── turmasController.dart
│   │       ├── models/
│   │       │   ├── atividadeModel.dart
│   │       │   ├── estatisticaAlunoModel.dart
│   │       │   └── notaModel.dart
│   │       ├── screens/
│   │       │   ├── atividades/
│   │       │   │   ├── adicionarAtividadeModal.dart
│   │       │   │   ├── atividadeNotasScreen.dart
│   │       │   │   ├── buscarAtividadesScreen.dart
│   │       │   │   ├── lancarNotasModal.dart
│   │       │   │   ├── listaAtividadesScreen.dart
│   │       │   │   └── turmaAtividadesScreen.dart
│   │       │   ├── turmas/
│   │       │   │   ├── alunoDetailScreen.dart
│   │       │   │   ├── listaTurmasScreen.dart
│   │       │   │   └── turmaAlunosScreen.dart
│   │       │   └── dashboardScreen.dart
│   │       ├── services/
│   │       │   ├── atividadesService.dart
│   │       │   └── iaInsightsService.dart
│   │       └── widgets/
│   │           ├── alunoGraficoWidget.dart
│   │           └── professorTopBar.dart
│   └── main.dart
└── pubspec.yaml
```

---

## Como Executar Backend

```bash
# 1. Configurar o MySQL com o database mentorly

# 2. Instalar dependências
cd backend
pip install -r requirements.txt

# 3. Configurar variáveis de ambiente (opcional)
# DB_HOST=localhost DB_USER=root DB_PASSWORD= DB_NAME=mentorly

# 4. Executar (as procedures são instaladas automaticamente)
python app.py
```

O servidor será iniciado em `http://localhost:5000`.

---

## Como Executar Frontend

```bash
cd frontend/app_mentorly
flutter pub get
flutter run
```

Certifique-se de que o backend está rodando antes de iniciar o frontend.

O endereço da API fica em um único lugar: `lib/core/services/apiService.dart`.
Ajuste conforme onde o app for rodar:

| Onde roda | `baseUrl` |
|-----------|-----------|
| Chrome / Web / Windows | `http://localhost:5000/api` |
| Emulador Android | `http://10.0.2.2:5000/api` |

---

## Público-Alvo

- Coordenadores pedagógicos;
- Professores do Ensino Fundamental e Médio.

---

## Status do Projeto

Em desenvolvimento. Nesta entrega estão prontas as 10 funcionalidades de turmas e
atividades listadas acima. As outras partes que o grupo tinha planejado no início ainda
não foram implementadas no backend.

---

## Licença

Este projeto foi desenvolvido para fins acadêmicos na disciplina de Projeto de Software.

---

## Contato da Equipe

- Bruno Guiero
- Henrique Poltronieri
- Luca Piovezan
- Lucas Santiago
- Roger Eduardo

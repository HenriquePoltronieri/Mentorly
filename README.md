# Mentorly

## Sobre o Projeto

O Mentorly é uma plataforma desenvolvida para auxiliar a coordenação escolar e os professores no acompanhamento e gerenciamento de aulas, atividades e desempenho das turmas.

O sistema busca centralizar informações acadêmicas, facilitar a comunicação entre coordenação e professores e oferecer recursos inteligentes para apoiar a tomada de decisões pedagógicas.

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

### ClassRepository (`/backend/repositories/class_repository.py`)
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

### Backend (API REST)
- CRUD completo de Usuários
- CRUD completo de Turmas
- CRUD completo de Atividades
- Arquitetura em camadas (Model → Repository → Service → Controller → Routes)
- **Funcionalidades além do CRUD via Stored Procedures:**
  - Relatório de turmas com contagem de atividades (LEFT JOIN + GROUP BY + ORDER BY)
  - Busca de atividades por termo com ordenação (WHERE LIKE + ORDER BY)
  - Usuários filtrados por papel (WHERE + ORDER BY)
  - Resumo geral do sistema (subconsultas agregadas)
- Tratamento de erros com códigos HTTP apropriados
- Validação de entradas
- Services separados por caso de uso

### Frontend (Flutter)
- Tela inicial com navegação para cada entidade
- Tela de listagem com refresh e exclusão com confirmação
- Tela de cadastro com formulário validado
- Tela de edição com dados preenchidos
- Consumo da API REST
- **Telas de funcionalidades além do CRUD:**
  - Relatório de Turmas (coordenação) — contagem de atividades por turma
  - Busca de Atividades (professor) — filtro por termo e ordenação

---

## Estrutura do Projeto

```
backend/
├── app.py                      # Entry point, blueprint registration
├── config.py                   # Database configuration
├── controllers/                # HTTP request handling (Controllers finos)
│   ├── user_controller.py
│   ├── class_controller.py
│   ├── activity_controller.py
│   └── dashboard_controller.py
├── database/                   # Database connection
│   ├── __init__.py             # SQLAlchemy instance
│   ├── connection.py           # Database creation + procedure install
│   ├── procedure.py            # Helper para chamar procedures
│   └── procedures.sql          # Definição das stored procedures
├── models/                     # SQLAlchemy models (entidades + CRUD básico)
│   ├── user_model.py
│   ├── class_model.py
│   └── activity_model.py
├── repositories/               # Consultas avançadas (procedures)
│   ├── user_repository.py
│   ├── class_repository.py
│   ├── activity_repository.py
│   └── report_repository.py
├── services/                   # Business logic (per use case)
│   ├── user_service.py
│   ├── class_service.py
│   ├── activity_service.py
│   └── dashboard_service.py
├── routes/                     # Route definitions (Blueprints)
│   ├── user_routes.py
│   ├── class_routes.py
│   ├── activity_routes.py
│   └── dashboard_routes.py
└── requirements.txt

frontend/app_mentorly/
├── lib/
│   ├── main.dart               # App entry point
│   ├── app/
│   │   ├── routes.dart         # Rotas do app
│   │   └── theme.dart
│   ├── core/                   # Serviços e utilitários
│   ├── features/
│   │   ├── auth/               # Autenticação
│   │   ├── coordenacao/        # Telas da coordenação
│   │   │   └── screens/relatorios/relatorioTurmasScreen.dart
│   │   └── professor/          # Telas do professor
│   │       └── screens/atividades/buscarAtividadesScreen.dart
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

---

## Público-Alvo

- Coordenadores pedagógicos;
- Diretores escolares;
- Professores do Ensino Fundamental e Médio;
- Instituições de ensino que buscam otimizar seus processos pedagógicos.

---

## Status do Projeto

Em desenvolvimento

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
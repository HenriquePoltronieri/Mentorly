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
- MySQL

### Frontend
- Flutter (SDK ^3.11.5)
- Dart

---

## Models Implementadas

### User (`/backend/models/user.py`)
| Campo | Tipo | Descrição |
|-------|------|-----------|
| id | Integer (PK) | Identificador único |
| name | String(120) | Nome do usuário |
| email | String(120) | Email (único) |
| password_hash | String(255) | Hash da senha |
| role | String(20) | Função (mentee, mentor, coordinator) |
| created_at | DateTime | Data de criação |
| updated_at | DateTime | Data de atualização |

### Turma (`/backend/models/class.py`)
| Campo | Tipo | Descrição |
|-------|------|-----------|
| id | Integer (PK) | Identificador único |
| name | String(120) | Nome da turma |
| description | Text | Descrição (opcional) |
| created_at | DateTime | Data de criação |
| updated_at | DateTime | Data de atualização |

### Activity (`/backend/models/activity.py`)
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

## Rotas Disponíveis

### Users (`/users`)

| Método | Rota | Descrição | Códigos HTTP |
|--------|------|-----------|-------------|
| POST | `/users` | Criar usuário | 201, 400, 409 |
| GET | `/users` | Listar todos | 200 |
| GET | `/users/:id` | Buscar por ID | 200, 404 |
| PUT | `/users/:id` | Atualizar | 200, 400, 404 |
| DELETE | `/users/:id` | Excluir | 204, 404 |

### Classes (`/classes`)

| Método | Rota | Descrição | Códigos HTTP |
|--------|------|-----------|-------------|
| POST | `/classes` | Criar turma | 201, 400, 409 |
| GET | `/classes` | Listar todas | 200 |
| GET | `/classes/:id` | Buscar por ID | 200, 404 |
| PUT | `/classes/:id` | Atualizar | 200, 400, 404 |
| DELETE | `/classes/:id` | Excluir | 204, 404 |

### Activities (`/activities`)

| Método | Rota | Descrição | Códigos HTTP |
|--------|------|-----------|-------------|
| POST | `/activities` | Criar atividade | 201, 400, 409 |
| GET | `/activities` | Listar todas (filtro: `?class_id=`) | 200 |
| GET | `/activities/:id` | Buscar por ID | 200, 404 |
| PUT | `/activities/:id` | Atualizar | 200, 400, 404 |
| DELETE | `/activities/:id` | Excluir | 204, 404 |

---

## Funcionalidades Implementadas

### Backend (API REST)
- CRUD completo de Usuários
- CRUD completo de Turmas
- CRUD completo de Atividades
- Arquitetura em camadas (Model → Repository → Service → Controller → Routes)
- Tratamento de erros com códigos HTTP apropriados
- Validação de entradas
- Services separados por caso de uso

### Frontend (Flutter)
- Tela inicial com navegação para cada entidade
- Tela de listagem com refresh e exclusão com confirmação
- Tela de cadastro com formulário validado
- Tela de edição com dados preenchidos
- Consumo da API REST

---

## Estrutura do Projeto

```
backend/
├── app.py                      # Entry point, blueprint registration
├── config.py                   # Database configuration
├── controllers/                # HTTP request handling (Blueprints)
│   ├── user_controller.py
│   ├── class_controller.py
│   └── activity_controller.py
├── database/                   # Database connection
│   ├── __init__.py             # SQLAlchemy instance
│   └── connection.py           # Database creation
├── models/                     # SQLAlchemy models
│   ├── user.py
│   ├── class.py
│   └── activity.py
├── repositories/               # Data access layer
│   ├── user_repository.py
│   ├── class_repository.py
│   └── activity_repository.py
├── services/                   # Business logic (per use case)
│   ├── create_user_service.py
│   ├── list_users_service.py
│   ├── get_user_service.py
│   ├── update_user_service.py
│   ├── delete_user_service.py
│   ├── create_class_service.py
│   ├── list_classes_service.py
│   ├── get_class_service.py
│   ├── update_class_service.py
│   ├── delete_class_service.py
│   ├── create_activity_service.py
│   ├── list_activities_service.py
│   ├── get_activity_service.py
│   ├── update_activity_service.py
│   └── delete_activity_service.py
├── routes/                     # Route definitions (placeholder)
│   ├── users_routes.py
│   └── class_route.py
└── requirements.txt

frontend/app_mentorly/
├── lib/
│   ├── main.dart               # App entry point
│   ├── models/                 # Dart model classes
│   │   ├── user.dart
│   │   ├── turma.dart
│   │   └── activity.dart
│   ├── services/               # API service classes
│   │   ├── api_service.dart
│   │   ├── user_service.dart
│   │   ├── class_service.dart
│   │   └── activity_service.dart
│   └── pages/                  # UI pages
│       ├── home_page.dart
│       ├── users/
│       │   ├── user_list_page.dart
│       │   └── user_form_page.dart
│       ├── classes/
│       │   ├── class_list_page.dart
│       │   └── class_form_page.dart
│       └── activities/
│           ├── activity_list_page.dart
│           └── activity_form_page.dart
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

# 4. Executar
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

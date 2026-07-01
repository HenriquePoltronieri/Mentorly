# Atualização - CRUD Completo Backend

## Comparação: Requisito vs. Implementado

| Requisito | Status | Observação |
|-----------|--------|------------|
| Analisar modelagem existente e identificar entidades principais | ✅ | User, Turma, Activity |
| Criar/ajustar Models com ORM | ✅ | User (ajustado), Turma e Activity (criados) |
| Implementar Create / List All / Find by ID / Update / Delete | ✅ | CRUD completo nas 3 entidades |
| Criar Controllers (apenas HTTP) | ✅ | 3 controllers (user, class, activity) |
| Services separados por caso de uso | ✅ | 15 services (5 por entidade) |
| Rotas REST (POST, GET, GET/:id, PUT, DELETE) | ✅ | 15 rotas no total |
| Tratamento de erros adequado | ✅ | ValueError → 404/409, validação → 400 |
| Validar entradas dos usuários | ✅ | Campos obrigatórios, duplicatas, tipos |
| Códigos HTTP corretos (200, 201, 204, 400, 404, 500) | ✅ | 201 no create, 204 no delete, etc. |
| **Frontend** — Tela de listagem | ❌ | **Não feito** (outra equipe cuidando do Flutter) |
| **Frontend** — Tela de cadastro | ❌ | **Não feito** |
| **Frontend** — Tela de edição | ❌ | **Não feito** |
| **Frontend** — Exclusão com confirmação | ❌ | **Não feito** |
| README — Tecnologias utilizadas | ✅ | |
| README — Como executar Backend | ✅ | |
| README — Como executar Frontend | ✅ | |
| README — Models implementadas | ✅ | |
| README — Rotas disponíveis | ✅ | |
| README — Funcionalidades implementadas | ✅ | |
| Projeto compila sem erros | ✅ | Backend: Python syntax OK. Flutter: não alterado. |

---

## O que foi implementado

CRUD completo das principais Models do sistema seguindo arquitetura em camadas:
**Model → Repository → Service (por caso de uso) → Controller (Blueprint) → Flask**

---

## Models Implementadas

### User (`backend/models/user.py`)
- Já existia, adicionado campo `updated_at`

### Turma (`backend/models/turma.py`)
- Criado do zero (substitui `class.py` que estava vazio — renomeado para evitar conflito com palavra reservada `class` do Python)
- Campos: id, name, description, created_at, updated_at
- Relacionamento 1:N com Activity

### Activity (`backend/models/activity.py`)
- Criado do zero (estava vazio)
- Campos: id, title, description, class_id (FK → classes), due_date, created_at, updated_at

---

## Arquivos Modificados

| Arquivo | Alteração |
|---------|-----------|
| `backend/models/user.py` | Adicionado campo `updated_at` |
| `backend/models/__init__.py` | Importados `Turma` e `Activity` |
| `backend/repositories/user_repository.py` | Adicionados métodos `update` e `delete` |
| `backend/controllers/user_controller.py` | Refatorado para usar services separados por caso de uso; adicionados endpoints PUT e DELETE |
| `backend/controllers/class_controller.py` | Implementado Blueprint completo com CRUD (estava vazio) |
| `backend/app.py` | Registrados `class_blueprint` e `activity_blueprint` |
| `README.md` | Atualizado com modelos, rotas e instruções |

## Arquivos Criados

### Models
- `backend/models/turma.py`

### Repositories
- `backend/repositories/class_repository.py`
- `backend/repositories/activity_repository.py`

### Services (separados por caso de uso)
- `backend/services/create_user_service.py`
- `backend/services/list_users_service.py`
- `backend/services/get_user_service.py`
- `backend/services/update_user_service.py`
- `backend/services/delete_user_service.py`
- `backend/services/create_class_service.py`
- `backend/services/list_classes_service.py`
- `backend/services/get_class_service.py`
- `backend/services/update_class_service.py`
- `backend/services/delete_class_service.py`
- `backend/services/create_activity_service.py`
- `backend/services/list_activities_service.py`
- `backend/services/get_activity_service.py`
- `backend/services/update_activity_service.py`
- `backend/services/delete_activity_service.py`

### Controllers
- `backend/controllers/activity_controller.py`

## Arquivos Removidos
- `backend/models/class.py` (vazio; substituído por `turma.py`)

---

## Rotas Disponíveis

### Users (`/users`)
| Método | Rota | Descrição | HTTP |
|--------|------|-----------|------|
| POST | `/users` | Criar usuário | 201, 400, 409 |
| GET | `/users` | Listar todos | 200 |
| GET | `/users/:id` | Buscar por ID | 200, 404 |
| PUT | `/users/:id` | Atualizar | 200, 400, 404 |
| DELETE | `/users/:id` | Excluir | 204, 404 |

### Classes (`/classes`)
| Método | Rota | Descrição | HTTP |
|--------|------|-----------|------|
| POST | `/classes` | Criar turma | 201, 400, 409 |
| GET | `/classes` | Listar todas | 200 |
| GET | `/classes/:id` | Buscar por ID | 200, 404 |
| PUT | `/classes/:id` | Atualizar | 200, 400, 404 |
| DELETE | `/classes/:id` | Excluir | 204, 404 |

### Activities (`/activities`)
| Método | Rota | Descrição | HTTP |
|--------|------|-----------|------|
| POST | `/activities` | Criar atividade | 201, 400, 409 |
| GET | `/activities` | Listar todas (`?class_id=` opcional) | 200 |
| GET | `/activities/:id` | Buscar por ID | 200, 404 |
| PUT | `/activities/:id` | Atualizar | 200, 400, 404 |
| DELETE | `/activities/:id` | Excluir | 204, 404 |

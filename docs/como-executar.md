# Como Executar

## Backend

### O que precisa ter instalado

- Python 3
- MySQL (versão 8.0.29 ou mais nova, por causa das procedures)

### Dependências

Estão em `backend/requirements.txt`:

- Flask 3.0.3
- Flask-SQLAlchemy 3.1.1
- PyMySQL 1.1.1

Para instalar:

```bash
cd backend
pip install -r requirements.txt
```

### Variáveis de ambiente

São opcionais. Se você não definir nada, o projeto usa estes valores padrão
(em `backend/config.py`):

| Variável | Padrão |
|---|---|
| `DB_HOST` | `localhost` |
| `DB_PORT` | `3306` |
| `DB_USER` | `root` |
| `DB_PASSWORD` | vazio |
| `DB_NAME` | `mentorly` |

Se o seu MySQL tiver senha no usuário root, defina antes de rodar:

```bash
# Windows (PowerShell)
$env:DB_PASSWORD = "sua_senha"

# Linux / macOS
export DB_PASSWORD="sua_senha"
```

### Subir o Flask

Com o MySQL rodando:

```bash
cd backend
python app.py
```

O servidor sobe em `http://localhost:5000`.

Rodando dessa forma, o próprio `app.py` cria o banco caso não exista, cria as tabelas e
instala as procedures. **Isso só acontece com `python app.py`** — se você subir de outro
jeito, as procedures não são instaladas e a busca e o relatório dão erro.

Para conferir se subiu, abra `http://localhost:5000` no navegador. Deve aparecer:

```json
{"status": "ok", "service": "Mentorly API"}
```

---

## Frontend

Em qualquer caso, o backend precisa estar rodando antes.

```bash
cd frontend/app_mentorly
flutter pub get
```

O endereço da API fica em um lugar só: `lib/core/services/apiService.dart`, na constante
`baseUrl`. O valor muda conforme onde o aplicativo roda.

### Flutter Web (Chrome)

No navegador, o aplicativo roda na própria máquina, então o endereço é `localhost`:

```dart
static const String baseUrl = 'http://localhost:5000/api';
```

Depois:

```bash
flutter run -d chrome
```

### Emulador Android

O emulador do Android é uma máquina virtual separada. Dentro dele, `localhost` é o próprio
emulador, e não o seu computador. Para chegar na máquina que hospeda o emulador, o Android
usa o endereço especial `10.0.2.2`:

```dart
static const String baseUrl = 'http://10.0.2.2:5000/api';
```

Depois:

```bash
flutter run
```

Se esquecer de trocar esse valor, o aplicativo abre normalmente mas todas as telas mostram
"Não foi possível conectar ao servidor".

---

## Observação sobre as procedures

As funcionalidades **Buscar Atividades** e **Relatório de Turmas** usam Stored Procedures,
e procedure só existe no MySQL. Sem o MySQL rodando, essas duas telas retornam erro 500,
mesmo que o resto do aplicativo esteja funcionando.

As outras oito funcionalidades (o CRUD de turmas e de atividades) usam só o SQLAlchemy e
não dependem de procedure.

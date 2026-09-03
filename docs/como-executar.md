# Como Executar

## Backend

### O que precisa ter instalado

- Python 3
- MySQL 8

### Dependências

Estão em `backend/requirements.txt`:

- Flask 3.0.3
- PyMySQL 1.1.1
- PyJWT 2.9.0 (token de login)
- openpyxl 3.1.5 (importação de planilhas)
- Werkzeug 3.0.4 (hash de senha)

Para instalar:

```bash
cd backend
pip install -r requirements.txt
```

Não há ORM: o acesso ao banco é SQL puro com PyMySQL.

### Variáveis de ambiente

São opcionais. Sem definir nada, valem os padrões de `backend/config.py`:

| Variável | Padrão | Para que serve |
|---|---|---|
| `DB_HOST` | `localhost` | |
| `DB_PORT` | `3306` | |
| `DB_USER` | `root` | |
| `DB_PASSWORD` | vazio | |
| `DB_NAME` | `mentorly_db` | |
| `SECRET_KEY` | chave de desenvolvimento | assina o JWT do login |
| `SMTP_HOST` | vazio | servidor de e-mail |
| `APP_BASE_URL` | `http://localhost:3000` | monta o link do convite do professor |

Se o seu MySQL tiver senha no root:

```bash
# Windows (PowerShell)
$env:DB_PASSWORD = "sua_senha"

# Linux / macOS
export DB_PASSWORD="sua_senha"
```

**Em produção, `SECRET_KEY` precisa vir do ambiente.** Com o valor padrão, qualquer
pessoa consegue forjar um token de login.

### Criar o banco

Com o MySQL rodando:

```bash
cd backend
python scripts/init_db.py
```

Isso cria o banco `mentorly_db`, aplica o `database/schema.sql` (10 tabelas) e instala as
6 procedures. O `python app.py` faz o mesmo ao subir, então este passo é opcional — serve
para recriar o banco sem subir o Flask.

Para conferir que a conexão e o isolamento por escola estão de pé:

```bash
python scripts/smoke_db.py
```

### Subir o Flask

```bash
cd backend
python app.py
```

O servidor sobe em `http://localhost:5000`. Para conferir, abra no navegador:

```json
{"status": "ok", "service": "Mentorly API"}
```

### Testar a API inteira

```bash
cd backend
python scripts/smoke_api.py
```

São 53 verificações que cobrem login, isolamento entre duas escolas, permissões por
papel, configuração do ano letivo e importação de planilha. Ele limpa os próprios dados
ao terminar.

### E-mail em desenvolvimento

Sem `SMTP_HOST` configurado, o backend entra em **modo dev**: em vez de enviar, imprime
o convite e o código de verificação no console do Flask. A tela de cadastro de professor
também mostra o link do convite na própria tela, para dar para testar o primeiro acesso
localmente.

---

## Frontend

O backend precisa estar rodando antes.

```bash
cd frontend/app_mentorly
flutter pub get
```

O endereço da API fica em um lugar só: `lib/core/services/apiService.dart`, na constante
`baseUrl`.

### Flutter Web

No navegador o aplicativo roda na própria máquina, então o endereço é `localhost`:

```dart
static const String baseUrl = 'http://localhost:5000/api';
```

```bash
flutter run -d edge --web-port=3000
```

A porta 3000 importa: é ela que o `APP_BASE_URL` do backend usa para montar o link do
convite do professor.

### Emulador Android

O emulador é uma máquina virtual separada: dentro dele, `localhost` é o próprio
emulador. Para chegar na máquina que o hospeda, o Android usa `10.0.2.2`:

```dart
static const String baseUrl = 'http://10.0.2.2:5000/api';
```

```bash
flutter run
```

Esquecer de trocar esse valor faz o aplicativo abrir normalmente, mas todas as telas
mostram "Não foi possível conectar ao servidor".

---

## Primeiro uso

1. **Cadastre uma Coordenação** ("Não tem conta? Cadastre-se"). Cada cadastro é uma
   escola independente.
2. **Configurar Ano Letivo** — etapas, notas mínima/máxima e critérios. Fica salvo como
   padrão da escola; entrar de novo edita em vez de duplicar.
3. **Gerenciar Turmas** — crie a turma e toque nela para adicionar alunos (manualmente
   ou por planilha).
4. **Professores** — cadastre o professor. Sem SMTP configurado, copie o link do convite
   que aparece na tela.
5. **Vincular Professores** — escolha as turmas de cada professor. É só o que estiver
   vinculado aqui que ele vai enxergar.
6. Abra o link do convite, defina a senha, e o professor entra direto nas turmas dele.

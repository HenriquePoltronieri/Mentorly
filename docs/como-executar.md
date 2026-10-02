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

As variáveis de banco são opcionais: sem definir nada, valem os padrões de
`backend/config.py`. A `SECRET_KEY` também é opcional para testar localmente, mas tem um
comportamento próprio, descrito logo abaixo da tabela:

| Variável | Padrão | Para que serve |
|---|---|---|
| `DB_HOST` | `localhost` | |
| `DB_PORT` | `3306` | |
| `DB_USER` | `root` | |
| `DB_PASSWORD` | vazio | |
| `DB_NAME` | `mentorly_db` | |
| `SECRET_KEY` | sem padrão: uma chave aleatória é gerada a cada execução | assina o JWT do login |
| `SMTP_HOST` | vazio | servidor de e-mail |
| `APP_BASE_URL` | `http://localhost:3000` | monta o link do convite do professor |

Se o seu MySQL tiver senha no root, o jeito mais prático é criar um arquivo
`backend/.env` (ignorado pelo git) com uma variável por linha:

```
DB_PASSWORD=sua_senha
SECRET_KEY=uma_chave_longa_e_aleatoria
```

O `config.py` lê esse arquivo ao subir. Uma variável já definida no ambiente sempre
vence a do arquivo, então dá para sobrescrever pontualmente:

```bash
# Windows (PowerShell)
$env:DB_PASSWORD = "outra_senha"

# Linux / macOS
export DB_PASSWORD="outra_senha"
```

**`SECRET_KEY` não tem mais um valor padrão fixo no código.** Um valor conhecido permitiria
forjar um token de login. Sem `SECRET_KEY` no ambiente nem em `backend/.env`, o backend gera uma
chave aleatória para aquela execução e imprime um aviso no console. A chave é segura, mas muda a
cada reinicialização, então **todas as sessões (tokens JWT) expiram quando o servidor reinicia**.
Para uma sessão que sobreviva a reinicializações, e para qualquer uso real, defina `SECRET_KEY`.

### Criar o banco

Com o MySQL rodando:

```bash
cd backend
python scripts/init_db.py
```

Isso cria o banco `mentorly_db`, aplica o `database/schema.sql` (11 tabelas), roda as
migrações de `database/migrations.py` e instala as 5 procedures. O `python app.py` faz o
mesmo ao subir, então este passo é opcional — serve para recriar o banco sem subir o Flask.

As migrações existem porque o `schema.sql` só cria o que ainda não existe
(`CREATE TABLE IF NOT EXISTS`): num banco já criado, uma coluna nova nunca chegaria. Cada
migração consulta o `information_schema` antes de agir, então rodar de novo não faz nada.

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

### Testes

Todos os comandos abaixo partem da pasta `backend`:

```bash
python scripts/smoke_db.py       # conexão, isolamento entre escolas e procedures
python scripts/smoke_api.py      # a API de ponta a ponta
python scripts/test_calculo.py   # motor de cálculo acadêmico, sem banco
python scripts/test_migracao_ano_letivo.py   # migração do ano letivo, em banco temporário
```

- `smoke_db.py` prova que o banco recusa cruzar escolas (chaves estrangeiras compostas), recusa
  turma e etapa em ano que a escola não cadastrou, dois anos atuais e ano repetido, e que as
  procedures rodam com o filtro de escola.
- `smoke_api.py` percorre a API pelo cliente de teste do Flask (251 verificações). Cobre login e
  cadastro, rota protegida sem token, isolamento entre duas escolas, permissões por papel
  (a Coordenação não cria atividade nem lança nota), configuração do ano letivo, importação de
  planilha, avaliação acadêmica (etapa, critério, valor máximo e teto da nota), cálculo por etapa,
  boletim e fechamento de etapa, importação de nota sem ambiguidade, edição e exclusão de aluno,
  exclusão de nota e o ano letivo (cadastro, ano atual único, turma e etapa por ano, atividade só
  com etapa do mesmo ano, dashboard e boletim sem misturar anos). O ano dos testes é fixo (2026):
  nenhum teste depende do relógio da máquina.
- `test_calculo.py` usa `unittest` e não acessa o banco (13 testes): nota ausente diferente de
  zero, pesos, normalização, ausência de arredondamento intermediário, consolidado e a exigência
  de ano no motor.
- `test_migracao_ano_letivo.py` cria um banco temporário `<DB_NAME>_mig` no formato antigo (turma
  sem ano, anos soltos), roda a migração duas vezes e interrompida no meio, e confere que nada
  se perde (24 verificações). Apaga o banco no final.

Os scripts de smoke usam o banco indicado em `DB_NAME` e **limpam os dados que criam** ao
terminar. Para não tocar nos seus dados, aponte `DB_NAME` para um banco temporário:

```bash
# Windows (PowerShell)
$env:DB_NAME = "mentorly_teste"
python scripts/init_db.py
python scripts/smoke_api.py
```

No Flutter, a partir de `frontend/app_mentorly`:

```bash
flutter analyze   # 0 warnings e 0 errors; restam infos de estilo (file_names, withOpacity)
flutter test      # 13 testes: login e primeiro acesso, abertura do app e modelo de ano letivo
```

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
2. **Anos Letivos** — cadastre o ano (por exemplo, 2026) e marque-o como atual: turmas e etapas só
   existem dentro de um ano da escola. Depois, **Configurar Ano Letivo** — etapas, notas
   mínima/máxima e critérios do ano atual (para outro ano, use o menu do ano em Anos Letivos).
   Fica salvo como padrão da escola; entrar de novo edita em vez de duplicar.
3. **Gerenciar Turmas** — crie a turma e toque nela para adicionar alunos (manualmente
   ou por planilha).
4. **Professores** — cadastre o professor. Sem SMTP configurado, copie o link do convite
   que aparece na tela.
5. **Vincular Professores** — escolha as turmas de cada professor. É só o que estiver
   vinculado aqui que ele vai enxergar.
6. Abra o link do convite, defina a senha, e o professor entra direto nas turmas dele.

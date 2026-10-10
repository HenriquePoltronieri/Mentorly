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
- cryptography 50.0.1 (suporte do PyMySQL às senhas do MySQL 8)

Para instalar:

```bash
cd backend
pip install -r requirements.txt
```

Não há ORM: o acesso ao banco é SQL puro com PyMySQL.

### Variáveis de ambiente

Tudo vem de variáveis de ambiente, ou de `backend/.env` (ignorado pelo Git; use
`backend/.env.example` como modelo, que traz só nomes e padrões públicos). Uma variável já definida
no ambiente sempre vence a do arquivo. As variáveis de banco são opcionais: sem definir nada,
valem os padrões de `backend/config.py`.

| Variável | Padrão | Para que serve |
|---|---|---|
| `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME` | `localhost`, `3306`, `root`, vazio, `mentorly_db` | conexão com o MySQL |
| `SECRET_KEY` | sem padrão: uma chave aleatória é gerada a cada execução | assina o JWT do login |
| `TOKEN_EXPIRACAO_HORAS` | `12` | validade do token de login |
| `AI_BASE_URL` | `https://api.groq.com/openai/v1` | provedor de IA (Groq, compatível com chat completions) |
| `AI_API_KEY` | vazio | credencial do provedor; sem ela a IA fica indisponível e o resto do sistema funciona |
| `AI_MODEL` | `openai/gpt-oss-20b` | modelo da Groq |
| `AI_TIMEOUT` | `15` | limite da chamada de IA, em segundos |
| `FLASK_DEBUG` | `false` | liga o debug do Flask ao rodar `python app.py` (só desenvolvimento) |
| `DEV_EXPOSE_AUTH_CODES` | `false` | permite à API devolver o código de verificação e o token de convite e imprimir o e-mail no console (só desenvolvimento local) |
| `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASSWORD`, `SMTP_FROM`, `SMTP_TLS` | vazio, `587`, vazio, vazio, `nao-responda@mentorly.local`, `1` | envio de e-mail do convite e do código |
| `APP_BASE_URL` | `http://localhost:3000` | monta o link do convite do professor |

Exemplo de `backend/.env` para uso local (sem valores reais aqui):

```
DB_PASSWORD=sua_senha
SECRET_KEY=uma_chave_longa_e_aleatoria
AI_API_KEY=chave_da_groq
FLASK_DEBUG=true
DEV_EXPOSE_AUTH_CODES=true
```

`FLASK_DEBUG=true` e `DEV_EXPOSE_AUTH_CODES=true` são conveniências **locais**. Os padrões seguros
são `false` para os dois, e nada no código os liga sozinho.

**`SECRET_KEY` não tem valor padrão fixo no código.** Um valor conhecido permitiria forjar um
token de login. Sem `SECRET_KEY`, o backend gera uma chave aleatória para aquela execução e
avisa no console; a chave é segura, mas muda a cada reinicialização, então **todas as sessões
(tokens JWT) expiram quando o servidor reinicia**. Para uma sessão que sobreviva a reinicializações,
e para qualquer uso real, defina `SECRET_KEY`.

**SMTP ausente não é "modo dev".** Sem `SMTP_HOST`, o e-mail não é enviado e a API responde
`conviteEnviado: false` (ou `enviado: false` no código de verificação), sem expor código nem token. Só
`DEV_EXPOSE_AUTH_CODES=true` libera essa exposição, e é por isso que o padrão é `false`.

### Criar o banco

Com o MySQL rodando:

```bash
cd backend
python scripts/init_db.py
```

Isso cria o banco `mentorly_db`, aplica o `database/schema.sql` (12 tabelas), roda as
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

Todos os comandos abaixo partem da pasta `backend`. Nenhum chama a Groq nem envia e-mail (o
provedor e o SMTP são substituídos por dublês).

```bash
python scripts/smoke_db.py                      # conexão, isolamento entre escolas, ano letivo e procedures
python scripts/smoke_api.py                     # a API de ponta a ponta (944 verificações)
python scripts/test_calculo.py                  # motor de cálculo, sem banco (20 testes)
python scripts/test_config_dev.py               # padrões seguros de FLASK_DEBUG e DEV_EXPOSE_AUTH_CODES (12)
python scripts/test_rate_limit.py               # limite de requisições (15)
python scripts/test_erros_nao_encontrado.py     # 404 só para recurso inexistente; bug interno é 500 (12)
python scripts/test_ia.py                       # 9A: payload, autorização e cliente externo (22)
python scripts/test_ia_insights_privacidade.py  # 9A: nenhum dado identificável vai ao provedor (14)
python scripts/test_ia_atividade.py             # 9B (25)
python scripts/test_ia_correcao.py              # 9C (38)
python scripts/test_ia_feedback.py              # 9D (39)
python scripts/test_ia_erros_internos.py        # erro interno não vira erro de entrada (10)
python scripts/test_migracao_ano_letivo.py      # migração do ano letivo, em banco temporário (24 verificações)
python scripts/test_migracao_transferencia_aluno.py   # histórico de turma (8)
python scripts/test_migracao_professor_habilitado.py  # habilitado do professor (8)
```

- `smoke_db.py` prova que o banco recusa cruzar escolas (chaves estrangeiras compostas), recusa
  turma e etapa em ano que a escola não cadastrou, dois anos atuais e ano repetido, e que as
  procedures rodam com o filtro de escola.
- `smoke_api.py` percorre a API pelo cliente de teste do Flask. Cobre login e cadastro, isolamento
  entre escolas, permissões por papel, configuração do ano letivo, importação de planilha, cálculo
  por etapa, boletim e fechamento, edição e exclusão, transferência, gestão de professores, as
  quatro funções de IA (com o provedor simulado) e as regras de integridade e segurança da
  auditoria final (etapa fechada, ano encerrado, atividade com notas, exclusões com conflito,
  validação de entradas, token só no cabeçalho, limites de requisição, pseudonimização do 9A e
  separação entre 404 e erro interno). O ano dos testes é fixo (2026): nenhum teste depende do
  relógio da máquina.
- `test_migracao_ano_letivo.py` cria um banco temporário `<DB_NAME>_mig` no formato antigo,
  roda a migração duas vezes e interrompida no meio, e confere que nada se perde. Apaga o banco no
  final.

Os scripts de smoke usam o banco indicado em `DB_NAME` e **limpam os dados que criam** ao
terminar. Para não tocar nos seus dados, aponte `DB_NAME` para um banco temporário:

```bash
# Windows (PowerShell)
$env:DB_NAME = "mentorly_teste"
python scripts/init_db.py
python scripts/smoke_api.py
```

O `smoke_api.py` liga `DEV_EXPOSE_AUTH_CODES` por conta própria (ele precisa do convite e do
código na resposta) e sobe os limites de requisição nas seções antigas; os testes de limite e de
privacidade usam os valores reais.

No Flutter, a partir de `frontend/app_mentorly`:

```bash
flutter analyze   # 0 warnings e 0 errors; restam 101 infos de estilo (file_names, withOpacity)
flutter test      # 107 testes: login e sessão, IA (9A a 9D), exclusões, convites, limites, lista de atividades e modelos
```

### E-mail em desenvolvimento

Sem `SMTP_HOST`, o backend **não envia** e-mail e **não revela** o código de verificação nem o
token do convite: a API responde `enviado: false` / `conviteEnviado: false` e o aplicativo avisa
que o convite não saiu. Para testar o primeiro acesso do professor localmente, ligue
explicitamente `DEV_EXPOSE_AUTH_CODES=true` no `backend/.env`: então a tela de cadastro de professor
mostra o link do convite, a API devolve o código e o e-mail é impresso no console do Flask.
`DEV_EXPOSE_AUTH_CODES=false` é o padrão seguro e deve ser mantido fora do ambiente local.

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
4. **Professores** — cadastre o professor. Com SMTP configurado, o convite segue por e-mail; em
   desenvolvimento, com `DEV_EXPOSE_AUTH_CODES=true`, copie o link do convite que aparece na tela.
5. **Vincular Professores** — escolha as turmas de cada professor. É só o que estiver
   vinculado aqui que ele vai enxergar.
6. Abra o link do convite, defina a senha, e o professor entra direto nas turmas dele.

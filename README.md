# Mentorly

> Estado atual: **Marcos 1 a 7 concluídos**. O plano até a apresentação e o histórico das
> decisões estão em [docs/roadmap.md](docs/roadmap.md).

## Sobre o Projeto

O Mentorly é um sistema de acompanhamento acadêmico para escolas. A **Coordenação** configura
o ano letivo (etapas e critérios de avaliação), cadastra turmas, alunos e professores. Cada
**Professor** vê apenas as turmas que a Coordenação vinculou a ele, cria atividades, lança
notas e acompanha o desempenho dos alunos, com média por etapa, boletim e alunos em risco.

Cada cadastro de Coordenação é uma **escola independente**: nenhuma escola enxerga os dados de
outra, e essa regra é garantida também pelo próprio banco de dados (chaves estrangeiras
compostas).

O fluxo completo funciona do aplicativo Flutter, passando pela API Flask, até o MySQL.

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
- SQL direto via PyMySQL 1.1.1 (sem ORM)
- MySQL 8 (com Stored Procedures)
- PyJWT 2.9.0 (autenticação) e Werkzeug 3.0.4 (hash de senha)
- openpyxl 3.1.5 (importação de planilhas XLSX)

### Frontend
- Flutter 3 (Dart SDK `>=3.0.0 <4.0.0`)
- `http`, `shared_preferences`, `file_picker` e `url_launcher`

---

## Funcionalidades

São 21 funcionalidades demonstráveis, contadas de forma conservadora. A tabela completa, com
tela, endpoint e service de cada uma, está em [docs/funcionalidades.md](docs/funcionalidades.md).

**Coordenação**
1. Cadastro e login da Coordenação (cada cadastro é uma escola)
2. Anos letivos (atual, em planejamento ou encerrado) e etapas com nota mínima e máxima
3. Critérios de avaliação com pesos
4. Gerenciar turmas (cadastrar, listar, editar e excluir)
5. Cadastrar alunos manualmente
6. Importar alunos por planilha
7. Editar e excluir aluno
8. Transferir aluno entre turmas com histórico preservado
9. Gerenciar professores: cadastrar, editar, convidar, desativar e reativar
10. Visualizar, vincular e desvincular professores de turmas
11. Relatório de turmas e atividades
12. Desempenho acadêmico: boletim por turma e fechamento/reabertura de etapa

**Professor**
13. Primeiro acesso por convite e login
14. Criar, editar e excluir atividade (etapa, critério e valor máximo)
15. Listar e buscar atividades
16. Lançar notas
17. Importar notas por planilha
18. Excluir nota lançada
19. Dashboard com alunos em risco
20. Desempenho do aluno por etapa e consolidado
21. Boletim da turma

**Ainda não implementado:** IA. O planejamento está em [docs/roadmap.md](docs/roadmap.md).

---

## Arquitetura

```
FLUTTER
Tela
  → Controller / Service (Dart)
  → ApiService            (centraliza a URL da API e o token)

FLASK
Route                      (Blueprint + decorator de papel)
  → Controller             (classe, só HTTP)
  → Service                (regra de negócio e autorização)
  → Model / Repository     (SQL escrito à mão)
  → MySQL
```

- **Route** — declara o endereço e quem pode acessar (`@auth_required`,
  `@coordenacao_required`, `@professor_required`).
- **Controller** — lê a requisição, chama o Service e devolve o código HTTP. Não tem regra
  acadêmica.
- **Service** — validações, autorização por escola/turma e regras de negócio. Cada caso de
  uso tem a sua classe com um método `execute()`. O cálculo acadêmico fica em
  `services/academico/calculo.py` e o boletim em `services/academico/boletim.py`.
- **Model** — SQL de uma entidade (CRUD e consultas simples), com PyMySQL.
- **Repository** — apenas `repositories/consultas.py`, para as consultas que chamam
  Stored Procedures.
- **Autenticação** — JWT com `{sub, tipo, coordenacao_id, exp}`. A escola sempre é lida do
  token, nunca de um parâmetro da requisição.

A separação não é absolutamente rígida: existem poucos acessos diretos Controller → Model e
Controller → Repository, e alguns modais Flutter usam o `ApiService` diretamente. Eles estão
descritos em [docs/architecture.md](docs/architecture.md).

---

## Models

Todas ficam em `backend/models/` e fazem SQL direto, sem ORM.

| Model | Tabela | O que representa |
|---|---|---|
| `Coordenacao` | `coordenacao` | A escola e o login da Coordenação |
| `Professor` | `professor` | Professor da escola, com convite e estado administrativo `habilitado` |
| `AnoLetivo` | `ano_letivo` | Ano letivo da escola, com status `planejamento`, `atual` ou `encerrado` |
| `Turma` | `turma` | Turma da escola, em um ano letivo da própria escola |
| `ProfessorTurma` | `professor_turma` | Vínculo criado pela Coordenação |
| `Aluno` | `aluno` | Aluno de uma turma |
| `AlunoTurmaHistorico` | `aluno_turma_historico` | Vínculos atuais e anteriores do aluno com turma e ano letivo |
| `Etapa` | `etapa` | Etapa de um ano letivo, com nota mínima/máxima e `fechada` |
| `Criterio` | `criterio` | Critério de avaliação de uma etapa, com peso |
| `Atividade` | `atividade` | Atividade ligada a turma, etapa e critério |
| `Nota` | `nota` | Nota de um aluno em uma atividade |
| `CodigoVerificacao` | `codigo_verificacao` | Códigos da verificação em duas etapas |

---

## Repository e Procedures

`backend/repositories/consultas.py` reúne as consultas que chamam procedures. As procedures
estão em `backend/database/procedures.sql` e são instaladas automaticamente na inicialização.
Todas recebem o id da escola (ou do professor), nunca o sistema inteiro.

| Procedure | Descrição | Consultas utilizadas |
|---|---|---|
| `sp_relatorio_turmas_atividades` | Turmas da escola com contagem de atividades | LEFT JOIN, GROUP BY, ORDER BY |
| `sp_buscar_atividades` | Busca de atividades por termo, com ordenação | WHERE (LIKE), ORDER BY, LEFT JOIN |
| `sp_professores_por_coordenacao` | Professores da escola com contagem de turmas | LEFT JOIN, GROUP BY |
| `sp_resumo_sistema` | Totais da escola | Subconsultas agregadas (COUNT) |
| `sp_turmas_do_professor` | Turmas vinculadas a um professor, com contagem de alunos | JOIN, subconsulta |

---

## Rotas Disponíveis

`Auth` indica quem pode chamar: **Qualquer** (`@auth_required`), **Coord.**
(`@coordenacao_required`) ou **Prof.** (`@professor_required`). Rotas de Coordenação e de
Professor sem token ou com o papel errado respondem 401/403.

### Autenticação (`/api/auth`)

| Método | Rota | Descrição |
|---|---|---|
| POST | `/api/auth/cadastro-coordenacao` | Cadastrar escola/Coordenação |
| POST | `/api/auth/login-coordenacao` | Login da Coordenação |
| POST | `/api/auth/login-professor` | Login do Professor |
| POST | `/api/auth/criar-senha-professor` | Primeiro acesso, com o token do convite |
| POST | `/api/auth/enviar-codigo` | Código de verificação em duas etapas |
| POST | `/api/auth/confirmar-codigo` | Confirmar o código |

### Turmas (`/api/classes`)

| Método | Rota | Auth | Descrição |
|---|---|---|---|
| GET | `/api/classes` | Qualquer | Listar (Professor vê só as dele); `?ano_letivo=` filtra pelo ano |
| GET | `/api/classes/<id>` | Qualquer | Buscar por ID |
| GET | `/api/classes/relatorio/atividades` | Coord. | Relatório de turmas (procedure) |
| POST | `/api/classes` | Coord. | Criar turma |
| PUT | `/api/classes/<id>` | Coord. | Atualizar |
| DELETE | `/api/classes/<id>` | Coord. | Excluir |

### Atividades (`/api/activities`)

| Método | Rota | Auth | Descrição |
|---|---|---|---|
| GET | `/api/activities` | Qualquer | Listar (filtro `?class_id=`) |
| GET | `/api/activities/buscar` | Qualquer | Buscar por termo (procedure) |
| GET | `/api/activities/<id>` | Qualquer | Buscar por ID |
| POST | `/api/activities` | Prof. | Criar |
| PUT | `/api/activities/<id>` | Prof. | Atualizar |
| DELETE | `/api/activities/<id>` | Prof. | Excluir |

### Configuração do ano letivo (`/api/config`)

| Método | Rota | Auth | Descrição |
|---|---|---|---|
| GET | `/api/config/anos-letivos` | Coord. | Listar os anos da escola, com totais de turmas e etapas |
| POST | `/api/config/anos-letivos` | Coord. | Cadastrar ano (nasce em planejamento) |
| PUT | `/api/config/anos-letivos/<id>` | Coord. | Mudar o status (`encerrar_atual` confirma a troca do ano atual) |
| DELETE | `/api/config/anos-letivos/<id>` | Coord. | Excluir ano sem turma nem etapa |
| GET | `/api/config/etapas` | Qualquer | Listar etapas |
| GET | `/api/config/etapas/<id>` | Qualquer | Buscar etapa |
| POST | `/api/config/etapas` | Coord. | Criar/atualizar etapa |
| PUT | `/api/config/etapas/<id>` | Coord. | Atualizar etapa |
| POST | `/api/config/etapas/<id>/notas` | Coord. | Definir nota mínima e máxima |
| POST | `/api/config/etapas/<id>/fechar` | Coord. | Fechar etapa |
| POST | `/api/config/etapas/<id>/reabrir` | Coord. | Reabrir etapa |
| DELETE | `/api/config/etapas/<id>` | Coord. | Excluir etapa |
| GET | `/api/config/criterios/etapa/<etapa_id>` | Qualquer | Listar critérios |
| GET | `/api/config/criterios/<id>` | Qualquer | Buscar critério |
| POST | `/api/config/criterios/etapa/<etapa_id>` | Coord. | Criar critério |
| PUT | `/api/config/criterios/<id>` | Coord. | Atualizar critério |
| DELETE | `/api/config/criterios/<id>` | Coord. | Excluir critério |

### Coordenação (`/api/coordenacao`)

| Método | Rota | Descrição |
|---|---|---|
| GET / POST | `/api/coordenacao/professores` | Listar / cadastrar professor (com convite) |
| PUT | `/api/coordenacao/professores/<id>` | Editar professor |
| POST | `/api/coordenacao/professores/<id>/desativar`, `/reativar`, `/reenviar-convite` | Administrar acesso e convite pendente |
| GET / POST | `/api/coordenacao/professores/<id>/turmas` | Ver / definir turmas do professor |
| DELETE | `/api/coordenacao/professores/<id>/turmas/<turma_id>` | Desvincular turma, preservando dados acadêmicos |
| GET / POST | `/api/coordenacao/turmas/<id>/alunos` | Listar / cadastrar alunos da turma |
| PUT / DELETE | `/api/coordenacao/alunos/<id>` | Editar / excluir aluno |
| GET | `/api/coordenacao/turmas/<id>/alunos/modelo-planilha` | Baixar modelo de planilha |
| POST | `/api/coordenacao/turmas/<id>/alunos/importar` | Importar alunos por planilha |
| GET | `/api/coordenacao/turmas/<id>/boletim` | Boletim da turma |

### Professor (`/api/professor` e `/api/atividades`)

| Método | Rota | Descrição |
|---|---|---|
| GET | `/api/professor/turmas` | Turmas vinculadas ao professor |
| GET / POST | `/api/professor/turmas/<id>/alunos` | Listar / cadastrar alunos |
| GET | `/api/professor/turmas/<id>/alunos/modelo-planilha` | Modelo de planilha de alunos |
| POST | `/api/professor/turmas/<id>/alunos/importar` | Importar alunos por planilha |
| GET | `/api/professor/turmas/<id>/boletim` | Boletim da turma |
| GET | `/api/professor/dashboard` | Dashboard (alunos em risco) |
| GET | `/api/professor/alunos/<id>/estatisticas` | Desempenho do aluno por etapa |
| PUT / DELETE | `/api/professor/alunos/<id>` | Editar / excluir aluno |
| DELETE | `/api/professor/notas/<id>` | Excluir nota lançada |
| GET / POST | `/api/atividades/<id>/notas` | Listar / lançar notas |
| GET | `/api/atividades/<id>/notas/modelo-planilha` | Modelo de planilha de notas |
| POST | `/api/atividades/<id>/notas/importar` | Importar notas por planilha |

### Dashboard da escola (`/api/dashboard`)

| Método | Rota | Auth | Descrição |
|---|---|---|---|
| GET | `/api/dashboard/resumo` | Coord. | Totais da escola (procedure) |

---

## Estrutura do Projeto

```
backend/
├── app.py                      # cria o Flask, registra as rotas e instala schema/procedures
├── config.py                   # variáveis de ambiente e backend/.env
├── requirements.txt
├── auth/                       # JWT e decorators de papel
├── routes/                     # Blueprints (activity, auth, class, config, coordenacao,
│                               #             dashboard, professor)
├── controllers/                # uma classe por área, só HTTP
├── services/
│   ├── academico/              # calculo.py (motor) e boletim.py
│   ├── activity/               # criar, listar, buscar, atualizar e excluir atividade
│   ├── aluno/                  # cadastrar, listar, editar e excluir aluno
│   ├── auth/                   # cadastro, logins, convite e verificação em duas etapas
│   ├── config/                 # anos letivos, etapas e critérios
│   ├── coordenacao/            # professores e vínculos
│   ├── planilha/               # leitura, validação e importação de XLSX
│   ├── professor/              # turmas, dashboard, estatísticas e notas
│   ├── turmas.py               # CRUD de turma (funções)
│   └── email_service.py
├── models/                     # SQL de cada entidade
├── repositories/consultas.py   # consultas que chamam procedures
├── database/
│   ├── connection.py           # conexão, transações e instalador
│   ├── migrations.py           # colunas novas em bancos já criados
│   ├── procedure.py            # único ponto que executa CALL
│   ├── procedures.sql
│   └── schema.sql
└── scripts/                    # init_db, smoke_db, smoke_api, test_calculo

docs/
├── architecture.md
├── banco-e-procedures.md
├── como-executar.md
├── funcionalidades.md
├── historico-do-projeto.md
├── roadmap.md
├── roteiro-video.md
├── simplificacao-tecnica.md
└── visao-geral.md

frontend/app_mentorly/
├── lib/
│   ├── main.dart
│   ├── app/                    # routes.dart e theme.dart
│   ├── core/
│   │   ├── services/           # apiService.dart e authService.dart
│   │   ├── utils/              # validators.dart
│   │   └── widgets/            # botões, campos e modais de aluno (adicionar/editar)
│   └── features/
│       ├── auth/               # login, cadastro, convite e verificação em duas etapas
│       ├── coordenacao/        # turmas, alunos, professores, configuração e boletim
│       └── professor/          # dashboard, turmas, atividades, notas e boletim
└── test/                       # auth_flow_test.dart e widget_test.dart
```

---

## Como Executar

O passo a passo completo, com variáveis de ambiente e solução de problemas, está em
[docs/como-executar.md](docs/como-executar.md). Resumo:

### Backend

```bash
# 1. MySQL 8 em execução
# 2. Dependências
cd backend
pip install -r requirements.txt

# 3. (Opcional) backend/.env, ignorado pelo Git, com uma variável por linha:
#    DB_PASSWORD=...   SECRET_KEY=...

# 4. Executar: cria o banco, aplica schema e migrações e instala as procedures
python app.py
```

O servidor sobe em `http://localhost:5000`. Sem `SECRET_KEY` definida, o backend gera uma
chave aleatória a cada execução e avisa no console; nesse caso as sessões deixam de valer
quando o servidor reinicia.

### Frontend

```bash
cd frontend/app_mentorly
flutter pub get
flutter run
```

O backend precisa estar rodando. O endereço da API fica em um único lugar,
`lib/core/services/apiService.dart`:

| Onde roda | `baseUrl` |
|-----------|-----------|
| Chrome / Web / Windows | `http://localhost:5000/api` |
| Emulador Android | `http://10.0.2.2:5000/api` |

### Testes

```bash
cd backend
python scripts/smoke_db.py       # conexão, isolamento entre escolas, ano letivo e procedures
python scripts/smoke_api.py      # API de ponta a ponta (267 verificações)
python scripts/test_calculo.py   # motor de cálculo, sem banco
python scripts/test_migracao_ano_letivo.py   # migração do ano letivo sobre um banco no formato antigo
python scripts/test_migracao_transferencia_aluno.py  # migration de histórico de turma

cd ../frontend/app_mentorly
flutter analyze
flutter test
```

Os scripts de smoke usam o banco configurado em `DB_NAME` e limpam os dados que criam. Para
não tocar nos seus dados, aponte `DB_NAME` para um banco temporário.

---

## Público-Alvo

- Coordenadores pedagógicos;
- Professores do Ensino Fundamental e Médio.

---

## Status do Projeto

Em desenvolvimento. Os Marcos 1 a 8 (avaliação, desempenho, ciclo escolar, gerenciamento de
alunos, exclusão de nota, ano letivo, transferência com histórico e gestão de professores) estão
concluídos em código e testes. O próximo marco é IA, conforme [docs/roadmap.md](docs/roadmap.md).

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

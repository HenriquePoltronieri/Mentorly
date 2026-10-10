# Mentorly

> Estado atual: **Marcos 1 a 8 e bloco de IA (9A a 9D) concluídos em código e testes**. A fase atual é
> **validação final, congelamento (freeze) do MVP e preparação da apresentação**. O plano e o histórico das
> decisões estão em [docs/roadmap.md](docs/roadmap.md).

## Sobre o Projeto

O Mentorly é um sistema de acompanhamento acadêmico para escolas. A **Coordenação** configura
o ano letivo (etapas e critérios de avaliação), cadastra turmas, alunos e professores. Cada
**Professor** vê apenas as turmas que a Coordenação vinculou a ele, cria atividades, lança
notas e acompanha o desempenho dos alunos, com média por etapa, boletim, alunos em risco e
insights acadêmicos explicáveis gerados sob demanda por IA.

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
- integração HTTP com a **Groq** (modelo `openai/gpt-oss-20b`), configurável por ambiente

### Frontend
- Flutter 3 (Dart SDK `>=3.0.0 <4.0.0`)
- `http`, `shared_preferences`, `file_picker` e `url_launcher`

---

## Funcionalidades

São 25 funcionalidades demonstráveis, contadas de forma conservadora. A tabela completa, com
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
22. Insights acadêmicos explicáveis da turma, gerados por IA a partir do motor acadêmico
23. Gerar atividade com IA: o Professor pede uma sugestão, revisa e só então salva
24. Corrigir resposta discursiva com IA: a IA sugere a avaliação, o Professor decide e lança a nota
25. Feedback e plano de recuperação por IA para um aluno, a partir do resultado calculado pelo motor

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

### Princípio central: motor, IA e decisão humana

```text
Motor acadêmico = verdade numérica e regras
IA              = interpretação, geração e sugestão
Professor       = decisão humana final
```

`services/academico/calculo.py` produz todos os valores oficiais; os services de
`services/ia/` montam payloads mínimos; e `services/ia/client.py` (um único `AIClient`, usado
por 9A, 9B, 9C e 9D) envia esses payloads a um provedor compatível com chat completions. A IA
**nunca grava no banco**: o que ela sugere só vira dado oficial quando o Professor confirma, pelo
fluxo normal. Uma falha externa não afeta notas, boletim ou login.

### Insights acadêmicos (Marco 9A)

Na tela de uma turma, **Insights IA** gera resumo, pontos positivos, pontos de atenção com
evidência numérica e sugestões para a etapa atual. **A Groq recebe pseudônimos ("Aluno 1",
"Aluno 2"...) e dados acadêmicos, nunca o nome, a matrícula, o e-mail ou o id do aluno.** O mapa
pseudônimo → nome real fica dentro do Mentorly: depois que a resposta volta, o backend troca as
referências pelo primeiro nome antes de entregá-la ao Professor. A IA não participa do mapeamento.
Uma resposta que cite uma referência inexistente é tratada como inválida.

### Regras de integridade e segurança

Estas regras valem no backend, mesmo fora do aplicativo:

- **Nota mínima.** A comparação com o mínimo tem tolerância numérica (1e-9): uma nota
  matematicamente igual ao mínimo é "adequada", não "abaixo do mínimo" por ruído de ponto flutuante.
- **Etapa fechada congela a configuração.** Além de atividades e notas, a Coordenação não altera
  nome, ordem, datas, notas mínima/máxima nem critérios (criar, editar, excluir) até reabrir a etapa.
- **Ano encerrado é histórico somente leitura.** Leituras, boletim e desempenho seguem normais;
  criar, editar ou excluir turma, aluno, etapa, critério, atividade e nota daquele ano, e também fechar ou reabrir etapa, é recusado (400).
  A transferência de um aluno *a partir* de um ano encerrado continua permitida (promoção).
- **Atividade com notas congela turma, etapa, critério e valor máximo.** Título, descrição e data
  seguem editáveis. Nota 0 conta como nota lançada.
- **Exclusão barrada pelo banco devolve 409** com mensagem amigável (critério ou etapa em uso, turma
  protegida por histórico de transferência), em vez de erro interno. Os diálogos de exclusão do app
  avisam o que será apagado em cascata.
- **Entradas validadas.** Corpo que não é objeto, tipos errados, textos acima do limite da coluna,
  `NaN`/`Infinity`, pesos fora de 0–100, datas inválidas e ordem de etapa duplicada recebem 400/409,
  não 500. Um bug interno (inclusive `KeyError`/`IndexError`) responde 500 genérico, sem detalhe;
  "não encontrado" (404) é uma exceção própria, `RecursoNaoEncontrado`.
- **Sessão e token.** O JWT é aceito só no cabeçalho `Authorization: Bearer`. A única exceção são
  as três rotas GET de download de modelo de planilha, abertas pelo navegador, que não envia
  cabeçalho. No aplicativo, um 401 (ou o 403 de professor desativado, identificado por
  `code: professor_desativado`) limpa a sessão e leva ao login, uma única vez; os demais 403 são
  erro da operação e não encerram a sessão.
- **Limite de requisições** (em memória, por processo; reiniciar o backend zera os contadores e
  várias instâncias não compartilham o limite). Excedido: HTTP 429 com `Retry-After`.

  | Fluxo | Limite | Chave |
  |---|---|---|
  | Login (Coordenação e Professor) | 10 por 15 min | IP + e-mail |
  | Confirmar código de verificação | 6 por 15 min | IP + e-mail |
  | Enviar/reenviar código | 5 por 15 min | IP + e-mail |
  | Reenviar convite de professor | 5 por 15 min | escola + professor |
  | IA (9A, 9B, 9C e 9D, um limite só) | 20 por 15 min | Professor |
  | IA, teto global do processo | 100 por 15 min | todos |

### Geração assistida de atividades (Marco 9B)

No formulário de nova atividade, o botão **Gerar com IA** pede tema, objetivo, dificuldade, tipo e
quantidade de questões. A IA devolve título, descrição, questões, gabarito e uma rubrica sugerida;
o Professor edita ou remove o que quiser e confirma. A confirmação apenas preenche o formulário
normal, e quem cria a atividade é o botão **Adicionar**, pelo mesmo fluxo e com as mesmas
validações de sempre. **A IA nunca grava no banco.** Nenhum dado de aluno é enviado ao provedor.

### Correção assistida de respostas (Marco 9C)

```text
Resposta do aluno → IA sugere avaliação → Professor revisa → fluxo normal de Nota
```

Na tela de notas de uma atividade, o botão ✨ ao lado do campo de nota abre a **correção
assistida**. O Professor cola a questão, a resposta esperada e a resposta do aluno (e, se quiser,
uma rubrica), e a IA devolve uma **sugestão**: nota, justificativa, avaliação por critério com
evidências, pontos positivos, pontos a melhorar e um feedback para o aluno. O botão **Usar nota
sugerida** apenas preenche o campo de nota; o Professor pode mudar o valor, e a nota só é gravada
quando ele clica em **Salvar notas**, pelo fluxo normal. **A IA nunca lança nota.** O nome do aluno
e qualquer outro dado pessoal não são enviados ao provedor, e o percentual é calculado pelo
Mentorly, não pela IA.

### Feedback e recuperação personalizados (Marco 9D)

```text
Mentorly calcula → IA interpreta → Professor revisa
```

Na tela de desempenho de um aluno, cada etapa tem o botão **Gerar feedback com IA**. A IA recebe só
o resultado que o motor acadêmico já calculou (nota, percentual, situação, desempenho por critério,
atividades avaliadas e sem nota lançada) e devolve uma **sugestão pedagógica**: resumo, pontos
consolidados, pontos de atenção com evidência, objetivos, ações, atividades e acompanhamento. O tipo
de plano vem da situação oficial: **recuperação** (abaixo do mínimo), **continuidade** (adequado) ou
**acompanhamento** (em andamento, com dados incompletos). É somente leitura: nada é salvo, nenhuma
nota, situação, critério ou etapa muda, e nenhum dado pessoal do aluno é enviado ao provedor. A IA
não prevê reprovação ou evasão, não cria rótulo de risco, não faz diagnóstico e não inventa números.

### Configuração da IA e do ambiente

Copie os nomes de `backend/.env.example` para `backend/.env` e configure:

| Variável | Uso |
|---|---|
| `SECRET_KEY` | assina o JWT; sem ela o backend gera uma chave por execução (sessões caem ao reiniciar) |
| `AI_BASE_URL` | URL base do provedor; padrão `https://api.groq.com/openai/v1` |
| `AI_API_KEY` | credencial do provedor; nunca deve ser versionada |
| `AI_MODEL` | modelo; padrão `openai/gpt-oss-20b` |
| `AI_TIMEOUT` | limite da chamada em segundos; padrão interno de 15 |
| `FLASK_DEBUG` | `false` por padrão; `true` liga o debug do Flask só em desenvolvimento |
| `DEV_EXPOSE_AUTH_CODES` | `false` por padrão; `true` deixa a API devolver código de verificação e token de convite, só para uso local |
| `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASSWORD`, `SMTP_FROM`, `SMTP_TLS` | envio de e-mail (convite e código) |

**SMTP ausente não expõe nada.** Sem `SMTP_HOST`, o e-mail simplesmente não é enviado e a API
responde `conviteEnviado: false` / `enviado: false`; o aplicativo avisa que o convite não saiu.
Quem libera mostrar o código ou o link do convite é só `DEV_EXPOSE_AUTH_CODES=true`, e o padrão
seguro é `false`.

O provedor do MVP é a Groq, com o modelo `openai/gpt-oss-20b`, e a integração foi validada com
chamadas reais em 06/10/2026 (ver [docs/roadmap.md](docs/roadmap.md)). URL e modelo continuam
configuráveis para permitir troca sem alteração de código. Sem `AI_API_KEY`, ou com chave
inválida, o provedor fora do ar ou uma resposta inválida, o botão mostra uma mensagem amigável e o
restante do Mentorly continua normal.

Cuidados de operação, observados com o plano gratuito da Groq em 06/10/2026 (além do limite
interno de 20 chamadas de IA por Professor a cada 15 minutos, descrito acima):

- o modelo gasta parte do limite de saída raciocinando, por isso o cliente pede até 2500 tokens
  (900 truncava o JSON e a Groq recusava);
- cada geração consome em torno de 2,7 mil tokens, e o plano gratuito limitou a conta a 8000
  tokens por minuto e 200.000 tokens por dia, o que equivale a algumas dezenas de gerações por dia;
- uma resposta fora do contrato é repetida uma vez; timeout, rede, chave e limite de uso não são
  repetidos.

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
| POST | `/api/coordenacao/alunos/<id>/transferir` | Transferir aluno de turma (preserva o histórico) |
| GET | `/api/coordenacao/alunos/<id>/historico` | Histórico de turmas do aluno |
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
| POST | `/api/professor/turmas/<id>/insights` | Gerar insights da etapa atual com IA (9A) |
| POST | `/api/professor/turmas/<id>/atividades/gerar` | Sugerir atividade com IA, sem gravar (9B) |
| POST | `/api/professor/atividades/<id>/correcao-assistida` | Sugerir avaliação de uma resposta, sem lançar nota (9C) |
| POST | `/api/professor/alunos/<id>/feedback-ia` | Feedback e plano de recuperação, somente leitura (9D) |
| GET | `/api/professor/dashboard` | Dashboard (alunos em risco) |
| GET | `/api/professor/alunos/<id>/estatisticas` | Desempenho do aluno por etapa |
| PUT / DELETE | `/api/professor/alunos/<id>` | Editar / excluir aluno |
| DELETE | `/api/professor/notas/<id>` | Excluir nota lançada |
| GET / POST | `/api/atividades/<id>/notas` | Listar / lançar notas |
| GET | `/api/atividades/<id>/notas/modelo-planilha` | Modelo de planilha de notas (aceita `?token=`, ver abaixo) |
| POST | `/api/atividades/<id>/notas/importar` | Importar notas por planilha |

As três rotas de download de modelo de planilha (`GET .../modelo-planilha`, uma da Coordenação e
duas do Professor) são as únicas que aceitam `?token=<jwt>`, porque são abertas pelo navegador, que
não manda cabeçalho. Em qualquer outra rota o token só vale em `Authorization: Bearer`.

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
├── erros.py                    # RecursoNaoEncontrado (404), separado de bug interno
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
│   ├── ia/                     # 9A–9D: payloads, contratos e o AIClient único
│   ├── turmas.py               # CRUD de turma (funções)
│   ├── entrada.py              # validação de tipo, tamanho, número finito e data
│   ├── conflito.py             # violação de FK/unicidade esperada vira 409
│   ├── rate_limit.py           # limite de requisições em memória
│   └── email_service.py
├── models/                     # SQL de cada entidade
├── repositories/consultas.py   # consultas que chamam procedures
├── database/
│   ├── connection.py           # conexão, transações e instalador
│   ├── migrations.py           # colunas novas em bancos já criados
│   ├── procedure.py            # único ponto que executa CALL
│   ├── procedures.sql
│   └── schema.sql
└── scripts/                    # init_db, smoke_db, smoke_api e os test_*.py (ver "Testes")

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
│   │   ├── services/           # apiService.dart (inclui o tratamento de sessão inválida) e authService.dart
│   │   ├── utils/              # validators.dart e mensagensConvite.dart
│   │   └── widgets/            # botões, campos e modais de aluno (adicionar/editar)
│   └── features/
│       ├── auth/               # login, cadastro, convite e verificação em duas etapas
│       ├── coordenacao/        # turmas, alunos, professores, configuração e boletim
│       └── professor/          # dashboard, turmas, atividades, notas e boletim
└── test/                       # testes de widget e de fluxo (login, IA, sessão, limites, exclusão...)
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
#    DB_PASSWORD=...   SECRET_KEY=...   (veja backend/.env.example)

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
python scripts/smoke_db.py                  # conexão, isolamento entre escolas, ano letivo e procedures
python scripts/smoke_api.py                 # API de ponta a ponta (944 verificações)
python scripts/test_calculo.py              # motor de cálculo, sem banco (20 testes)
python scripts/test_config_dev.py           # padrões seguros de debug e de exposição de códigos (12)
python scripts/test_rate_limit.py           # limite de requisições (15)
python scripts/test_erros_nao_encontrado.py # 404 só para recurso inexistente (12)
python scripts/test_ia.py                   # 9A: payload, autorização e cliente externo, sem internet (22)
python scripts/test_ia_insights_privacidade.py  # 9A: nada identificável vai ao provedor (14)
python scripts/test_ia_atividade.py         # 9B (25)
python scripts/test_ia_correcao.py          # 9C (38)
python scripts/test_ia_feedback.py          # 9D (39)
python scripts/test_ia_erros_internos.py    # erro interno não vira erro de entrada (10)
python scripts/test_migracao_ano_letivo.py   # migração do ano letivo sobre um banco no formato antigo
python scripts/test_migracao_transferencia_aluno.py  # migration de histórico de turma
python scripts/test_migracao_professor_habilitado.py # migration do status administrativo

cd ../frontend/app_mentorly
flutter analyze   # 0 warnings e 0 errors; 101 infos de estilo
flutter test      # 107 testes
```

Nenhum teste chama a Groq nem envia e-mail: o provedor e o SMTP são substituídos por dublês.

Os scripts de smoke usam o banco configurado em `DB_NAME` e limpam os dados que criam. Para
não tocar nos seus dados, aponte `DB_NAME` para um banco temporário.

---

## Público-Alvo

- Coordenadores pedagógicos;
- Professores do Ensino Fundamental e Médio.

---

## Status do Projeto

Os Marcos 1 a 8 (avaliação, desempenho, ciclo escolar, gerenciamento de alunos, exclusão de
nota, ano letivo, transferência com histórico e gestão de professores) e o bloco de IA (9A
insights, 9B geração de atividades, 9C correção assistida e 9D feedback e recuperação) estão
concluídos em código e testes. Passou por uma auditoria final, com todos os itens importantes e
médios corrigidos. A fase atual é de validação final, congelamento do MVP e preparação da
apresentação. A integração externa depende das variáveis de ambiente do provedor e não altera nem
persiste dados acadêmicos.

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

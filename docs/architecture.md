# Arquitetura

A disciplina pediu que o projeto seguisse esta sequência de camadas:

```

FLUTTER

Tela

  → Controller / Service (Dart)

  → ApiService

FLASK

  → Route

  → Controller

  → Service

  → Model ou Repository

  → Banco de Dados (MySQL)

```

A regra principal é que cada camada faz uma coisa só e conversa com a camada seguinte. O projeto

segue esse fluxo **na maior parte do código**, mas não de forma absolutamente rígida: a seção

[Exceções conhecidas](#exceções-conhecidas) lista, com nome de arquivo, os poucos pontos em que

uma camada é pulada.

## Visão geral do sistema

- **Dois papéis.** A **Coordenação** configura a escola (ano letivo, turmas, alunos, professores).

  O **Professor** cria atividades, lança notas e acompanha o desempenho. Os papéis são

  verificados no backend, não só escondidos na interface.

- **Multi-escola.** Cada cadastro de Coordenação é uma escola. Todo dado pedagógico pendura em

  uma `coordenacao_id`, e o isolamento é reforçado no banco por chaves estrangeiras compostas

  (ver [banco-e-procedures.md](banco-e-procedures.md)).

- **Autenticação por JWT.** O login devolve um token HS256 com `{sub, tipo, coordenacao_id, exp}`.

  Os decorators de `backend/auth/decorators.py` (`@auth_required`, `@coordenacao_required`,

  `@professor_required`) validam o token e o papel. A escola e o professor da requisição vêm

  **sempre do token**, nunca do corpo ou da URL.

- **Disponibilidade do Professor.** `professor.habilitado` é o estado administrativo persistido;

  `senha_hash` só indica que o convite foi concluído. `@professor_required` consulta o estado atual

  do Professor, então um JWT emitido antes de desativá-lo perde acesso imediatamente.

- **Motor acadêmico único.** Nenhuma tela e nenhum outro service calcula nota. Dashboard,

  desempenho do aluno, boletim e fechamento de etapa passam por

  `backend/services/academico/calculo.py`.

- **IA explicativa separada.** O motor entrega percentuais, situações e critérios prontos. O

  service de IA reduz e delimita esses dados, chama o provedor externo e valida o JSON. A IA não

  calcula notas, não decide aprovação e não escreve no banco.

## No Flutter

- **Tela** — o que o usuário vê e usa. Cuida de botões, campos e listas e exibe o que o backend

  devolve. Não calcula média nem aplica regra acadêmica.

- **Service Dart / Controller Dart** — quem chama a API. Existe um por área, por exemplo

  `TurmasService`, `AtividadesService`, `EtapasService`, `BoletimService` (Coordenação),

  `BoletimTurmaService` (Professor), `AlunosService` e `AtividadesController` (notas). Recebem os

  dados da tela e devolvem o resultado pronto.

- **ApiService** — `lib/core/services/apiService.dart`. Concentra as requisições (`get`, `post`,

  `put`, `delete`, envio de arquivo), o endereço da API e o token de sessão. Se o endereço mudar,

  altera-se em um lugar só. Nenhum arquivo fora de `core/services/` importa `package:http`.

- **AuthService** — `lib/core/services/authService.dart`. Login, cadastro, primeiro acesso do

  professor e sessão persistida. As telas de login chamam o `AuthService` diretamente.

## No Flask

- **Route** — `backend/routes/`. Declara o endereço (Blueprint) e o decorator de papel. Não

  importa Models nem Services.

- **Controller** — `backend/controllers/`. É uma classe por área. Lê a requisição, chama o Service

  e devolve o código HTTP certo. Traduz exceções do Service em status (`LookupError` → 404,

  `ValueError` → 400/409). Não escreve SQL e não tem regra acadêmica.

- **Service** — `backend/services/`. Concentra as validações e as regras de negócio, inclusive a

  autorização por escola e por turma (por exemplo `aluno_acessivel` em

  `services/aluno/acesso_turma.py`). Na maior parte do código, cada caso de uso tem a sua classe

  com um método `execute()`. Services não importam Flask e não acessam o banco diretamente.

- **Model** — `backend/models/`. Uma classe por entidade, com métodos estáticos e SQL escrito à

  mão (PyMySQL). **Não há ORM.** Os Models também serializam a linha para o JSON da API.

- **Repository** — `backend/repositories/consultas.py`. Usado só para as consultas que não são

  CRUD e chamam Stored Procedures (busca de atividades, relatório de turmas, resumo da escola,

  professores por escola e turmas do professor). O `CALL` fica em um único arquivo,

  `backend/database/procedure.py`, que valida o nome contra uma lista de procedures permitidas.

- **Banco** — MySQL 8. O schema fica em `backend/database/schema.sql`, as migrações para bancos

  já criados em `backend/database/migrations.py` e as procedures em `procedures.sql`.

### O ano letivo como contexto

Cada escola tem os seus anos letivos (`ano_letivo`), e um deles é o **atual**. Turma e etapa

pertencem a um ano da própria escola, garantido por chave estrangeira. Nenhuma camada decide o ano

pelo relógio: `services/config/anos_letivos.py` concentra os casos de uso (listar, criar, mudar o

status, excluir) e a função `resolver_ano_letivo`, que devolve o ano a usar (o informado, validado

para a escola, ou o ano atual). Os Services de turma, etapa, dashboard, boletim e desempenho do

aluno recebem ou deduzem o ano a partir daí; o motor (`calculo.py`) apenas **exige** o ano e nunca

lista etapas de todos os anos. Só a Coordenação tem rotas de anos letivos; o Professor consome o

contexto nas próprias turmas.

### O motor acadêmico e o boletim

```

backend/services/academico/

├── calculo.py   # desempenho por criterio e por etapa, consolidado, etapa atual

└── boletim.py   # monta o boletim de uma turma chamando o motor uma vez por aluno

```

`calculo.py` implementa a regra: desempenho do critério = pontos obtidos ÷ pontos possíveis, com o

peso de cada critério, sem arredondamento intermediário. Nota ausente não é zero. O consolidado

considera apenas etapas **fechadas** e completas. O boletim apenas agrega o resultado do motor.

### IA como camada de apoio ao Professor

A arquitetura de IA segue o mesmo princípio dos demais módulos: o domínio do Mentorly prepara o
contexto, um cliente isolado conversa com o provedor externo e a resposta volta para a interface.
O modelo externo nunca acessa o banco diretamente.

```text
dados e regras determinísticas
        ↓
Service do caso de uso
        ↓
payload estruturado e limitado
        ↓
AIClient
        ↓
modelo externo
        ↓
resposta estruturada e validada
        ↓
Flutter
```

A separação central é:

```text
Motor acadêmico = verdade numérica e regras oficiais.
IA              = interpretação, geração e sugestão.
```

A IA nunca é a fonte oficial de nota, média, percentual, situação acadêmica, aprovação, reprovação
ou fechamento de etapa.

#### Dois tipos de fluxo

**1. IA somente leitura**

É o padrão dos Insights Acadêmicos já implementados:

```text
dados acadêmicos
  → cálculo determinístico
  → IA
  → explicação ao Professor
```

Nada é persistido por esse fluxo.

**2. IA geradora com revisão humana**

É o padrão planejado para geração de atividades, correção assistida e feedback/recuperação:

```text
Professor solicita
  → backend prepara contexto
  → IA gera sugestão
  → Flutter apresenta
  → Professor revisa e pode alterar
  → Professor confirma
  → fluxo normal do Mentorly persiste, quando aplicável
```

Portanto, **IA não significa persistência automática**.

#### Marco 9A — Insights Acadêmicos Explicáveis — implementado

```text
Aluno / Turma / Etapa / Critério / Atividade / Nota
  → calcular_desempenho_etapa                 (verdade numérica)
  → GerarInsightsTurmaService                 (autorização, redução e agregados)
  → AIClient                                  (HTTP externo e JSON estruturado)
  → InsightsTurmaScreen                       (exibição sob demanda)
```

`GerarInsightsTurmaService` exige o vínculo `professor_turma`, compara a escola da turma com a
escola do JWT e usa a etapa do ano da própria turma. O payload contém nome da turma, ano, etapa,
escala, agregados, primeiro nome do aluno, situação, percentuais, completude e critérios. Email,
matrícula, identificadores do banco e autenticação não saem da aplicação.

Detalhes individuais são limitados a 50 alunos; para turmas maiores, os agregados continuam
considerando todos.

O prompt de sistema manda tratar strings do JSON como dados, usar somente evidências fornecidas e
não inferir intenção, personalidade ou futuro. O cliente aceita apenas o contrato `resumo`,
`pontosPositivos`, `pontosAtencao` e `sugestoesGerais`. Ausência de chave, timeout, falha HTTP ou
JSON inválido viram erro amigável; nenhuma resposta artificial é criada.

**Estado:** a infraestrutura e os Insights estão implementados e cobertos por testes com cliente
simulado. A chamada externa real ainda precisa ser validada com `AI_API_KEY` antes de considerar a
integração operacionalmente encerrada.

#### Marco 9B — Geração assistida de atividades e questões — planejado

Fluxo arquitetural previsto:

```text
Professor
  → formulário de criação de atividade
  → contexto pedagógico
  → Service de geração com IA
  → AIClient
  → sugestão estruturada
  → Flutter
  → Professor revisa
  → fluxo normal de criação da atividade
  → Model
  → MySQL
```

O contexto pode incluir tema, etapa, critério, dificuldade e quantidade/tipo de questões. A resposta
pode conter título, enunciado, questões, gabarito/resposta esperada, orientações e rubrica.

A IA **não chama diretamente** `Atividade.create`. O Professor precisa revisar o conteúdo antes de
entrar no fluxo normal de criação.

#### Marco 9C — Correção assistida de respostas discursivas — planejado

Essa é a funcionalidade de IA de maior impacto prevista para a demonstração. Como os alunos ainda
não acessam o Mentorly, na primeira versão o Professor cola ou digita a resposta do aluno.

```text
Professor
  → seleciona atividade e aluno
  → informa questão / resposta esperada / rubrica
  → informa resposta do aluno
  → Service de correção assistida
  → AIClient
  → avaliação estruturada
  → Flutter mostra sugestão
  → Professor revisa e pode alterar
  → Professor confirma
  → fluxo normal de lançamento de nota
  → Nota
  → MySQL
```

O retorno pode conter:

- avaliação por critério;
- evidências encontradas na resposta;
- pontos atendidos;
- pontos faltantes;
- pontuação sugerida;
- feedback pedagógico.

Exemplo conceitual:

```text
Contexto histórico:      22 / 30
Mudanças tecnológicas:   35 / 40
Impactos sociais:        18 / 30

Sugestão total:          75 / 100
```

`75/100` é somente uma **sugestão**. O valor não vira nota antes da confirmação do Professor.

Regra estrutural:

```text
AIClient
  NÃO
→ Nota.lancar
```

A rubrica definida pelo Professor é a referência principal da análise. A IA não deve substituir
critérios já definidos por critérios inventados.

#### Marco 9D — Feedback e recuperação personalizados — planejado

```text
dados acadêmicos já calculados
  → Service específico
  → AIClient
  → feedback / plano sugerido
  → Professor
```

A entrada pode usar critérios, atividades, desempenho, completude, etapa e situação oficial. A saída
pode apresentar pontos fortes, pontos de atenção, feedback individual e sugestões de recuperação.
Nenhuma dessas sugestões altera nota ou status acadêmico.

#### Human in the loop

Há dois níveis de controle humano:

```text
Insights:
IA → Professor lê
```

e, quando a sugestão pode produzir efeito no sistema:

```text
IA
  → Professor revisa
  → Professor confirma
  → Service normal do Mentorly
  → banco
```

Isso impede que uma resposta do modelo externo contorne as validações acadêmicas já existentes.

#### Separação entre domínio e integração externa

O `AIClient` deve conhecer apenas:

- endpoint do provedor;
- chave e modelo configurados;
- timeout;
- envio HTTP;
- contrato de resposta.

Ele não deve conhecer diretamente `Nota`, `Atividade`, `Aluno`, conexão MySQL ou regras de negócio.

Quem conhece as entidades do Mentorly é o Service de cada caso de uso:

```text
Service do Mentorly
  → conhece domínio e prepara contexto

AIClient
  → conhece integração externa e devolve estrutura
```

A intenção é reutilizar `backend/services/ia/client.py` em todos os casos de uso. Mudam o prompt,
o payload e o contrato de resposta, não o cliente HTTP.

#### Contratos estruturados por caso de uso

Cada funcionalidade possui um contrato próprio:

| Caso | Saída esperada |
|---|---|
| Insights | resumo, pontos positivos, pontos de atenção, sugestões |
| Geração de atividade | título, questões, gabarito, orientações, rubrica |
| Correção assistida | critérios, evidências, pontuação sugerida, feedback |
| Feedback/recuperação | feedback, pontos fortes, pontos de atenção, ações sugeridas |

Não se usa uma resposta textual genérica para tudo.

#### Segurança e privacidade da IA

Antes de qualquer payload ser montado, continuam valendo as regras normais do Mentorly:

- JWT e papel são validados;
- a escola vem do token;
- a turma precisa pertencer à escola;
- o vínculo Professor–Turma é validado quando aplicável.

Conteúdo do banco e do usuário é tratado como **dado**, não como instrução capaz de substituir o
prompt de sistema.

`AI_API_KEY` existe somente no ambiente. Chave, JWT e payloads sensíveis completos não devem ser
registrados em logs.

A minimização também depende do caso:

- **Insights:** primeiro nome e dados acadêmicos necessários;
- **Geração de atividade:** normalmente nenhum dado de aluno;
- **Correção:** questão, rubrica e resposta textual, sem email, matrícula, senha, JWT ou id do banco;
- **Feedback:** somente os resultados acadêmicos necessários para o objetivo.

#### Falha segura

Nenhum fluxo acadêmico obrigatório depende da disponibilidade da IA:

```text
Insights indisponíveis
→ dashboard, notas e boletim continuam funcionando

Geração indisponível
→ Professor cria atividade manualmente

Correção indisponível
→ Professor corrige e lança nota manualmente

Feedback indisponível
→ dados acadêmicos continuam disponíveis normalmente
```

As chamadas são sob demanda, nunca disparadas por `build()` do Flutter. O botão fica desabilitado
durante a requisição e o payload é limitado para evitar chamadas duplicadas e custo desnecessário.

#### Persistência

Não existe tabela genérica de IA.

- Insights não são persistidos.
- Atividade gerada só será persistida depois da confirmação do Professor e pelo fluxo normal.
- A sugestão bruta da correção não precisa ser persistida inicialmente; a decisão confirmada volta
  ao fluxo normal de nota.
- Feedback/recuperação pode inicialmente ser apenas exibido.

#### Visão geral da integração

```text
                         ┌─────────────────────┐
                         │       Flutter       │
                         └──────────┬──────────┘
                                    │
                           ApiService / JWT
                                    │
                         ┌──────────▼──────────┐
                         │       Flask         │
                         │ Route / Controller  │
                         └──────────┬──────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    │                               │
            Services de domínio               Services de IA
                    │                               │
               Models / SQL                      AIClient
                    │                               │
                  MySQL                      Modelo externo
```

O modelo externo nunca acessa o banco. Quando uma sugestão precisa virar dado oficial, ela volta
ao fluxo normal do domínio e passa novamente pelas validações do Mentorly.

---

## Exemplo 1 — Lançar notas (Professor)

```

atividadeNotasScreen.dart                  (tela: tabela de alunos e notas)

  → AtividadesController.salvarNotas       (features/professor/controllers/atividadesController.dart)

  → ApiService.post('/atividades/<id>/notas')

  → POST /api/atividades/<id>/notas        (backend/routes/professor_routes.py, @professor_required)

  → ProfessorController.lancar_notas       (backend/controllers/professor_controller.py)

  → LancarNotasService.execute             (backend/services/professor/notas.py)

  → Nota.lancar_em_lote                    (backend/models/nota_model.py)

  → tabela nota no MySQL

```

- o Controller só lê o corpo da requisição, passa o `id` do professor (vindo do token) e traduz o

  resultado em HTTP;

- o `LancarNotasService` é quem valida: o professor leciona na turma da atividade, o aluno é da

  turma, o valor está entre 0 e a nota máxima da atividade e **a etapa não está fechada**;

- quem grava é o Model, em uma transação só (todas as notas ou nenhuma).

## Exemplo 2 — Fechar etapa (Coordenação)

```

boletimTurmaScreen.dart                    (features/coordenacao/screens/academico/)

  → EtapasService.fecharEtapa              (features/coordenacao/services/etapasService.dart)

  → ApiService.post('/config/etapas/<id>/fechar')

  → POST /api/config/etapas/<id>/fechar    (backend/routes/config_routes.py, @coordenacao_required)

  → ConfigController.fechar_etapa          (backend/controllers/config_controller.py)

  → FecharEtapaService.execute             (backend/services/config/etapas.py)

  → Etapa.fechar                           (backend/models/etapa_model.py)

  → coluna etapa.fechada no MySQL

```

Antes de fechar, o service usa o motor (`calcular_desempenho_etapa`) para contar quantos alunos

ainda têm atividade sem nota e devolve esse número como aviso. O fechamento não é bloqueado por

isso. Depois de fechada, criar/editar/excluir atividade, lançar, importar e excluir nota na etapa

passam a ser recusados pelos Services de atividade e de nota, até a Coordenação reabrir.

## Exemplo 3 — Buscar atividades (consulta com procedure)

A busca não é CRUD, então passa pelo Repository:

```

buscarAtividadesScreen.dart

  → AtividadesService.buscarAtividades     (features/professor/services/atividadesService.dart)

  → ApiService.get('/activities/buscar')

  → GET /api/activities/buscar             (backend/routes/activity_routes.py, @auth_required)

  → ActivityController.buscar_atividades   (backend/controllers/activity_controller.py)

  → consultas.buscar_atividades            (backend/repositories/consultas.py)

  → call_procedure("sp_buscar_atividades") (backend/database/procedure.py)

  → MySQL

```

Aqui **não há Service intermediário**: o Controller chama a função do Repository diretamente. É uma

das exceções abaixo. O isolamento continua garantido, porque o Controller passa o `coordenacao_id`

do token e, se quem busca for professor, o `professor_id`.

## Exemplo 4 — Boletim da turma (Professor)

```

boletimTurmaScreen.dart                    (features/professor/screens/turmas/)

  → BoletimTurmaService.buscarBoletim      (features/professor/services/boletimTurmaService.dart)

  → GET /api/professor/turmas/<id>/boletim (@professor_required)

  → ProfessorController.boletim_turma      (confere a turma com Turma.find_by_id_para_professor)

  → montar_boletim_turma                   (backend/services/academico/boletim.py)

  → calcular_todas_etapas / calcular_consolidado_geral (backend/services/academico/calculo.py)

  → Aluno, Etapa, Criterio, Atividade, Nota (Models)

```

## Exemplo 5 — Insights da turma (Professor)

```text

insightsTurmaScreen.dart

  → InsightsIaService.gerar

  → POST /api/professor/turmas/<id>/insights (@professor_required)

  → ProfessorController.insights_turma

  → GerarInsightsTurmaService.execute

  → calcular_desempenho_etapa para cada aluno

  → AIClient.gerar

  → Mistral Small por padrão (provedor/modelo substituíveis por configuração)

```

O botão manual evita chamadas em rebuild. A indisponibilidade do provedor afeta somente essa
requisição e não entra no fluxo do motor acadêmico.

Esse fluxo está **implementado** e testado com cliente externo simulado. A chamada ao provedor real
ainda depende da configuração local de `AI_API_KEY`, portanto a validação externa real continua
pendente.

## Exemplo 6 — Correção assistida de resposta discursiva (planejado)

Os componentes abaixo ainda são **planejados**; os nomes representam a direção arquitetural e não
devem ser lidos como arquivos já existentes.

```text
correcaoAssistidaScreen.dart                 (planejado)
  → CorrecaoIaService Dart                   (planejado)
  → POST /api/professor/.../corrigir         (planejado)
  → ProfessorController                      (planejado)
  → CorrigirRespostaIaService                (planejado)
  → AIClient                                 (reutilizado)
  → modelo externo
  → sugestão estruturada
  → Flutter
  → Professor revisa e confirma
  → endpoint normal de notas
  → LancarNotasService
  → Nota
  → MySQL
```

A separação é proposital: o modelo externo pode sugerir avaliação e feedback, mas não conhece
`Nota` nem executa persistência. A confirmação humana devolve o fluxo ao Service de domínio que já
valida Professor, turma, aluno, etapa fechada e limites da nota.

---

## Exceções conhecidas

A auditoria do código encontrou os pontos abaixo. Nenhum coloca regra acadêmica pesada na

interface ou no Controller; são atalhos pequenos e conscientes.

| Onde | O que acontece | Observação |

|---|---|---|

| `class_controller.py` (`list_classes`, `get_class`) | O ramo do Professor chama `ProfessorTurma` e `Turma` direto (Controller → Model) | Consulta de leitura com o `professor_id` do token |

| `coordenacao_controller.py` e `professor_controller.py` (`boletim_turma`) | Chamam `Turma.find_by_id*` direto para validar acesso (Controller → Model) | `boletim.py` documenta que quem valida a turma é o Controller |

| `activity_controller.py`, `class_controller.py`, `dashboard_controller.py` | Chamam `repositories/consultas.py` sem Service (Controller → Repository) | Simplificação intencional ([simplificacao-tecnica.md](simplificacao-tecnica.md)): o Service apenas repassava a chamada |

| `services/turmas.py` | CRUD de turma como módulo de funções, e não uma classe por caso de uso | Os demais Services seguem o padrão classe + `execute()` |

| `adicionarAlunosModal`, `editarAlunoModal`, `lancarNotasModal` (Flutter) | Usam `ApiService` direto, sem um Service Dart | Servem para envio de arquivo, cadastro e edição de aluno; só exibem e enviam dados |

Essas exceções podem ser reavaliadas, se forem importantes para o checkpoint.

## Princípios aplicados

- **Responsabilidade única.** Um Service por caso de uso, o SQL concentrado nos Models, o cálculo

  acadêmico concentrado em um único módulo e a autorização concentrada nos decorators e em

  helpers como `aluno_acessivel`.

- **Aberto para extensão.** Um caso de uso novo costuma virar um Service, um método de Controller e

  uma rota, sem reescrever o que já existe. Foi assim com exclusão de aluno, boletim e exclusão de

  nota.

- **Interfaces enxutas.** Cada Service expõe apenas `execute()`; os módulos `turmas.py` e

  `consultas.py` expõem cinco funções cada.

- **Dependências.** Os Services dependem diretamente dos Models concretos (métodos estáticos). O

  acoplamento é intencional e simples, adequado ao tamanho do projeto: não há camada de abstração

  adicional entre Service e Model.

- **Sem herança relevante.** Por isso o princípio de substituição de Liskov não é exercitado de

  forma significativa neste projeto.

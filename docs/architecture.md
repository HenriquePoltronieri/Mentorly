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

### IA como camada de leitura

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
matrícula, identificadores do banco e autenticação não saem da aplicação. Detalhes individuais
são limitados a 50 alunos; para turmas maiores, os agregados continuam considerando todos.

O prompt de sistema manda tratar strings do JSON como dados inertes, usar somente evidências
fornecidas e recusar inferências sobre intenção, personalidade ou futuro. O cliente aceita apenas
o contrato `resumo`, `pontosPositivos`, `pontosAtencao` e `sugestoesGerais`. Ausência de chave,
timeout, falha HTTP ou JSON inválido viram 503 amigável; nenhuma resposta artificial é criada.
Não existe tabela de IA nem cache persistente nesta versão.

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

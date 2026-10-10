# Funcionalidades

O Mentorly tem hoje **25 funcionalidades demonstráveis**, contadas de forma conservadora: cada
linha abaixo tem tela no aplicativo, endpoint na API e regra no backend. Todas passam pelas
camadas explicadas em [architecture.md](architecture.md).

Quando uma linha diz "Repository", o Controller chama `repositories/consultas.py` diretamente, sem
um Service (exceção documentada na arquitetura).

## Coordenação

| # | Funcionalidade | Tela Flutter | Service/Controller Dart | Endpoint | Service backend | Model / Repository |
|---|---|---|---|---|---|---|
| 1 | Cadastro e login da Coordenação (cada cadastro é uma escola) | `cadastroScreen`, `loginScreen` | `AuthService.cadastrarCoordenacao`, `loginCoordenacao` | `POST /api/auth/cadastro-coordenacao`, `/login-coordenacao` | `CadastroCoordenacaoService`, `LoginCoordenacaoService` | `Coordenacao` |
| 2 | Anos letivos (atual, em planejamento ou encerrado) e etapas com nota mínima e máxima | `anosLetivosScreen`, `configEtapasScreen`, `configNotasEtapaScreen` | `AnosLetivosService`, `EtapasService` | `GET`/`POST /api/config/anos-letivos`, `PUT`/`DELETE /api/config/anos-letivos/<id>`, `POST /api/config/etapas`, `POST /api/config/etapas/<id>/notas` | `ListarAnosLetivosService`, `CriarAnoLetivoService`, `AtualizarAnoLetivoService`, `ExcluirAnoLetivoService`, `SalvarEtapaService`, `DefinirNotasEtapaService` | `AnoLetivo`, `Etapa` |
| 3 | Critérios de avaliação com pesos (os pesos de uma etapa somam 100) | `configCriteriosScreen` | `CriteriosService` | `/api/config/criterios/...` | `SalvarCriterioService` e demais | `Criterio` |
| 4 | Gerenciar turmas (cadastrar, listar, editar, excluir), cada uma em um ano letivo da escola | `gerenciarTurmasScreen`, `adicionarTurmaModal` | `TurmasService` | `/api/classes` | funções de `services/turmas.py` | `Turma` |
| 5 | Cadastrar alunos manualmente | `listaAlunosTurmaScreen`, `adicionarAlunosModal` | `AlunosService.listarAlunos` (o cadastro usa o `ApiService` no modal) | `POST /api/coordenacao/turmas/<id>/alunos` | `CadastrarAlunoService` | `Aluno` |
| 6 | Importar alunos por planilha XLSX (modelo para baixar e relatório de erros por linha) | `adicionarAlunosModal` | `ApiService` (envio de arquivo) | `POST /api/coordenacao/turmas/<id>/alunos/importar` | `ImportarAlunosService` | `Aluno` |
| 7 | Editar e excluir aluno | `listaAlunosTurmaScreen`, `editarAlunoModal` | `AlunosService.excluirAluno` | `PUT` e `DELETE /api/coordenacao/alunos/<id>` | `AtualizarAlunoService`, `ExcluirAlunoService` | `Aluno` |
| 8 | Transferir aluno com histórico de turmas | `listaAlunosTurmaScreen`, `transferirAlunoModal`, `historicoAlunoModal` | `AlunosService.transferirAluno`, `historicoAluno` | `POST /api/coordenacao/alunos/<id>/transferir`, `GET /historico` | `TransferirAlunoService`, `HistoricoAlunoService` | `Aluno`, `AlunoTurmaHistorico` |
| 9 | Gerenciar professor: cadastrar, editar, status, convite (a tela diz se o e-mail saiu ou não) e reativação | `cadastroProfessorScreen`, `listaProfessoresScreen` | `ProfessoresService` | `GET`/`POST /api/coordenacao/professores`, `PUT /<id>`, `POST /desativar`, `/reativar`, `/reenviar-convite` | `CadastrarProfessorService`, `ListarProfessoresService`, services de `gerenciar_professor.py` | `Professor` |
| 10 | Visualizar, vincular e desvincular professores de turmas | `listaTurmasProfessorScreen`, menu de `listaProfessoresScreen` | `ProfessorTurmasService` | `GET`/`POST /api/coordenacao/professores/<id>/turmas`, `DELETE /<id>/turmas/<turma_id>` | `VincularTurmasService`, `DesvincularTurmaDoProfessorService` | `ProfessorTurma` |
| 11 | Relatório de turmas com a contagem de atividades | `relatorioTurmasScreen` | `TurmasService.relatorioTurmasAtividades` | `GET /api/classes/relatorio/atividades` | Repository | `sp_relatorio_turmas_atividades` |
| 12 | Desempenho acadêmico: boletim por turma e fechamento/reabertura de etapa, com aviso de alunos incompletos | `boletimTurmasScreen`, `boletimTurmaScreen` (Coordenação) | `BoletimService`, `EtapasService.fecharEtapa`/`reabrirEtapa` | `GET /api/coordenacao/turmas/<id>/boletim`, `POST /api/config/etapas/<id>/fechar` e `/reabrir` | `montar_boletim_turma`, `FecharEtapaService`, `ReabrirEtapaService` | `calculo.py`, `Etapa` |

## Professor

| # | Funcionalidade | Tela Flutter | Service/Controller Dart | Endpoint | Service backend | Model / Repository |
|---|---|---|---|---|---|---|
| 13 | Primeiro acesso por convite e login | `definirSenhaProfessorScreen`, `professorLoginScreen` | `AuthService.criarSenhaProfessor`, `loginProfessor` | `POST /api/auth/criar-senha-professor`, `/login-professor` | `CriarSenhaProfessorService`, `LoginProfessorService` | `Professor` |
| 14 | Criar, editar e excluir atividade, com etapa, critério e valor máximo | `turmaAtividadesScreen`, `adicionarAtividadeModal` | `AtividadesService` | `POST`, `PUT`, `DELETE /api/activities` | `CreateActivityService`, `UpdateActivityService`, `DeleteActivityService` | `Atividade` |
| 15 | Listar e buscar atividades (por termo, com ordenação) | `listaAtividadesScreen`, `buscarAtividadesScreen` | `AtividadesService.listarAtividades`, `buscarAtividades` | `GET /api/activities`, `GET /api/activities/buscar` | `GetActivitiesService`; a busca usa Repository | `Atividade`, `sp_buscar_atividades` |
| 16 | Lançar notas em lote, com validação do valor máximo | `atividadeNotasScreen` | `AtividadesController.salvarNotas` | `POST /api/atividades/<id>/notas` | `LancarNotasService` | `Nota` |
| 17 | Importar notas por planilha (modelo já preenchido com os alunos) | `lancarNotasModal` | `ApiService` (envio de arquivo) | `POST /api/atividades/<id>/notas/importar` | `ImportarNotasService` | `Nota` |
| 18 | Excluir nota lançada, com confirmação | `atividadeNotasScreen` | `AtividadesController.excluirNota` | `DELETE /api/professor/notas/<id>` | `ExcluirNotaService` | `Nota` |
| 19 | Dashboard com alunos em risco na etapa atual | `dashboardScreen` | `ProfessorDashboardService` | `GET /api/professor/dashboard` | `DashboardProfessorService` | `calculo.py`, `Turma`, `Aluno` |
| 20 | Desempenho do aluno: por etapa, por critério e consolidado | `alunoDetailScreen` | `ProfessorAlunoDetailService` | `GET /api/professor/alunos/<id>/estatisticas` | `EstatisticasAlunoService` | `calculo.py`, `Nota` |
| 21 | Boletim da turma | `boletimTurmaScreen` (Professor) | `BoletimTurmaService` | `GET /api/professor/turmas/<id>/boletim` | `montar_boletim_turma` | `calculo.py`, `Aluno` |
| 22 | Insights acadêmicos explicáveis da etapa atual (a Groq recebe só pseudônimos "Aluno N"; os nomes voltam pelo Mentorly) | `insightsTurmaScreen` | `InsightsIaService` | `POST /api/professor/turmas/<id>/insights` | `GerarInsightsTurmaService`, `AIClient` | `calculo.py`, `Aluno`, `Turma` |
| 23 | Gerar atividade com IA, revisar e salvar pelo fluxo normal | `gerarAtividadeIaDialog` (dentro de `adicionarAtividadeModal`) | `GeracaoAtividadeIaService` | `POST /api/professor/turmas/<id>/atividades/gerar` | `GerarAtividadeIaService`, `AIClient` | `Turma`, `Etapa`, `Criterio` (a criação usa `Atividade`) |
| 24 | Corrigir resposta discursiva com IA: sugestão revisada pelo Professor, nota lançada pelo fluxo normal | `corrigirRespostaIaDialog` (dentro de `atividadeNotasScreen`) | `CorrecaoAssistidaIaService` | `POST /api/professor/atividades/<id>/correcao-assistida` | `CorrigirRespostaIaService`, `AIClient` | `Atividade`, `Etapa` (a nota é gravada por `LancarNotasService`, não pela IA) |
| 25 | Feedback e plano de recuperação por IA para um aluno em uma etapa (somente leitura) | `feedbackIaDialog` (dentro de `alunoDetailScreen`) | `FeedbackIaService` | `POST /api/professor/alunos/<id>/feedback-ia` | `GerarFeedbackIaService`, `AIClient` | `calculo.py`, `Aluno`, `Etapa` (nenhuma escrita) |

O Professor também edita e exclui aluno nas turmas dele (`PUT`/`DELETE /api/professor/alunos/<id>`,
os mesmos Services da funcionalidade 7), e importa alunos por planilha.

## O que sustenta as funcionalidades (não contado na lista)

- **Isolamento entre escolas.** Nenhuma escola enxerga dados de outra; o banco recusa vínculos
  entre escolas por meio de chaves estrangeiras compostas.
- **Permissões por papel.** A Coordenação não cria atividade nem lança nota, e o Professor não
  gerencia turmas nem configura o ano letivo. Isso responde 403 no backend, mesmo fora do app.
- **Ciclo administrativo de Professor.** `habilitado` decide acesso; `senha_hash` decide se o
  convite já foi concluído. Desativar bloqueia login e JWT antigo sem apagar vínculos, notas ou atividades.
- **Ano letivo como contexto.** O dashboard, o boletim, o desempenho do aluno e a etapa atual
  usam o ano certo: o dashboard, o ano atual da escola; o boletim e o desempenho, o ano da própria
  turma. Turma, etapa e atividade nunca se misturam entre anos.
- **Motor de cálculo acadêmico** (`services/academico/calculo.py`): média ponderada por etapa, nota
  ausente diferente de zero, consolidado só com etapas fechadas.
- **IA somente para interpretação.** Recebe resultados já calculados e dados acadêmicos mínimos, não
  escreve no banco e não produz nota, status ou previsão. O 9A envia pseudônimos ("Aluno 1"...) e
  remapeia os nomes localmente; 9B, 9C e 9D não enviam identificação de aluno. Há um único
  `AIClient`, e a falha da IA nunca derruba o restante do sistema.
- **Integridade acadêmica** (regras do backend, não novas telas):
  - nota igual à mínima é "adequada" (tolerância de ponto flutuante);
  - etapa fechada congela atividades, notas e também a configuração da etapa e dos critérios;
  - ano letivo encerrado é histórico somente leitura, inclusive fechar e reabrir etapa (a transferência a partir dele continua permitida);
  - atividade que já tem notas não muda de turma, etapa, critério nem valor máximo;
  - exclusão barrada por vínculo protegido responde 409 com mensagem clara, e os diálogos de exclusão
    avisam o que será apagado em cascata.
- **Segurança e robustez.** Entradas inválidas respondem 400, não 500; "não encontrado" é uma
  exceção própria (`RecursoNaoEncontrado`) e bug interno responde 500 genérico; o JWT só vale no
  cabeçalho (exceto nos 3 downloads de modelo de planilha); sessão inválida no app limpa a sessão e
  volta ao login; login, códigos, convites e IA têm limite de requisições (429 com `Retry-After`).
- **Bloqueio de alterações em etapa fechada** (atividade, nota e configuração), até a Coordenação reabrir.

## Fora da lista

- `GET /api/dashboard/resumo` (totais da escola) existe na API e é testado, mas ainda não tem tela.
- A verificação em duas etapas (`/api/auth/enviar-codigo`, `/confirmar-codigo`) existe no backend e
  no `AuthService`, mas está fora do fluxo de login. A decisão sobre usá-la está em aberto
  ([roadmap.md](roadmap.md)).

## Como chegar em cada tela

**Coordenação** — depois do login, o painel tem os atalhos:

- **Professores** → funcionalidade 9;
- **Gerenciar Turmas** → 4; tocando em uma turma, abrem os alunos → 5, 6, 7 e 8;
- **Vincular Professores** → 10;
- **Anos Letivos** → 2 (cadastrar anos, marcar o atual, encerrar); o menu de cada ano abre a configuração de etapas e critérios daquele ano;
- **Configurar Ano Letivo** → 2 e 3, para o ano atual;
- **Buscar Atividades** → 15 (leitura);
- **Relatório de Turmas** → 11;
- **Desempenho Acadêmico** → 12.

**Professor** — a barra superior tem **Dashboard** (19), **Turmas** e **Atividades**:

- **Turmas** → turma → alunos (7) → aluno (20), botão **Boletim** (21) e **Insights IA** (22);
- **Atividades** → turma → atividade → lançar, importar e excluir notas (16, 17 e 18); criar, editar
  e excluir atividade é a 14, e a busca (15) fica na própria tela de atividades; em **Adicionar
  atividade**, o botão **Gerar com IA** (23) preenche o formulário com uma sugestão revisada, e quem
  salva continua sendo o **Adicionar**; na tela de notas, o botão ✨ de cada aluno abre a **correção
  assistida** (24), que só preenche o campo de nota, e quem grava continua sendo o **Salvar notas**;
  na tela de desempenho do aluno, cada etapa tem **Gerar feedback com IA** (25), somente leitura.

## Situação dos testes

Os testes automáticos abaixo passam no estado atual do repositório (10/10/2026). Nenhum chama a
Groq nem envia e-mail.

| Teste | O que cobre | Resultado |
|---|---|---|
| `python scripts/smoke_db.py` | Escrita, leitura, isolamento por FK composta, regras do ano letivo no banco e procedures | OK |
| `python scripts/smoke_api.py` | API de ponta a ponta: papéis, isolamento, ano letivo, transferência, professores, IA (9A–9D com provedor simulado) e as regras de integridade e segurança da auditoria final | 944 verificações, 0 falhas |
| `python scripts/test_calculo.py` | Regras do motor de cálculo, inclusive a fronteira da nota mínima, sem banco | 20 testes, OK |
| `python scripts/test_config_dev.py` | Padrões seguros de `FLASK_DEBUG` e `DEV_EXPOSE_AUTH_CODES`; ausência de segredos nos testes | 12 testes, OK |
| `python scripts/test_rate_limit.py` | Janela deslizante, `Retry-After`, limpeza de memória e concorrência | 15 testes, OK |
| `python scripts/test_erros_nao_encontrado.py` | 404 só para recurso inexistente; `KeyError`/`IndexError` viram 500 genérico; trava de código-fonte | 12 testes, OK |
| `python scripts/test_ia.py` | 9A: payload mínimo, limite, autorização e cliente externo com respostas simuladas | 22 testes, OK |
| `python scripts/test_ia_insights_privacidade.py` | 9A: nenhum nome, matrícula, e-mail ou id chega ao provedor; remapeamento dos pseudônimos | 14 testes, OK |
| `python scripts/test_ia_atividade.py` | 9B: contrato, validação do pedido, service sem dados de aluno e sem gravar, retry e falhas | 25 testes, OK |
| `python scripts/test_ia_correcao.py` | 9C: contrato (nota sem clamp, evidência, rubrica), percentual calculado pelo backend, service que não lança nota, retry e falhas | 38 testes, OK |
| `python scripts/test_ia_feedback.py` | 9D: contrato (números do payload, termos proibidos, em andamento), payload sem dado pessoal, service somente leitura e falhas | 39 testes, OK |
| `python scripts/test_ia_erros_internos.py` | Erro interno dos controllers de IA não vira erro de entrada | 10 testes, OK |
| `python scripts/test_migracao_ano_letivo.py` | Migração do ano letivo sobre um banco no formato antigo: preserva dados, é idempotente e retoma uma execução interrompida | 24 verificações, 0 falhas |
| `python scripts/test_migracao_transferencia_aluno.py` | Migração do histórico de turma sobre um banco legado | 8 verificações, 0 falhas |
| `python scripts/test_migracao_professor_habilitado.py` | Migração de `habilitado`: legado, preservação e idempotência | 8 verificações, 0 falhas |
| `flutter test` | Login e primeiro acesso, sessão inválida, limites (429), IA 9A–9D, avisos de exclusão, mensagens de convite, lista de atividades e modelos | 107 testes, OK |
| `flutter analyze` | Análise estática do Flutter | 0 warnings, 0 errors; 101 infos de estilo |

Esses testes cobrem a API e a lógica e a maior parte das telas por testes de widget, não a interface
inteira. O teste manual de ponta a ponta, pelas telas do aplicativo, está previsto no
[roadmap.md](roadmap.md).

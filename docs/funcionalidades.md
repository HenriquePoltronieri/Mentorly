# Funcionalidades

O Mentorly tem hoje **24 funcionalidades demonstráveis**, contadas de forma conservadora: cada
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
| 9 | Gerenciar professor: cadastrar, editar, status, convite e reativação | `cadastroProfessorScreen`, `listaProfessoresScreen` | `ProfessoresService` | `GET`/`POST /api/coordenacao/professores`, `PUT /<id>`, `POST /desativar`, `/reativar`, `/reenviar-convite` | `CadastrarProfessorService`, `ListarProfessoresService`, services de `gerenciar_professor.py` | `Professor` |
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
| 22 | Insights acadêmicos explicáveis da etapa atual | `insightsTurmaScreen` | `InsightsIaService` | `POST /api/professor/turmas/<id>/insights` | `GerarInsightsTurmaService`, `AIClient` | `calculo.py`, `Aluno`, `Turma` |
| 23 | Gerar atividade com IA, revisar e salvar pelo fluxo normal | `gerarAtividadeIaDialog` (dentro de `adicionarAtividadeModal`) | `GeracaoAtividadeIaService` | `POST /api/professor/turmas/<id>/atividades/gerar` | `GerarAtividadeIaService`, `AIClient` | `Turma`, `Etapa`, `Criterio` (a criação usa `Atividade`) |
| 24 | Corrigir resposta discursiva com IA: sugestão revisada pelo Professor, nota lançada pelo fluxo normal | `corrigirRespostaIaDialog` (dentro de `atividadeNotasScreen`) | `CorrecaoAssistidaIaService` | `POST /api/professor/atividades/<id>/correcao-assistida` | `CorrigirRespostaIaService`, `AIClient` | `Atividade`, `Etapa` (a nota é gravada por `LancarNotasService`, não pela IA) |

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
- **IA somente para interpretação.** Recebe resultados já calculados, usa primeiro nome e dados
  acadêmicos mínimos, não escreve no banco e não produz nota, status ou previsão.
- **Bloqueio de alterações em etapa fechada** (atividade e nota), até a Coordenação reabrir.

## Fora da lista

- `GET /api/dashboard/resumo` (totais da escola) existe na API e é testado, mas ainda não tem tela.
- A verificação em duas etapas (`/api/auth/enviar-codigo`, `/confirmar-codigo`) existe no backend e
  no `AuthService`, mas está fora do fluxo de login. A decisão sobre usá-la está em aberto
  ([roadmap.md](roadmap.md)).

## Como chegar em cada tela

**Coordenação** — depois do login, o painel tem os atalhos:

- **Professores** → funcionalidade 8;
- **Gerenciar Turmas** → 4; tocando em uma turma, abrem os alunos → 5, 6 e 7;
- **Vincular Professores** → 9;
- **Anos Letivos** → 2 (cadastrar anos, marcar o atual, encerrar); o menu de cada ano abre a configuração de etapas e critérios daquele ano;
- **Configurar Ano Letivo** → 2 e 3, para o ano atual;
- **Buscar Atividades** → 14;
- **Relatório de Turmas** → 10;
- **Desempenho Acadêmico** → 11.

**Professor** — a barra superior tem **Dashboard** (18), **Turmas** e **Atividades**:

- **Turmas** → turma → alunos (7) → aluno (20), botão **Boletim** (21) e **Insights IA** (22);
- **Atividades** → turma → atividade → lançar, importar e excluir notas (15, 16 e 17); a busca (14)
  fica na própria tela de atividades; em **Adicionar atividade**, o botão **Gerar com IA** (23)
  preenche o formulário com uma sugestão revisada, e quem salva continua sendo o **Adicionar**; na
  tela de notas, o botão ✨ de cada aluno abre a **correção assistida** (24), que só preenche o
  campo de nota, e quem grava continua sendo o **Salvar notas**.

## Situação dos testes

Os testes automáticos abaixo passam no estado atual do repositório (06/10/2026):

| Teste | O que cobre | Resultado |
|---|---|---|
| `python scripts/smoke_db.py` | Escrita, leitura, isolamento por FK composta, regras do ano letivo no banco e procedures | OK |
| `python scripts/smoke_api.py` | API de ponta a ponta, incluindo gestão de Professor e isolamento/acesso/falha da IA | 371 verificações, 0 falhas |
| `python scripts/test_calculo.py` | Regras do motor de cálculo, sem banco | 13 testes, OK |
| `python scripts/test_ia.py` | Payload mínimo, limite, autorização e cliente externo com respostas simuladas | 22 testes, OK |
| `python scripts/test_ia_correcao.py` | Contrato da correção (nota sem clamp, evidência, rubrica), percentual calculado pelo backend, pedido, service que não lança nota, retry e falhas | 38 testes, OK |
| `python scripts/test_ia_atividade.py` | Contrato da atividade gerada, validação do pedido, service sem dados de aluno e sem gravar, retry e falhas | 25 testes, OK |
| `python scripts/test_migracao_ano_letivo.py` | Migração do ano letivo sobre um banco no formato antigo: preserva dados, é idempotente e retoma uma execução interrompida | 24 verificações, 0 falhas |
| `python scripts/test_migracao_transferencia_aluno.py` | Migração do histórico de turma sobre um banco legado: preserva alunos/turmas, cria os vínculos iniciais e é idempotente | 8 verificações, 0 falhas |
| `python scripts/test_migracao_professor_habilitado.py` | Migração de `habilitado`: legado, preservação e idempotência | 8 verificações, 0 falhas |
| `flutter test` | Fluxos anteriores, insights, geração de atividade e correção assistida (model, revisão, duplo toque, usar nota sugerida e erro) | 41 testes, OK |
| `flutter analyze` | Análise estática do Flutter | 0 warnings, 0 errors; 90 infos de estilo |

Esses testes cobrem a API e a lógica, não a interface inteira. O teste manual de ponta a ponta,
pelas telas do aplicativo, está previsto no [roadmap.md](roadmap.md) para 13/10.

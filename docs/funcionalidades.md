# Funcionalidades

O Mentorly tem hoje **20 funcionalidades demonstráveis**, contadas de forma conservadora: cada
linha abaixo tem tela no aplicativo, endpoint na API e regra no backend. Todas passam pelas
camadas explicadas em [architecture.md](architecture.md).

Quando uma linha diz "Repository", o Controller chama `repositories/consultas.py` diretamente, sem
um Service (exceção documentada na arquitetura).

## Coordenação

| # | Funcionalidade | Tela Flutter | Service/Controller Dart | Endpoint | Service backend | Model / Repository |
|---|---|---|---|---|---|---|
| 1 | Cadastro e login da Coordenação (cada cadastro é uma escola) | `cadastroScreen`, `loginScreen` | `AuthService.cadastrarCoordenacao`, `loginCoordenacao` | `POST /api/auth/cadastro-coordenacao`, `/login-coordenacao` | `CadastroCoordenacaoService`, `LoginCoordenacaoService` | `Coordenacao` |
| 2 | Configurar o ano letivo: etapas com nota mínima e máxima | `configEtapasScreen`, `configNotasEtapaScreen` | `EtapasService` | `POST /api/config/etapas`, `POST /api/config/etapas/<id>/notas` | `SalvarEtapaService`, `DefinirNotasEtapaService` | `Etapa` |
| 3 | Critérios de avaliação com pesos (os pesos de uma etapa somam 100) | `configCriteriosScreen` | `CriteriosService` | `/api/config/criterios/...` | `SalvarCriterioService` e demais | `Criterio` |
| 4 | Gerenciar turmas (cadastrar, listar, editar, excluir) | `gerenciarTurmasScreen`, `adicionarTurmaModal` | `TurmasService` | `/api/classes` | funções de `services/turmas.py` | `Turma` |
| 5 | Cadastrar alunos manualmente | `listaAlunosTurmaScreen`, `adicionarAlunosModal` | `AlunosService.listarAlunos` (o cadastro usa o `ApiService` no modal) | `POST /api/coordenacao/turmas/<id>/alunos` | `CadastrarAlunoService` | `Aluno` |
| 6 | Importar alunos por planilha XLSX (modelo para baixar e relatório de erros por linha) | `adicionarAlunosModal` | `ApiService` (envio de arquivo) | `POST /api/coordenacao/turmas/<id>/alunos/importar` | `ImportarAlunosService` | `Aluno` |
| 7 | Editar e excluir aluno | `listaAlunosTurmaScreen`, `editarAlunoModal` | `AlunosService.excluirAluno` | `PUT` e `DELETE /api/coordenacao/alunos/<id>` | `AtualizarAlunoService`, `ExcluirAlunoService` | `Aluno` |
| 8 | Cadastrar professor, com convite para criar a senha | `cadastroProfessorScreen`, `listaProfessoresScreen` | `ProfessoresService` | `GET`/`POST /api/coordenacao/professores` | `CadastrarProfessorService`, `ListarProfessoresService` | `Professor`, `sp_professores_por_coordenacao` |
| 9 | Vincular professores a turmas | `listaTurmasProfessorScreen` | `ProfessorTurmasService` | `GET`/`POST /api/coordenacao/professores/<id>/turmas` | `VincularTurmasService` | `ProfessorTurma` |
| 10 | Relatório de turmas com a contagem de atividades | `relatorioTurmasScreen` | `TurmasService.relatorioTurmasAtividades` | `GET /api/classes/relatorio/atividades` | Repository | `sp_relatorio_turmas_atividades` |
| 11 | Desempenho acadêmico: boletim por turma e fechamento/reabertura de etapa, com aviso de alunos incompletos | `boletimTurmasScreen`, `boletimTurmaScreen` (Coordenação) | `BoletimService`, `EtapasService.fecharEtapa`/`reabrirEtapa` | `GET /api/coordenacao/turmas/<id>/boletim`, `POST /api/config/etapas/<id>/fechar` e `/reabrir` | `montar_boletim_turma`, `FecharEtapaService`, `ReabrirEtapaService` | `calculo.py`, `Etapa` |

## Professor

| # | Funcionalidade | Tela Flutter | Service/Controller Dart | Endpoint | Service backend | Model / Repository |
|---|---|---|---|---|---|---|
| 12 | Primeiro acesso por convite e login | `definirSenhaProfessorScreen`, `professorLoginScreen` | `AuthService.criarSenhaProfessor`, `loginProfessor` | `POST /api/auth/criar-senha-professor`, `/login-professor` | `CriarSenhaProfessorService`, `LoginProfessorService` | `Professor` |
| 13 | Criar, editar e excluir atividade, com etapa, critério e valor máximo | `turmaAtividadesScreen`, `adicionarAtividadeModal` | `AtividadesService` | `POST`, `PUT`, `DELETE /api/activities` | `CreateActivityService`, `UpdateActivityService`, `DeleteActivityService` | `Atividade` |
| 14 | Listar e buscar atividades (por termo, com ordenação) | `listaAtividadesScreen`, `buscarAtividadesScreen` | `AtividadesService.listarAtividades`, `buscarAtividades` | `GET /api/activities`, `GET /api/activities/buscar` | `GetActivitiesService`; a busca usa Repository | `Atividade`, `sp_buscar_atividades` |
| 15 | Lançar notas em lote, com validação do valor máximo | `atividadeNotasScreen` | `AtividadesController.salvarNotas` | `POST /api/atividades/<id>/notas` | `LancarNotasService` | `Nota` |
| 16 | Importar notas por planilha (modelo já preenchido com os alunos) | `lancarNotasModal` | `ApiService` (envio de arquivo) | `POST /api/atividades/<id>/notas/importar` | `ImportarNotasService` | `Nota` |
| 17 | Excluir nota lançada, com confirmação | `atividadeNotasScreen` | `AtividadesController.excluirNota` | `DELETE /api/professor/notas/<id>` | `ExcluirNotaService` | `Nota` |
| 18 | Dashboard com alunos em risco na etapa atual | `dashboardScreen` | `ProfessorDashboardService` | `GET /api/professor/dashboard` | `DashboardProfessorService` | `calculo.py`, `Turma`, `Aluno` |
| 19 | Desempenho do aluno: por etapa, por critério e consolidado | `alunoDetailScreen` | `ProfessorAlunoDetailService` | `GET /api/professor/alunos/<id>/estatisticas` | `EstatisticasAlunoService` | `calculo.py`, `Nota` |
| 20 | Boletim da turma | `boletimTurmaScreen` (Professor) | `BoletimTurmaService` | `GET /api/professor/turmas/<id>/boletim` | `montar_boletim_turma` | `calculo.py`, `Aluno` |

O Professor também edita e exclui aluno nas turmas dele (`PUT`/`DELETE /api/professor/alunos/<id>`,
os mesmos Services da funcionalidade 7), e importa alunos por planilha.

## O que sustenta as funcionalidades (não contado na lista)

- **Isolamento entre escolas.** Nenhuma escola enxerga dados de outra; o banco recusa vínculos
  entre escolas por meio de chaves estrangeiras compostas.
- **Permissões por papel.** A Coordenação não cria atividade nem lança nota, e o Professor não
  gerencia turmas nem configura o ano letivo. Isso responde 403 no backend, mesmo fora do app.
- **Motor de cálculo acadêmico** (`services/academico/calculo.py`): média ponderada por etapa, nota
  ausente diferente de zero, consolidado só com etapas fechadas.
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
- **Configurar Ano Letivo** → 2 e 3;
- **Buscar Atividades** → 14;
- **Relatório de Turmas** → 10;
- **Desempenho Acadêmico** → 11.

**Professor** — a barra superior tem **Dashboard** (18), **Turmas** e **Atividades**:

- **Turmas** → turma → alunos (7) → aluno (19) e botão **Boletim** (20);
- **Atividades** → turma → atividade → lançar, importar e excluir notas (15, 16 e 17); a busca (14)
  fica na própria tela de atividades.

## Situação dos testes

Os testes automáticos abaixo passam no estado atual do repositório (02/10/2026):

| Teste | O que cobre | Resultado |
|---|---|---|
| `python scripts/smoke_db.py` | Escrita, leitura, isolamento por FK composta e procedures | OK |
| `python scripts/smoke_api.py` | A API de ponta a ponta: login, isolamento entre escolas, permissões por papel, configuração do ano letivo, importação de planilha, avaliação, cálculo, boletim e fechamento de etapa, edição/exclusão de aluno e exclusão de nota | 185 verificações, 0 falhas |
| `python scripts/test_calculo.py` | Regras do motor de cálculo, sem banco | 10 testes, OK |
| `flutter test` | Fluxos de login e primeiro acesso, e abertura do app | 6 testes, OK |
| `flutter analyze` | Análise estática do Flutter | 0 warnings, 0 errors (restam infos de estilo) |

Esses testes cobrem a API e a lógica, não a interface inteira. O teste manual de ponta a ponta,
pelas telas do aplicativo, está previsto no [roadmap.md](roadmap.md) para 13/10.

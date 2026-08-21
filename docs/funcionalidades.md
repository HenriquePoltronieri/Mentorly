# Funcionalidades da Entrega

São 10 funcionalidades. Todas passam pelas camadas explicadas em
[arquitetura.md](arquitetura.md).

| # | Funcionalidade | Tela Flutter | Service Dart | Endpoint | Service backend | Model / Repository |
|---|---|---|---|---|---|---|
| 1 | Cadastrar Turma | `adicionarTurmaModal` | `TurmasService.cadastrarTurma` | `POST /api/classes` | `CreateClassService` | `Class.create` (+ `TurmaRepository.find_by_name`) |
| 2 | Listar Turmas | `gerenciarTurmasScreen` | `TurmasService.listarTurmas` | `GET /api/classes` | `GetClassesService` | `Class.find_all` |
| 3 | Atualizar Turma | `adicionarTurmaModal` | `TurmasService.atualizarTurma` | `PUT /api/classes/<id>` | `UpdateClassService` | `Class.update` (+ `TurmaRepository.find_by_name`) |
| 4 | Excluir Turma | `gerenciarTurmasScreen` | `TurmasService.excluirTurma` | `DELETE /api/classes/<id>` | `DeleteClassService` | `Class.delete` |
| 5 | Cadastrar Atividade | `adicionarAtividadeModal` | `AtividadesService.cadastrarAtividade` | `POST /api/activities` | `CreateActivityService` | `Activity.create` |
| 6 | Listar Atividades por Turma | `turmaAtividadesScreen` | `AtividadesService.listarAtividades` | `GET /api/activities?class_id=<id>` | `GetActivitiesService` | `ActivityRepository.find_by_class_id` |
| 7 | Atualizar Atividade | `adicionarAtividadeModal` | `AtividadesService.atualizarAtividade` | `PUT /api/activities/<id>` | `UpdateActivityService` | `Activity.update` |
| 8 | Excluir Atividade | `turmaAtividadesScreen` | `AtividadesService.excluirAtividade` | `DELETE /api/activities/<id>` | `DeleteActivityService` | `Activity.delete` |
| 9 | Buscar Atividades | `buscarAtividadesScreen` | `AtividadesService.buscarAtividades` | `GET /api/activities/buscar` | `SearchActivitiesService` | `ActivityRepository` → `sp_buscar_atividades` |
| 10 | Relatório de Turmas/Atividades | `relatorioTurmasScreen` | `TurmasService.relatorioTurmasAtividades` | `GET /api/classes/relatorio/atividades` | `GetClassReportService` | `TurmaRepository` → `sp_relatorio_turmas_atividades` |

O cadastro e a edição usam o mesmo modal, tanto de turma quanto de atividade. Quando ele
recebe um registro existente, abre com os campos preenchidos e o botão vira "Salvar".

## Como chegar em cada tela

Na tela inicial, use o atalho **"Entrar no painel da coordenação"** (o login ainda não
tem backend). No painel:

- **Gerenciar Turmas** → funcionalidades 1, 2, 3 e 4;
- **Gerenciar Turmas → toque em uma turma** → funcionalidades 5, 6, 7 e 8;
- **Buscar Atividades** → funcionalidade 9;
- **Relatório de Turmas** → funcionalidade 10.

## Situação dos testes

**As 10 funcionalidades foram testadas pela interface do aplicativo.**

| Funcionalidades | Situação |
|---|---|
| 1 a 8 | Testadas pela interface. Cadastramos uma turma, editamos, criamos uma atividade nela, editamos, e depois excluímos as duas. Tudo funcionou e a lista se atualizou sozinha em cada operação. |
| 9 e 10 | Testadas com **MySQL 8.4** e as Stored Procedures instaladas. Criamos uma turma e uma atividade pela tela, a busca encontrou a atividade pelo termo e o relatório mostrou a turma com a contagem certa de atividades. |

Vale registrar como sabemos que a procedure da busca realmente rodou: o resultado na tela
mostra o nome da turma junto de cada atividade, e esse campo (`class_name`) só existe
porque a `sp_buscar_atividades` faz um LEFT JOIN com a tabela `classes`. A resposta comum
do endpoint de atividades não traz esse campo.

O backend compila sem erro (`python -m compileall backend`) e o `flutter analyze` não
aponta nenhum erro.

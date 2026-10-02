# SIMPLIFICAÇÃO TÉCNICA — MENTORLY

## 1. Estado inicial

O projeto estava funcional, mas com repasses em cadeia e arquivos pequenos que
apenas encaminhavam chamadas. O backend tinha repositories e services de uma
camada extra para consultas simples; o Flutter mantinha componentes e modelos
sem consumidores.

## 2. Principais fontes de complexidade

- `Route → Controller → Service → Repository` para cinco consultas que apenas
  chamavam uma procedure.
- Cinco classes de CRUD de turma, cada uma em seu arquivo, sem estado próprio.
- Comentários históricos muito extensos e alguns desatualizados.
- Controller de autenticação que apenas capturava exceções e repassava ao
  `AuthService`.
- Nove arquivos Flutter sem referência de código ativa.
- Dois métodos de model e dois métodos do controller Flutter sem consumidores.

## 3. Backend simplificado

- Criado `backend/repositories/consultas.py` com cinco funções explícitas para
  procedures; os controllers usam essas funções diretamente.
- Criado `backend/services/turmas.py` com `listar_turmas`, `buscar_turma`,
  `criar_turma`, `atualizar_turma` e `excluir_turma`, preservando as validações.
- O cálculo acadêmico em `services/academico/calculo.py` recebeu um docstring
  curto e uma montagem de resultado sem repetições; a fórmula e o arredondamento
  intermediário foram mantidos.
- Removidos `__init__` vazios e comentários que só descreviam o código.
- Removidos `Etapa.nota_minima_da_escola`, `Nota.media_por_atividade` e
  `Nota.lancar`: não havia referências no backend.

## 4. Flutter simplificado

- Login e primeiro acesso do professor chamam `AuthService` diretamente; o
  controller intermediário foi removido.
- Removidos comentários que diziam que o cálculo vinha de `GradeCalculator`.
- Retirados modelos/widgets sem consumidores e o service de IA que era apenas
  um placeholder sem rota ou tela correspondente.
- Removidos `somaPesos` e `resetar` do controller de configuração, sem chamadas.
- Criados testes de widget para sucesso, erro, sessão persistida e token ausente.

## 5. Código morto removido

`GradeCalculator`, `LoadingIndicator`, `ProfessorCard`, `TurmaCard`,
`ProfessorModel`, `AlunoModel`, `EscolaModel`, `IaInsightsService`,
`AuthController`, os seis services de turma antigos, `SearchActivitiesService`,
`GetSystemSummaryService` e `GetClassReportService`, além dos quatro
repositories de consulta individuais. Também foram removidos os métodos Python
sem referências citados na seção 3.

## 6. Camadas removidas ou reduzidas

Os repasses sem regra foram reduzidos para `Controller → função explícita →
Model/procedure`. O CRUD de turma passou de cinco classes para um módulo com
cinco operações nomeadas. Isso reduz arquivos e navegação sem criar uma camada
genérica.

## 7. Camadas mantidas

Controllers continuam tratando HTTP e status. Services que validam autorização,
coordenam várias consultas, executam transações ou calculam notas foram mantidos.
Models continuam concentrando SQL e serialização; `ApiService`, `AuthService`,
JWT, decorators e procedures continuam nos seus papéis atuais.

## 8. Regras de negócio preservadas

O isolamento por `coordenacao_id`, o vínculo Professor–Turma e Aluno–Turma,
JWT, autorização de escrita, FKs, constraints, transações, validação de nota
máxima, etapas/critérios e todas as regras de notas e dashboard permaneceram.
Nota ausente continua diferente de zero e o motor acadêmico continua central.

## 9. Antes x depois

```text
Antes:  Controller → SearchActivitiesService → ActivityRepository → procedure
Depois: Controller → consultas.buscar_atividades → procedure

Antes:  Controller → cinco ClassServices → Model
Depois: Controller → services.turmas.criar_turma (e demais operações) → Model
```

## 10. Arquivos removidos

Consulte a seção 5; são 36 arquivos/métodos no total entre backend e Flutter.
Nenhum arquivo de schema ou procedure ativa foi removido.

## 11. Arquivos alterados

Controllers de atividade, turma e dashboard; motor acadêmico; models de etapa e
nota; services de professores e dashboard; duas telas de autenticação; controller
de configuração; comentário da tela de alunos; `README.md`. Foram adicionados
`repositories/consultas.py`, `services/turmas.py`, `scripts/test_calculo.py` e
`test/auth_flow_test.dart`.

## 12. Testes

```text
smoke_db:       OK — escrita, leitura, isolamento e procedures
smoke_api:      OK — 119 verificações, 0 falhas
flutter analyze: 71 infos, 0 warnings, 0 errors (exit 1 por infos existentes)
flutter test:   OK — 6 testes (inclui os 5 novos fluxos de autenticação)
py_compile:     OK — todos os arquivos Python
```

Os smokes foram executados em banco temporário e o banco original foi preservado.
O cálculo também foi comparado com a versão anterior em 1.000 casos mockados,
com resultados idênticos.

## 13. Regressões

Nenhuma regressão encontrada. URLs, JSON e status HTTP não foram alterados.

## 14. Complexidade restante

O motor acadêmico, decorators de autorização, procedures, transações e consultas
de importação continuam relativamente detalhados porque implementam segurança,
integridade ou regra de negócio real. Telas Flutter grandes também foram mantidas
quando concentram um fluxo de formulário completo.

## 15. Avaliação final

Notas de 0 a 10 (em complexidade, nota maior significa simplicidade):

```text
Legibilidade:             8
Facilidade de explicar:   8
Complexidade:             8
Organização:              8
Manutenibilidade:         8
```

O Mentorly está preparado para iniciar o Marco 3 sem introduzir framework,
gerenciador de estado ou padrão arquitetural novo.

# Roadmap do Mentorly

Este roadmap organiza o estado atual, os próximos passos e as decisões estruturais do Mentorly.

O desenvolvimento planejado deve estar concluído até **20/10/2026**. As duas semanas seguintes ficam reservadas para estudo do código, preparação da apresentação e ensaios.

A seção 6 preserva o plano original em 13 fases. Itens adiados não foram removidos do projeto: continuam documentados e só mudaram de prioridade.

---

# 1. Estado atual

## Marco 1 — Avaliação funcionando
**Status: ✅ Concluído**

> Professor cria uma atividade com etapa + critério + valor e lança notas válidas.

- criar atividade;
- escolher etapa;
- escolher critério;
- definir nota máxima;
- lançar notas;
- importar notas por planilha.

## Marco 2 — Desempenho funcionando
**Status: ✅ Concluído**

> Mentorly calcula corretamente a média por etapa e identifica alunos abaixo do mínimo.

- motor acadêmico centralizado (`services/academico/calculo.py`);
- normalização das notas e critérios ponderados;
- média por etapa, com nota mínima e máxima de cada etapa;
- distinção entre nota zero e nota ausente;
- identificação de alunos abaixo do mínimo no dashboard do Professor.

## Marco 3 — Ciclo escolar funcionando
**Status: ✅ Concluído**

> Coordenação configura → professor avalia → aluno recebe resultado → dashboard/boletim refletem tudo corretamente.

- boletim do aluno e boletim da turma;
- consolidado geral (só com etapas fechadas e completas);
- fechamento e reabertura de etapa pela Coordenação;
- bloqueio de alterações acadêmicas em etapa fechada.

## Marco 4 — Gerenciamento de alunos e correções
**Status: ✅ Concluído**

- edição de aluno;
- exclusão de aluno;
- **A04** — importação de notas deixou de escolher aluno errado por nome ambíguo;
- **A01** — `SECRET_KEY` sem valor padrão fixo;
- **A02** — correção do arredondamento intermediário no cálculo da etapa;
- aviso de alunos incompletos no fechamento de etapa.

## Marco 5 — Exclusão de nota
**Status: ✅ Concluído**

- exclusão explícita de nota lançada;
- confirmação antes da exclusão;
- bloqueio em etapa fechada;
- atualização automática da tela;
- proteção contra duplo toque;
- autorização por Professor, turma e escola.

## Marco 6 — Ano letivo completo
**Status: ✅ Concluído**

> O ano letivo deixa de ser um número solto e passa a ser um cadastro de cada escola, que controla turmas, etapas, etapa atual, dashboard e boletim.

- tabela `ano_letivo (id, coordenacao_id, ano, status)`, com os estados `planejamento`, `atual` e `encerrado`;
- um único ano `atual` por escola, garantido pelo próprio MySQL;
- `turma.ano_letivo` e `etapa.ano_letivo` viraram chave estrangeira composta para o cadastro de anos da escola (turma sem ano deixou de existir);
- migration idempotente que preserva os dados existentes;
- `date.today().year` deixou de decidir o ano acadêmico em todos os pontos mapeados;
- dashboard, boletim, desempenho do aluno e etapa atual usam o ano correto;
- atividade só aceita etapa do mesmo ano da turma;
- gestão de anos letivos pela Coordenação (API e tela Flutter); o Professor não administra anos.

---

# 2. Estado técnico validado

Verificação mais recente (03/10/2026, depois do Marco 9):

| Verificação | Resultado |
|---|---|
| `py_compile` | 97 arquivos, OK |
| `smoke_db` | OK |
| `smoke_api` | 298 verificações, 0 falhas |
| `test_calculo` | 13 testes, OK |
| `test_ia` | 14 testes, OK; cliente externo simulado, sem internet |
| `test_migracao_ano_letivo` | 24 verificações, 0 falhas |
| `test_migracao_transferencia_aluno` | 8 verificações, 0 falhas |
| `test_migracao_professor_habilitado` | 8 verificações, 0 falhas |
| `flutter analyze` | 0 warnings, 0 errors; 90 infos de estilo (`file_names`, `withOpacity` e afins) |
| `flutter test` | 21 testes, todos passando |

A auditoria não encontrou regressões críticas ou importantes nos Marcos 1 a 5. No Marco 6, o código novo foi comparado com o antigo sobre os dados reais de desenvolvimento: dashboard, boletim, desempenho do aluno, médias e etapas saíram idênticos, e as únicas diferenças foram o ano letivo agora explícito.

Por contagem conservadora, o Mentorly possui hoje **22 funcionalidades demonstráveis de MVP** (lista em [funcionalidades.md](funcionalidades.md)).

A integração externa da IA está implementada com Mistral Small como padrão; falta configurar uma
chave no ambiente e executar a chamada real controlada antes da demonstração.

---

# 3. Checkpoint da disciplina

A etapa atual da disciplina exige:

- arquitetura proposta na disciplina;
- separação adequada de responsabilidades entre camadas;
- aplicação dos princípios de qualidade;
- aplicação dos princípios SOLID estudados;
- repositório atualizado;
- commits e arquivos enviados corretamente;
- professor com acesso ao repositório.

## Checklist

- [x] revisar arquitetura atual;
- [x] revisar separação entre camadas;
- [x] revisar responsabilidades dos services/controllers/models;
- [x] revisar SOLID;
- [x] atualizar `architecture.md`;
- [x] atualizar `funcionalidades.md`;
- [x] atualizar `visao-geral.md`;
- [x] revisar `README.md`;
- [x] revisar `git status` e `git diff`;
- [x] verificar arquivos sensíveis;
- [x] organizar commits;
- [x] realizar push;
- [ ] conferir os arquivos no repositório remoto;
- [ ] confirmar acesso do professor ao repositório.

## Arquitetura atual

```text
FLUTTER
Screen
  ↓
Controller / Service (Dart)
  ↓
ApiService
  ↓
FLASK
Route
  ↓
Controller
  ↓
Service
  ↓
Model / Repository
  ↓
MySQL
```

- **Route:** declara o endereço e o decorator de papel (`@auth_required`, `@coordenacao_required`, `@professor_required`).
- **Controller:** lê a requisição, chama o Service e devolve o código HTTP.
- **Service:** regras de negócio e autorização por escola/turma; um Service por caso de uso na maior parte do código.
- **Model:** SQL escrito à mão (PyMySQL) de uma entidade.
- **Repository:** apenas `repositories/consultas.py`, para as consultas que chamam procedures.

### Exceções conhecidas

A arquitetura segue esse fluxo na maior parte do projeto, mas **não é uma separação absolutamente rígida**. A auditoria encontrou pequenas exceções, que estão registradas aqui em vez de escondidas:

- **Controller → Model (4 pontos):** `class_controller.py` (ramo do Professor em `list_classes` e `get_class`) e `boletim_turma` em `coordenacao_controller.py` e `professor_controller.py`, que consultam `Turma` diretamente para validar acesso.
- **Controller → Repository (3 pontos):** `activity_controller.py`, `class_controller.py` e `dashboard_controller.py` chamam `repositories/consultas.py` sem um Service intermediário (simplificação intencional, descrita em [simplificacao-tecnica.md](simplificacao-tecnica.md)).
- **Estilo dos Services:** `services/turmas.py` é um módulo de funções; os demais Services são classes com `execute()`.
- **Flutter:** `adicionarAlunosModal`, `editarAlunoModal` e `lancarNotasModal` usam o `ApiService` diretamente, sem um Service Dart intermediário.

Essas exceções são pequenas e **não colocam regra de negócio pesada na interface**: as telas só exibem o que o backend calcula. Elas podem ser reavaliadas depois do Git organizado, se forem importantes para o checkpoint.

### SOLID, em termos proporcionais ao projeto

- **SRP:** Services por caso de uso, SQL concentrado nos Models, cálculo acadêmico concentrado em `calculo.py`.
- **OCP:** um caso de uso novo costuma virar Service + método de Controller + rota, sem reescrever o resto.
- **LSP:** não se aplica de forma relevante, pois não há herança significativa.
- **ISP:** cada Service expõe só `execute()`.
- **DIP:** os Services dependem diretamente dos Models concretos. O acoplamento é intencional e simples, adequado ao porte do projeto.

---

# 4. Plano final até a apresentação

| Etapa | Período |
|---|---|
| Etapa 0 — Git e checkpoint | 02/10 – 03/10 |
| Marco 6 — Ano letivo completo ✅ | 03/10 – 06/10 |
| Marco 7 — Transferência de aluno com histórico | 06/10 – 08/10 |
| Marco 8 — Gestão completa de professores | 08/10 – 10/10 |
| Marco 9 — IA | 10/10 – 12/10 |
| Teste manual E2E | 13/10 |
| Correção de UX/bugs | 14/10 – 16/10 |
| Documentação final | 16/10 – 17/10 |
| Git final | 17/10 |
| Auditoria final | 18/10 |
| Correções finais | 19/10 – 20/10 |
| Congelamento | 20/10 |
| Buffer | 21/10 – 22/10 |
| MVP | 23/10 |
| Revisão | 30/10 |
| Apresentação | 07/11 |

## Período de estudo

De **21/10 a 06/11**, o desenvolvimento normal está encerrado. A prioridade passa a ser:

- estudar o código;
- estudar a arquitetura;
- revisar SOLID;
- preparar a demonstração;
- ensaiar a apresentação.

## Marco 6 — Ano letivo completo
**03/10 – 06/10 · ✅ concluído**

Modelagem (decisão estrutural herdada do plano original, adaptada ao código):

```text
ano_letivo
id
coordenacao_id
ano                       UNIQUE (coordenacao_id, ano)
status                    planejamento | atual | encerrado
```

- **Fonte de verdade do ano:** o cadastro `ano_letivo` da escola. `turma.ano_letivo` e `etapa.ano_letivo` continuam guardando o número do ano, mas agora esse número é chave estrangeira composta `(coordenacao_id, ano_letivo)` para o cadastro: o banco recusa turma ou etapa de um ano que a escola não tem e nunca cruza escolas. Não há um segundo campo para o mesmo dado.
- **Um ano atual por escola:** coluna gerada `atual_unico` com índice único. Dois anos `atual` na mesma escola são recusados pelo MySQL, sem trigger.
- **Contexto padrão:** sem ano informado, vale o ano atual da escola. `date.today()` continua sendo usado só para datas (por exemplo, escolher entre as etapas de um ano), nunca para decidir qual é o ano acadêmico.
- **Ano encerrado** mantém os dados e só deixa de receber turma e etapa novas. **Ano em planejamento** aceita turmas e etapas, mas não vira o contexto do dashboard enquanto não for o atual.
- **Atividade** só aceita etapa do mesmo ano letivo da turma.
- **Turma** só muda de ano enquanto não tiver atividades.

Os pontos que usavam `date.today().year` foram corrigidos:

- `boletim.py` — usa o ano da própria turma;
- `etapas.py` — etapa nova usa o ano atual da escola; listagem sem ano traz só o ano atual; contagem de alunos incompletos considera só turmas do mesmo ano da etapa;
- `professor/dashboard.py` — usa o ano atual da escola (ou o ano pedido) e só conta turmas desse ano;
- `professor/estatisticas_aluno.py` — usa o ano da turma do aluno;
- `professor/listar_turmas.py` — usa o ano da turma;
- `etapa_atual` e `calcular_todas_etapas` em `calculo.py` — exigem o ano e nunca listam etapas de todos os anos.

Encerrar o ano é só trocar o status: **não** há promoção automática de alunos, transferência nem criação automática de turmas do próximo ano. Isso pertence ao Marco 7 e à evolução futura.

Detalhes técnicos e a migração estão em [banco-e-procedures.md](banco-e-procedures.md).

## Marco 7 — Transferência de aluno com histórico
**06/10 – 08/10 · ✅ concluído**

`aluno.turma_id` continua sendo a referência rápida da turma atual, para manter as listas,
dashboard, boletim e autorização do Professor compatíveis. A trilha é `aluno_turma_historico`:
cada aluno tem um vínculo aberto, que a transferência fecha antes de criar o vínculo da nova turma.
As três escritas acontecem na mesma transação.

- a transferência é exclusiva da Coordenação e usa a escola do JWT;
- origem e destino precisam pertencer à mesma escola;
- destino do mesmo ano ou de ano `planejamento`/`atual` é permitido; ano encerrado é bloqueado;
- notas e atividades antigas não são reatribuídas; o desempenho atual considera apenas a turma atual;
- cadastro manual e importação criam o primeiro vínculo; excluir aluno remove o histórico por cascade.

O histórico pode ser consultado pela Coordenação na lista de alunos. A migration cria, sem
duplicar, o vínculo inicial dos alunos já existentes usando turma, ano letivo e data de criação.

## Marco 8 — Gestão completa de professores
**08/10 – 10/10 · ✅ concluído, migrado no banco real e publicado**

- `professor.habilitado` é o estado administrativo persistido; a migration idempotente deixa todos os registros legados habilitados;
- `ativo` continua compatível e significa apenas que a senha foi criada; a API também devolve `status`: `convite_pendente`, `ativo` ou `desativado`;
- a Coordenação edita nome, email e disciplina, reenvia convite apenas para conta pendente, consulta e gerencia turmas, desativa e reativa;
- desativar não apaga vínculos, atividades, notas nem histórico; o login e todo endpoint de Professor conferem `habilitado`, inclusive para JWT emitido antes da desativação;
- a Coordenação e as turmas são sempre validadas pela escola do JWT; Professor não acessa endpoints administrativos.

Decisão mantida: **não excluir fisicamente professor que já tem histórico.** A migration foi aplicada no banco real com backup e validação antes da publicação.

## Marco 9 — IA
**10/10 – 12/10 · ✅ concluído em código e testes; configuração externa pendente no ambiente**

**Escopo:** insights acadêmicos explicáveis para o Professor.

```text
motor acadêmico
      ↓
dados confiáveis
      ↓
service de IA
      ↓
modelo
      ↓
insight textual
```

A IA **não** calcula nota, **não** altera nota, **não** decide aprovação, **não** fecha etapa e **não** substitui `calculo.py`.

Implementação: `GerarInsightsTurmaService` valida JWT, vínculo e escola, usa a etapa atual do ano
da turma e chama `calcular_desempenho_etapa`. O `AIClient` envia um JSON limitado a um provedor
compatível com chat completions e valida a resposta estruturada. O Flutter só chama pelo botão
**Gerar insights**. Não há persistência; falha externa retorna mensagem amigável e não afeta o
restante do produto. O padrão é `mistral-small-latest`, com URL e modelo substituíveis por
variáveis de ambiente.

Dados enviados nesta versão: turma, ano, etapa, escala oficial, agregados da turma e, por aluno,
primeiro nome, percentual, nota calculada, situação, completude, contagens de atividades e
desempenho por critério. Email, matrícula, ids do banco e histórico bruto não são enviados.

Seguindo o plano original, a prioridade são insights explicáveis sobre dados existentes, e não previsões opacas como "IA prevê reprovação".

---

# 5. Itens estruturais que não podem sumir

### Ano letivo real
Implementado no Marco 6. Continua sendo a base do histórico: o Marco 7 (transferência) vai se apoiar nele para registrar de qual turma e de qual ano o aluno veio.

### Transferência com histórico
Não permitir implementação ingênua (ver Marco 7).

### `nota_historico`
Continua como evolução futura:

```text
nota_historico

id
nota_id
valor_anterior
valor_novo
professor_id
alterado_em
```

Hoje a mitigação é parcial: o fechamento de etapa impede alterar ou excluir nota sem uma reabertura explícita, mas a alteração em si não deixa trilha.

### A06 — autoria
Pergunta ainda **sem resposta** (não resolver agora):

> Professores da mesma turma podem alterar atividades/notas criadas por outro Professor?

Hoje a regra é por vínculo com a turma, não por autoria.

### Soft-delete de professor
Manter a decisão: desativar em vez de excluir (ver Marco 8).

### 2FA
Decisão pendente:

- obrigatório?
- opcional?
- apenas Coordenação?

A infraestrutura (`/api/auth/enviar-codigo`, `/api/auth/confirmar-codigo` e `twoFactorScreen`) existe, mas está fora do fluxo de login. Para o MVP, a recomendação do plano original é opcional ou somente para a Coordenação.

### Fórmula acadêmica
Preservar a regra:

```text
desempenho = pontos_obtidos / pontos_possiveis
```

aplicada por critério, com o peso do critério, somando as contribuições e multiplicando pela nota máxima da etapa. **Sem arredondamento intermediário:** o arredondamento acontece uma única vez, no resultado final. Nota ausente é diferente de zero: a etapa só recebe resultado quando todos os critérios com peso positivo estão completos e os pesos somam 100.

---

# 6. Plano original (Fases 1 a 13)

O texto abaixo é o roadmap original, mantido como histórico e com o status de cada fase atualizado em 02/10/2026.

---

## Fase 1 — Fechar o núcleo acadêmico

**Status: ✅ concluída (Marco 1).** Atividade ligada a etapa e critério, com valor máximo validado no backend e FKs compostas que impedem cruzar escolas.
**Prioridade: crítica**

Objetivo: fazer uma atividade representar corretamente uma avaliação dentro de uma etapa.

### 1.1 Vincular atividade à etapa

Adicionar/validar:

- `atividade.etapa_id`
- FK para `etapa`
- etapa obrigatoriamente da mesma escola/turma
- professor só pode escolher etapas da escola dele
- frontend precisa exibir seletor de etapa

Exemplo:

```text
Prova de Matemática
Turma: 2º A
Etapa: 1º Bimestre
```

**Critério de pronto:**

- professor cria atividade escolhendo uma etapa;
- recarrega a página;
- atividade continua ligada à etapa;
- outro professor/escola não consegue usar a etapa.

### 1.2 Nota máxima da atividade

Adicionar ao modal:

```text
Valor da atividade: 20 pontos
```

Backend deve validar:

```text
nota_maxima > 0
```

Depois:

```text
Aluno recebe 18/20 → permitido
Aluno recebe 20/20 → permitido
Aluno recebe 21/20 → bloqueado
Aluno recebe -1 → bloqueado
```

**Critério de pronto:** nenhuma atividade acadêmica nova pode nascer com `nota_maxima = 0`.

### 1.3 Vincular atividade ao critério

Professor deve escolher um critério já configurado pela escola:

```text
Tipo:
○ Prova
○ Trabalho
○ Participação
```

Estrutura:

```text
Escola
└── Critérios
     ├── Prova
     ├── Trabalho
     └── Participação

Atividade
→ etapa
→ critério
```

A Coordenação define os critérios; o Professor utiliza, não redefine o padrão da escola.

---

## Fase 2 — Corrigir cálculo de notas

**Status: ✅ concluída (Marco 2; arredondamento intermediário corrigido no Marco 4, A02).** Regra implementada em `backend/services/academico/calculo.py`; explicação em [banco-e-procedures.md](banco-e-procedures.md).
**Prioridade: crítica**

Hoje este é o ponto que impede o dashboard de representar corretamente o desempenho.

### 2.1 Definir uma regra matemática oficial

Antes de codificar mais, documentar exatamente como o Mentorly calcula nota.

Exemplo:

```text
1º Bimestre = 25 pontos

Provas = 60%
Trabalhos = 30%
Participação = 10%
```

É preciso decidir como atividades com valores diferentes entram nesse cálculo.

Recomendação: normalizar cada critério:

```text
desempenho = pontos obtidos / pontos possíveis
```

Depois aplicar peso:

```text
nota_etapa =
(provas_normalizadas × peso_provas)
+ (trabalhos_normalizados × peso_trabalhos)
+ (participação_normalizada × peso_participação)
```

Essa regra deve ser explícita e documentada.

### 2.2 Implementar peso dos critérios

Hoje `criterio.peso` aparentemente existe, mas não participa da média.

Precisa passar a participar.

Teste mínimo:

```text
Prova = 70%
Trabalho = 30%

Aluno:
Prova = 8/10
Trabalho = 10/10
```

Resultado esperado:

```text
8 × 0,70 + 10 × 0,30 = 8,6
```

ou o equivalente na escala utilizada pela escola.

### 2.3 Média por etapa

A média deve ser calculada separadamente:

```text
Aluno João
├── 1º Bimestre → 18/25
├── 2º Bimestre → 21/25
├── 3º Bimestre → ...
└── 4º Bimestre → ...
```

Nunca usar a nota mínima da primeira etapa como referência universal.

Cada etapa deve usar:

- suas atividades;
- seus critérios;
- seus pesos;
- sua nota máxima;
- sua nota mínima.

---

## Fase 3 — Tornar notas realmente completas

**Status: 🟡 quase toda concluída.** 3.1 (lançamento em lote) ✅ e 3.2 (importação XLSX, com a ambiguidade por nome corrigida no Marco 4, A04) ✅. A exclusão explícita de nota entrou no Marco 5. **3.3 (`nota_historico`) segue pendente** — ver seção 5.
**Prioridade: crítica**

### 3.1 Tela de lançamento de notas

Fluxo final:

```text
Professor
→ Minhas turmas
→ Turma
→ Atividades
→ Prova 1
→ Lançar notas
```

Tabela esperada:

| Aluno | Nota | Máximo |
|---|---:|---:|
| João Silva | 17 | 20 |
| Maria Souza | 19 | 20 |

Adicionar:

- validação;
- salvar em lote;
- feedback de erro;
- estado "não lançado";
- edição posterior.

### 3.2 Importação de notas por XLSX

Completar o fluxo:

```text
Baixar modelo
→ arquivo já vem com os alunos
→ professor preenche notas
→ upload
→ validação
→ relatório
```

Retorno ideal:

```text
24 notas atualizadas
2 erros

Linha 8 — nota acima de 20
Linha 17 — aluno não encontrado
```

### 3.3 Auditoria de alterações de nota

Adicionar histórico, não apenas `updated_at`.

Estrutura sugerida:

```text
nota_historico

id
nota_id
valor_anterior
valor_novo
professor_id
alterado_em
```

Isso é especialmente importante em um sistema escolar.

---

## Fase 4 — Fechar o ciclo da etapa

**Status: ✅ concluída (Marco 3).** Boletim da turma (Professor e Coordenação), consolidado geral, fechamento/reabertura de etapa pela Coordenação e detalhe do aluno por etapa.

Aqui o Mentorly começa a virar produto acadêmico de verdade.

### 4.1 Boletim da etapa

Criar endpoint equivalente a:

```text
GET /api/professor/turmas/{id}/boletim
```

Retornar por aluno:

```text
João Silva

1º Bimestre
Provas: 70%
Trabalhos: 30%

Média: 7,8
Situação: Acima da média mínima
```

### 4.2 Fechamento da etapa

Decidir se haverá conceito de:

```text
Etapa aberta
Etapa fechada
```

Isso ajuda a impedir edição acidental de notas antigas.

Fluxo:

```text
1º Bimestre
Status: aberto

Coordenação/Professor autorizado
→ fecha etapa

Status: fechado
```

Depois definir claramente quem pode reabrir.

Recomendação: dar essa autoridade principalmente à Coordenação.

### 4.3 Detalhe do aluno

Transformar a tela atual em algo como:

```text
Aluno: João Silva
Turma: 2º A

Média atual: 7,4
Situação: Atenção

1º Bimestre  ████████ 8,2
2º Bimestre  ██████   6,5
3º Bimestre  ...
```

Além de:

- atividades;
- notas;
- evolução;
- critérios;
- situação por etapa.

---

## Fase 5 — Corrigir o Dashboard

**Status: ✅ concluída (Marco 2).** O dashboard do Professor calcula "aluno em risco" com o motor central, na etapa atual da escola.

**Só agora**, porque antes os dados não são academicamente confiáveis.

### Dashboard do Professor

Mostrar somente seus dados:

```text
Minhas turmas: 4
Meus alunos: 103
Atividades abertas: 7
Alunos em atenção: 12
```

E:

```text
Alunos em risco
├── João — 1º Bimestre — 5,2
├── Ana — 1º Bimestre — 4,8
└── Carlos — 2º Bimestre — 5,0
```

### Regra de aluno em risco

Deixar de usar regra simplificada.

Regra inicial sugerida:

```text
média da etapa < nota mínima da etapa
```

Mais tarde pode ser sofisticada.

---

## Fase 6 — Completar gestão de alunos

**Status: ✅ concluída.** Editar e excluir aluno foram concluídos no Marco 4; transferência
com histórico foi concluída no Marco 7.

Implementar:

- editar aluno;
- excluir aluno;
- transferir aluno;
- visualizar dados completos;
- matrícula;
- email, se necessário.

### Transferência

Evitar simplesmente alterar `turma_id` sem histórico.

Ideal:

```text
Aluno João
2026 → 1º A
2027 → 2º A
```

Isso leva à necessidade futura de matrícula/ano letivo.

---

## Fase 7 — Melhorar o modelo de ano letivo

**Status: ✅ concluída (Marco 6).** O ano letivo é um cadastro de cada escola e controla turmas, etapas, etapa atual, dashboard e boletim — ver seção 4.

Hoje o sistema aparentemente usa sempre o ano corrente.

Criar conceito real de:

```text
AnoLetivo
id
coordenacao_id
ano
status
```

Exemplo:

```text
2025 — Encerrado
2026 — Atual
2027 — Planejamento
```

Relacionar:

```text
Ano letivo
├── etapas
├── turmas
├── vínculos
└── dados acadêmicos
```

Isso evita misturar dados de anos diferentes.

---

## Fase 8 — Completar gestão de professores

**Status: ✅ concluída (Marco 8).** A Coordenação administra cadastro, edição, convite pendente,
vínculos, desativação e reativação. `habilitado` é separado de `senha_hash`, portanto uma conta
pendente não é confundida com uma conta desativada e um JWT antigo perde acesso após desativação.

Professor, atividades, notas e vínculos não são excluídos nessa operação.

---

## Fase 9 — Recuperação de senha e segurança

**Status: ⏳ pendente.** Recuperação de senha não consta nos marcos planejados até 20/10 (será reavaliada depois do Marco 9). A infraestrutura de 2FA existe, mas está fora do fluxo de login; a decisão continua em aberto (seção 5).

### Recuperação de senha

Fluxo:

```text
Esqueci minha senha
→ email
→ token temporário
→ nova senha
```

Endpoints sugeridos:

```text
POST /api/auth/recuperar-senha
POST /api/auth/redefinir-senha
```

Implementar:

- token único;
- expiração;
- invalidação após uso;
- resposta que não revele se email existe.

### 2FA

A infraestrutura aparentemente existe, mas está fora do fluxo.

Decidir:

- obrigatório?
- opcional?
- somente Coordenação?

Para TCC/MVP, recomendação: opcional ou somente Coordenação.

---

## Fase 10 — Testes de verdade

**Status: 🟡 parcial.** Existem `smoke_db`, `smoke_api` (298 verificações), `test_calculo`
(13 testes), `test_ia` (14 testes), três testes de migration (24, 8 e 8 verificações) e
`flutter test` (21 testes). Uma suíte estruturada por módulo continua como evolução.

Os smoke tests são úteis, mas é importante começar uma suíte estruturada.

### Backend

Criar testes para:

- autenticação;
- autorização;
- isolamento;
- professor-turma;
- alunos;
- atividades;
- etapas;
- critérios;
- notas;
- cálculos.

Principalmente casos negativos:

```text
Escola A → aluno Escola B ❌
Professor A → turma Professor B ❌
Coordenação → criar atividade ❌
Professor → nota acima do limite ❌
Aluno de outra turma → receber nota ❌
```

### Flutter

Testes pelo menos de:

- login;
- configuração acadêmica;
- criação de turma;
- criação de atividade;
- lançamento de nota.

---

## Fase 11 — Limpeza técnica

**Status: 🟡 parcial.** Já feito: ORM antigo removido, código morto removido (ver [simplificacao-tecnica.md](simplificacao-tecnica.md)), bypass de login removido, `SECRET_KEY` sem valor padrão fixo, `backend/.env` ignorado pelo Git. Pendente: URL da API por ambiente, padronização de nomes de arquivo Dart e tratamento de erros mais uniforme.

Quando o domínio estiver estável:

- remover SQLAlchemy antigo se realmente não for mais utilizado;
- remover tabelas `users/classes/activities` antigas se sobraram;
- remover controllers/services mortos;
- remover bypass de login;
- remover telas órfãs;
- padronizar nomes;
- corrigir URLs por ambiente;
- configurar `.env`;
- remover segredos hardcoded;
- melhorar tratamento de erros.

Isso deve ser feito depois de confirmar qual arquitetura venceu.

---

## Fase 12 — Preparar apresentação/TCC

**Status: ⏳ pendente.** As etapas do fluxo abaixo existem no app e na API (a API é coberta por `smoke_api`). O teste manual de ponta a ponta está previsto para 13/10 e o roteiro do vídeo ainda precisa ser refeito.

O fluxo demonstrável deveria ser:

```text
COORDENAÇÃO
    ↓
Cria conta
    ↓
Configura ano letivo
    ↓
Define etapas
    ↓
Define critérios/pesos
    ↓
Cria turma
    ↓
Adiciona alunos
    ↓
Cadastra professor
    ↓
Vincula professor

PROFESSOR
    ↓
Recebe convite
    ↓
Define senha
    ↓
Faz login
    ↓
Vê somente suas turmas
    ↓
Cria atividade
    ↓
Escolhe etapa
    ↓
Escolhe critério
    ↓
Define valor
    ↓
Lança notas

MENTORLY
    ↓
Calcula média
    ↓
Mostra desempenho
    ↓
Identifica alunos em risco
    ↓
Gera boletim
```

Se isso estiver estável, o projeto terá uma demonstração muito forte.

---

## Fase 13 — IA

**Status: ✅ concluída em código e testes (Marco 9).** A chamada real controlada depende da chave
do provedor no ambiente de demonstração.

Somente depois do ciclo acadêmico estar confiável.

A IA então poderá utilizar:

```text
Aluno
├── histórico
├── notas
├── atividades
├── critérios
├── etapas
└── evolução
```

Possibilidades:

- detectar queda de desempenho;
- apontar atividades com pior resultado;
- resumir desempenho da turma;
- sugerir alunos que precisam de atenção;
- gerar insights para o professor.

Evitar começar com previsões opacas como "IA prevê reprovação". Primeiro priorizar insights explicáveis sobre dados existentes.

---

# Ordem resumida

| Ordem | Bloco | Prioridade | Situação |
|---:|---|---|---|
| 1 | Atividade ↔ etapa | 🔴 | ✅ Marco 1 |
| 2 | Nota máxima da atividade | 🔴 | ✅ Marco 1 |
| 3 | Atividade ↔ critério | 🔴 | ✅ Marco 1 |
| 4 | Pesos e cálculo acadêmico | 🔴 | ✅ Marco 2 |
| 5 | Média correta por etapa | 🔴 | ✅ Marco 2 |
| 6 | Lançamento/importação de notas | 🔴 | ✅ Marcos 1, 4 e 5 |
| 7 | Boletim/fechamento | 🟠 | ✅ Marco 3 |
| 8 | Dashboard/aluno em risco correto | 🟠 | ✅ Marco 2 |
| 9 | Detalhe do aluno | 🟠 | ✅ Marco 3 |
| 10 | Editar/excluir/transferir aluno | 🟡 | ✅ Marcos 4 e 7 |
| 11 | Ano letivo real | 🟡 | ✅ Marco 6 |
| 12 | Gestão completa de professores | 🟡 | ✅ Marco 8 |
| 13 | Recuperação de senha | 🟡 | ⏳ pendente |
| 14 | Auditoria de notas (`nota_historico`) | 🟡 | ⏳ pendente |
| 15 | Testes completos | 🟠 | 🟡 parcial |
| 16 | Limpeza de legado | 🟡 | 🟡 parcial |
| 17 | Produção/deploy | 🔵 | ⏳ pendente |
| 18 | IA | 🔵 | ✅ Marco 9 |

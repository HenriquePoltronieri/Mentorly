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

  e devolve o código HTTP certo. Traduz exceções do Service em status (`RecursoNaoEncontrado` → 404, `ValueError` → 400, `ConflitoDeIntegridade` → 409, `LimiteExcedido` → 429); um erro interno (inclusive `KeyError` e `IndexError`) vira 500 genérico, sem detalhe para o cliente. Não escreve SQL e não tem regra acadêmica.

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

É o padrão usado na geração de atividades (9B) e na correção assistida (9C); o feedback e a
recuperação (9D) seguem o mesmo desenho, com a diferença de que o 9D é só leitura e nada é salvo:

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

#### Marco 9A — Insights Acadêmicos Explicáveis — validado com Groq real

```text
Aluno / Turma / Etapa / Critério / Atividade / Nota
  → calcular_desempenho_etapa                 (verdade numérica)
  → GerarInsightsTurmaService                 (autorização, redução e agregados)
  → AIClient                                  (HTTP externo e JSON estruturado)
  → InsightsTurmaScreen                       (exibição sob demanda)
```

`GerarInsightsTurmaService` exige o vínculo `professor_turma`, compara a escola da turma com a
escola do JWT e usa a etapa do ano da própria turma. O payload contém nome da turma, ano, etapa,
escala, agregados e, por aluno, uma **referência neutra** ("Aluno 1", "Aluno 2"...), a situação, os
percentuais, a completude e os critérios. **Nome, primeiro nome, sobrenome, e-mail, matrícula,
identificadores do banco e autenticação não saem da aplicação.**

A referência é atribuída pelo próprio Mentorly, na ordem da priorização (abaixo do mínimo primeiro).
O mapa referência → nome fica só em memória no service. Quando a resposta volta, o backend troca
cada "Aluno N" pelo primeiro nome (com a inicial do sobrenome se dois alunos tiverem o mesmo
primeiro nome), por substituição exata: "Aluno 10" não vira "Aluno 1" + "0", e "Maluno 1" não é
tocado. Uma referência que o Mentorly não atribuiu, ou um plural ("Alunos 1 e 2"), torna a resposta
inválida (503 amigável). A IA não participa do mapeamento e nunca recebe o mapa.

Detalhes individuais são limitados a 50 alunos; para turmas maiores, os agregados continuam
considerando todos.

O prompt de sistema manda tratar strings do JSON como dados, usar somente evidências fornecidas e
não inferir intenção, personalidade ou futuro. O cliente aceita apenas o contrato `resumo`,
`pontosPositivos`, `pontosAtencao` e `sugestoesGerais`. Ausência de chave, timeout, falha HTTP ou
JSON inválido viram erro amigável; nenhuma resposta artificial é criada.

**Estado:** implementado, coberto por testes com cliente simulado (a suíte automática nunca
chama a Groq) e **validado em 06/10/2026 com a Groq real** no fluxo completo do Mentorly:
Professor → turma vinculada → motor acadêmico → payload → `AIClient` → Groq → JSON validado →
Flutter. Provedor `Groq`, modelo `openai/gpt-oss-20b`, timeout de 15 s.

Decisões que vieram da validação real:

- `max_tokens` de 2500: o modelo raciocina antes de responder e 900 truncava o JSON (a Groq
  respondia 400 `json_validate_failed`);
- uma nova tentativa quando o provedor recusa o JSON ou a resposta sai fora do contrato; falhas de
  rede, timeout, chave e limite de uso não são repetidas;
- o motivo técnico de uma resposta inválida vai só para o log, e o Professor recebe a mensagem
  amigável;
- o prompt proíbe, entre outras coisas, inferir esforço ou participação, comparar percentual com
  nota mínima e tratar atividade sem nota como pendente, atrasada ou não entregue: ausência de
  nota não significa ausência de entrega. Cada regra nasceu de uma violação observada em respostas
  reais e tem teste de regressão.

Limites conhecidos: a saída do modelo é probabilística, então podem sobrar sugestões genéricas
(por exemplo, incentivar participação); o texto continua sendo apoio pedagógico, e a tela avisa que
notas e status oficiais são calculados pelo sistema. O plano gratuito da Groq limita o uso diário
(200.000 tokens/dia na conta usada).

#### Marco 9B — Geração assistida de atividades e questões — implementado

Fluxo:

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

**Backend.** `POST /api/professor/turmas/<id>/atividades/gerar` (somente Professor) chama
`GerarAtividadeIaService`, que nunca grava. Ele só chama a IA depois de validar, nesta ordem:
vínculo Professor–turma e escola (404 para qualquer outra combinação), o pedido (tema, dificuldade,
tipo, quantidade de 1 a 10) e, quando informados, etapa e critério com a **mesma função da criação
de atividade** (`validar_etapa_e_criterio`): etapa da escola, do ano da turma, aberta, e critério
pertencente à etapa. `professor_id` e `coordenacao_id` vêm do token, nunca do corpo.

**Contexto enviado à Groq:** nome da turma, disciplina, ano letivo, nome da etapa, nome do critério
e o pedido do Professor (tema, objetivo, dificuldade, quantidade, tipo, observações). **Nenhum dado
de aluno ou de professor, e-mail, matrícula ou identificador.** O texto digitado pelo Professor é
limpo de delimitadores antes de ir ao prompt e tratado como dado.

**Reuso do `AIClient`.** O cliente não conhece nenhum recurso: `gerar(payload, caso)` recebe um
`CasoDeUso` (prompt, instrução, validador do contrato e limite de saída). O padrão continua sendo
o dos insights, então o 9A não mudou. O 9B define o seu em `services/ia/contrato_atividade.py`; o
retry, o tratamento de erro e a mensagem amigável são os mesmos do 9A.

**Contrato da resposta** (validado antes de chegar ao Flutter): `titulo`, `descricao`, `objetivo`,
`questoes[]` (`tipo`, `enunciado`, `alternativas`, `respostaEsperada`, `explicacao`) e
`rubricaSugerida[]` (`criterio`, `descricao`, `peso`). Exige a quantidade e o tipo pedidos, quatro
alternativas e uma letra A–D de gabarito nas objetivas, e textos não vazios. Resposta fora do
contrato é repetida uma vez e, se persistir, vira 503 com mensagem amigável.

**Persistência e questões.** O Mentorly não tem tabela de questões, e o 9B **não cria uma**. A
sugestão é só um rascunho na tela: ao confirmar, o texto revisado (objetivo, descrição, questões,
alternativas, gabarito e explicação, e opcionalmente a rubrica) é preenchido no formulário normal e
salvo no campo `descricao` da atividade, pelo `POST /api/activities` já existente. Nada da resposta
bruta da IA é guardado. Escolha de menor impacto: uma modelagem de questões fica para quando o 9C
precisar dela. A rubrica é só texto; **não cria critério oficial nem altera pesos**, e a nota
máxima continua sendo decisão do Professor no formulário.

**Falhas.** Sem chave, chave inválida, timeout, provedor recusando ou resposta inválida devolvem
503 com a mensagem "…crie a atividade manualmente"; nenhuma atividade parcial é criada e o
formulário continua utilizável.

**Flutter.** `GerarAtividadeIaDialog` (pedido → revisão editável: título, descrição, objetivo,
enunciados, alternativas, gabarito, explicação, remover questão) com o aviso "Conteúdo gerado por
IA. Revise antes de salvar.". O botão fica desabilitado durante o pedido, o que evita duplo clique.

**Limites conhecidos.** A saída é probabilística: foram vistos gabarito discutível, viés de
posição (várias respostas "A") e questões que fogem do tema pedido. Por isso a revisão humana é
parte do fluxo, e o aviso fica visível. Cada geração gasta mais tokens que um insight, e o plano
gratuito da Groq limita o uso diário.

#### Marco 9C — Correção assistida de respostas discursivas — implementado

Como os alunos ainda não acessam o Mentorly, o Professor cola ou digita a resposta do aluno.

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

**Backend.** `POST /api/professor/atividades/<id>/correcao-assistida` (somente Professor) chama
`CorrigirRespostaIaService`, que **nunca grava nem altera nota** (nem importa `Nota`). A ordem é:
a atividade precisa ser de uma turma do Professor, reaproveitando `_atividade_do_professor` do
lançamento de notas (404 para qualquer outra combinação, inclusive outra escola); **etapa fechada
bloqueia o fluxo com mensagem clara, sem gastar chamada de IA**, pela mesma regra que já bloqueia
lançar nota; o valor máximo da resposta precisa ser maior que zero e não passar do valor da
atividade; questão, resposta esperada e resposta do aluno são obrigatórias; a rubrica é opcional
(até 6 itens). `professor_id`, `coordenacao_id`, turma e aluno nunca vêm do corpo.

**Contexto enviado à Groq:** título da atividade, nome do critério oficial, questão, resposta
esperada, resposta do aluno, valor máximo e a rubrica. **Nome do aluno, e-mail, matrícula,
identificadores e dados de outra escola não são enviados**; o nome aparece só na tela do Flutter.
O texto colado é limpo de delimitadores e tratado como dado; o prompt manda ignorar pedidos
escritos dentro da resposta do aluno (tentativa de manipulação).

**Contrato da resposta** (validado antes de chegar ao Flutter): `notaSugerida`, `avaliacao[]`
(`criterio`, `resultado`, `evidencia`, `faltou`), `pontosPositivos`, `pontosMelhorar`,
`justificativa` e `feedbackAluno`. O validador **recusa, sem corrigir em silêncio**, nota negativa,
acima do valor máximo, texto, `NaN` ou infinito; exige evidência em toda avaliação; exige que a
evidência de um item atendido reproduza pelo menos três palavras seguidas escritas pelo aluno (e
que qualquer trecho entre aspas exista na resposta); e, havendo rubrica, exige um item de avaliação
por item da rubrica. Resposta fora do contrato é repetida uma vez e, persistindo, vira 503 com
mensagem amigável.

**Quem calcula o quê.** `percentual = notaSugerida / valorMaximo * 100` é calculado pelo backend; o
percentual que o modelo eventualmente mande é ignorado. A nota oficial é a que o Professor digitar
e salvar.

**Reuso do `AIClient`.** Ganhou apenas um novo `CasoDeUso` (prompt, validador e limite de saída);
transporte, retry e mensagens de erro são os mesmos do 9A e 9B.

**Flutter.** Na `atividadeNotasScreen`, cada aluno tem o botão ✨, que abre o
`CorrigirRespostaIaDialog` (entrada → sugestão, com o aviso "A avaliação gerada por IA é apenas uma
sugestão. Revise antes de lançar a nota."). **Usar nota sugerida** devolve só o número, que
preenche o campo de nota daquele aluno; nada é salvo. O Professor pode alterar o valor e só grava
ao clicar em **Salvar notas** (`POST /api/atividades/<id>/notas`, o fluxo de sempre). O botão
fica desabilitado durante o pedido e, se a IA falhar, os textos digitados permanecem nos campos.

**Persistência.** Nada é gravado: nem prompt, nem resposta do aluno, nem a resposta da Groq, nem
a justificativa. Não existe tabela de questão, de resposta de aluno ou de correção.

**Limites conhecidos.** A IA avalia apenas o texto colado e pode errar; por isso o resultado é
sugestão e fica visível. A nota sugerida vale para a resposta corrigida: se a atividade tiver várias
questões, o Professor decide o total. Cada correção gasta tokens da cota da Groq.

#### Marco 9D — Feedback e recuperação personalizados — implementado

```text
Professor escolhe a etapa
  → motor acadêmico (calcular_desempenho_etapa)
  → GerarFeedbackIaService
  → payload sem identificador pessoal
  → AIClient (CasoDeUso de feedback)
  → sugestão pedagógica
  → Professor revisa
```

**Backend.** `POST /api/professor/alunos/<id>/feedback-ia` com `{"etapaId": N}` (somente Professor).
`GerarFeedbackIaService` é **somente leitura**: não importa nem chama nenhuma escrita de nota,
atividade, etapa ou critério, e o teste da API confirma que as tabelas ficam idênticas antes e
depois. A ordem é: o aluno precisa estar em turma vinculada ao Professor, da escola do token (404
para outra turma, outra escola ou aluno inexistente, reaproveitando `aluno_acessivel`); a etapa é
**explícita** (nunca "a etapa atual" implícita), da escola e do mesmo ano letivo da turma do aluno;
o resultado oficial vem do motor; sem configuração válida ou sem nenhuma atividade avaliada, a
resposta é 422 e a Groq não é chamada.

**Fonte dos dados.** Tudo vem do motor: nota, percentual, situação, completude, desempenho por
critério, atividades avaliadas e sem nota lançada, nota mínima e máxima da etapa. A IA não recalcula.
Quando o motor devolve `Decimal` (MySQL), o payload é convertido para tipos JSON.

**Contexto enviado à Groq:** tipo de plano, etapa (nome e escala), resultado (nota, percentual,
situação, completude), critérios (nome, peso, desempenho, atividades avaliadas e sem nota lançada) e
contagem de atividades. **Nenhum nome, e-mail, matrícula, id, turma ou dado de outra escola**: o
nome do aluno aparece só na tela.

**Etapa fechada é permitida.** Como o fluxo é só leitura, olhar o desempenho de uma etapa encerrada
é um uso legítimo (diferente de lançar nota, que o backend bloqueia).

**Três situações, decididas pelo backend** a partir da situação oficial: `abaixo_do_minimo` gera
plano de **recuperação**; `adequado` gera plano de **continuidade** (consolidação e aprofundamento,
sem forçar recuperação); `em_andamento` gera plano de **acompanhamento**: a resposta precisa dizer
que os dados estão incompletos e recomenda no máximo 2 itens por lista.

**Contrato da resposta:** `resumo`, `pontosConsolidados`, `pontosAtencao` (`descricao`,
`evidencia`), `objetivosRecuperacao`, `acoesSugeridas` (`acao`, `motivo`), `atividadesSugeridas` e
`acompanhamento`. Além do formato, o validador impõe regras que o prompt sozinho não garantiu:

- todo número citado como desempenho precisa existir no payload (quantidades pequenas como "2
  atividades" são livres só nas sugestões; percentuais e decimais continuam exigindo origem);
- termos de previsão (reprovação, evasão, risco), diagnóstico, inferência pessoal (família,
  esforço, comportamento), "pendente/atrasada/não entregue" e "nova nota/para passar" invalidam a
  resposta, que é repetida uma vez e, persistindo, vira 503 amigável;
- listas longas são cortadas ao limite, em vez de derrubar a resposta.

**Atividade sem nota lançada** nunca vira "pendente", "atrasada" ou "não entregue": o payload traz
`atividadesSemNotaLancada` por critério, e o prompt manda sugerir apenas verificar ou lançar a nota.

**Flutter.** Cada card de etapa na tela de desempenho do aluno tem **Gerar feedback com IA**, que
abre o `FeedbackIaDialog`: mostra a situação oficial do motor, o aviso "Sugestões geradas por IA com
base nos dados acadêmicos disponíveis. Revise antes de utilizar." e só chama a IA no clique, com o
botão desabilitado durante o pedido. Em falha, mostra mensagem amigável e o desempenho do aluno
continua disponível.

**Persistência.** Nada é gravado: nem feedback, nem plano, nem prompt, nem a resposta da Groq. Não
há migration.

**Limites conhecidos.** O texto é genérico em parte (por exemplo, "participar de sessões de estudo
em grupo") e a IA não conhece a sala de aula; é apoio, não decisão. Cada geração gasta tokens da cota
da Groq.

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

- **Insights:** pseudônimos ("Aluno N") e dados acadêmicos necessários; nenhum nome real;
- **Geração de atividade:** normalmente nenhum dado de aluno;
- **Correção:** questão, rubrica e resposta textual, sem email, matrícula, senha, JWT ou id do banco;
- **Feedback:** somente os resultados acadêmicos necessários para o objetivo.

#### Um único `AIClient` e limite de uso

Os quatro casos usam o mesmo `AIClient` (`services/ia/client.py`), que cuida de transporte, timeout,
limite de tamanho da resposta, uma nova tentativa para resposta fora do contrato e validação do
JSON; cada caso entrega o seu prompt, o seu contrato e o seu limite de saída (`CasoDeUso`). Como a
cota da Groq é pequena, cada Professor tem um **limite único de 20 chamadas de IA a cada 15
minutos** (compartilhado por 9A, 9B, 9C e 9D), mais um teto de 100 no processo. Passado o limite, a
resposta é 429 com `Retry-After` e o provedor nem é chamado.

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

## Regras de integridade e robustez

Regras do backend (valem fora do aplicativo), nascidas da auditoria final:

- **Motor.** A nota é comparada com a mínima com tolerância de 1e-9 (ruído de ponto flutuante), e o
  arredondamento continua acontecendo uma única vez, no resultado final.
- **Congelamentos.** Etapa fechada congela atividades, notas e a configuração da etapa e dos
  critérios. Ano letivo encerrado é histórico somente leitura (turma, aluno, etapa, critério,
  atividade e nota; a leitura e a transferência a partir dele seguem permitidas). Atividade com
  notas congela turma, etapa, critério e valor máximo. A regra de ano vem de uma única função,
  `exigir_ano_nao_encerrado`, e a de etapa de `exigir_etapa_aberta`; ambas rodam depois da checagem
  de escola e de vínculo, então quem não tem acesso recebe 404 e nunca descobre o estado do recurso.
- **Erros.** `RecursoNaoEncontrado` (`backend/erros.py`) é a única exceção que vira 404; ela de
  propósito não herda de `LookupError`, porque `KeyError` e `IndexError` herdam, e um bug interno
  não pode parecer "não encontrado". Violações esperadas do banco viram `ConflitoDeIntegridade`
  (409). Entradas passam por `services/entrada.py` (tipo, tamanho, número finito, data) e viram 400;
  o que sobrar é 500 genérico, com o detalhe só no log.
- **Autenticação.** O JWT vale só em `Authorization: Bearer`; a exceção são as três rotas GET de
  download de modelo de planilha, abertas pelo navegador. O professor desativado perde o acesso
  imediatamente (403 com `code: professor_desativado`).
- **Sessão no Flutter.** O `ApiService` é o único ponto que reconhece sessão inválida: um 401 em
  chamada autenticada (ou aquele 403) apaga a sessão, troca a pilha pelo login do papel e mostra
  uma mensagem, uma só vez, mesmo com várias chamadas simultâneas. Os outros 403 e o 401 do próprio
  login seguem como erro da operação.
- **Limite de requisições.** `services/rate_limit.py`: janela deslizante em memória, por processo,
  com chave coerente com o fluxo (IP + e-mail no login e nos códigos, escola + professor no convite,
  Professor na IA). Reiniciar o backend zera os contadores e várias instâncias não compartilham o
  limite; é a proteção simples do MVP.
- **Configuração de desenvolvimento.** `FLASK_DEBUG` e `DEV_EXPOSE_AUTH_CODES` vêm desligados. SMTP
  ausente significa "e-mail não enviado", nunca "pode mostrar o código ou o convite".

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

  → Groq com openai/gpt-oss-20b por padrão (provedor/modelo substituíveis por configuração)

```

O botão manual evita chamadas em rebuild. A indisponibilidade do provedor afeta somente essa
requisição e não entra no fluxo do motor acadêmico.

Esse fluxo está **implementado**, testado com cliente externo simulado e **validado com a Groq real**
em 06/10/2026 (ver Marco 9A acima). A chamada real depende de `AI_API_KEY` no ambiente local.

## Exemplo 6 — Correção assistida de resposta discursiva (implementado)

O fluxo abaixo está implementado no Marco 9C.

```text
corrigirRespostaIaDialog.dart (em atividadeNotasScreen)
  → CorrecaoAssistidaIaService (Dart)
  → POST /api/professor/atividades/<id>/correcao-assistida
  → ProfessorController
  → CorrigirRespostaIaService
  → AIClient                                 (reutilizado)
  → Groq
  → sugestão estruturada
  → Flutter mostra a sugestão
  → Professor revisa, usa a sugestão (só preenche o campo) e pode alterar
  → "Salvar notas": endpoint normal de notas
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

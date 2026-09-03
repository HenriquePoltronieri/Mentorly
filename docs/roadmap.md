# Roadmap do Mentorly

O roadmap a seguir organiza os próximos passos do Mentorly em ordem de dependência. A prioridade é fechar primeiro o ciclo acadêmico, depois completar administração, segurança e, por último, avançar para IA.

---

## Fase 1 — Fechar o núcleo acadêmico
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

Adicionar:

- editar professor;
- remover/desativar professor;
- reenviar convite;
- visualizar turmas vinculadas;
- desvincular turma;
- professor inativo;
- talvez redefinição administrativa de acesso.

Recomendação: não excluir fisicamente professor que já possui histórico.

Melhor:

```text
ativo = false
```

---

## Fase 9 — Recuperação de senha e segurança

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

| Ordem | Bloco | Prioridade |
|---:|---|---|
| 1 | Atividade ↔ etapa | 🔴 |
| 2 | Nota máxima da atividade | 🔴 |
| 3 | Atividade ↔ critério | 🔴 |
| 4 | Pesos e cálculo acadêmico | 🔴 |
| 5 | Média correta por etapa | 🔴 |
| 6 | Lançamento/importação de notas | 🔴 |
| 7 | Boletim/fechamento | 🟠 |
| 8 | Dashboard/aluno em risco correto | 🟠 |
| 9 | Detalhe do aluno | 🟠 |
| 10 | Editar/excluir/transferir aluno | 🟡 |
| 11 | Ano letivo real | 🟡 |
| 12 | Gestão completa de professores | 🟡 |
| 13 | Recuperação de senha | 🟡 |
| 14 | Auditoria de notas | 🟡 |
| 15 | Testes completos | 🟠 |
| 16 | Limpeza de legado | 🟡 |
| 17 | Produção/deploy | 🔵 |
| 18 | IA | 🔵 |

---

# Próximos 3 grandes marcos

## Marco 1 — Avaliação funcionando

> Professor cria uma atividade com etapa + critério + valor e lança notas válidas.

## Marco 2 — Desempenho funcionando

> Mentorly calcula corretamente a média por etapa e identifica alunos abaixo do mínimo.

## Marco 3 — Ciclo escolar funcionando

> Coordenação configura → professor avalia → aluno recebe resultado → dashboard/boletim refletem tudo corretamente.

---

# Foco imediato

O desenvolvimento agora deve se concentrar no **Marco 1**.

Esse é o bloco que destrava praticamente todo o restante do Mentorly:

```text
atividade
→ etapa
→ critério
→ nota máxima
→ lançamento de notas
→ cálculo
→ dashboard
```

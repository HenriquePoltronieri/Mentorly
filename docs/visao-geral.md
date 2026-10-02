# Visão Geral

## O que é o Mentorly

O Mentorly é um sistema de acompanhamento acadêmico para escolas. Ele ajuda a coordenação e os
professores a organizar turmas, atividades e notas, e mostra, com base nas regras da própria
escola, como cada aluno está indo.

A ideia surgiu porque, na escola, o controle de turmas, atividades e notas costuma ficar
espalhado em cadernos, planilhas e mensagens, e a média de cada aluno depende de contas feitas à
mão. O Mentorly reúne tudo em um só lugar e faz o cálculo de forma única e explícita.

O público são coordenadores pedagógicos e professores do Ensino Fundamental e Médio.

## Como funciona

Dois papéis usam o sistema:

- **Coordenação.** Cria a conta da escola, cadastra os **anos letivos** (um é o atual) e configura
  cada ano: etapas (por exemplo, quatro bimestres), nota mínima e máxima de cada etapa e os critérios de avaliação com seus pesos
  (por exemplo, Provas 70% e Trabalhos 30%). Cadastra turmas, alunos (à mão ou por planilha) e
  professores, e vincula cada professor às turmas que ele leciona. Acompanha o boletim das turmas
  e fecha cada etapa quando o resultado está definido.
- **Professor.** Recebe um convite, define a senha e passa a ver **somente as turmas vinculadas a
  ele**. Cria atividades escolhendo a etapa, o critério e o valor máximo, lança notas (na tela ou
  por planilha), corrige ou exclui uma nota e acompanha o desempenho dos alunos.

Cada turma e cada etapa pertencem a um ano letivo da escola, e o Mentorly nunca mistura anos: o
dashboard do Professor mostra o ano atual, o boletim usa o ano da turma, e um ano encerrado
mantém seus dados.

O Mentorly calcula a média de cada etapa, indica os alunos abaixo da nota mínima, gera o boletim
da turma e um consolidado do aluno. Uma etapa fechada fica protegida contra alterações até que a
Coordenação a reabra.

Cada cadastro de Coordenação é uma **escola independente**: uma escola nunca vê os dados de outra.

## Ciclo acadêmico atual

```
Coordenação configura        Professor avalia            Mentorly mostra o resultado
─────────────────────        ────────────────            ───────────────────────────
Etapas e critérios     →     Cria atividade        →     Média por etapa
Turmas e alunos              (etapa + critério +         Alunos em risco
Professores e vínculos        valor máximo)              Boletim da turma
                             Lança / importa notas       Consolidado do aluno
                                                          Fechamento da etapa
```

As regras do cálculo estão em [banco-e-procedures.md](banco-e-procedures.md) e a tabela das 20
funcionalidades demonstráveis, em [funcionalidades.md](funcionalidades.md).

## Como o projeto evoluiu

O projeto começou pelo frontend: as telas de um sistema escolar completo foram desenhadas antes
de existir um backend. Depois vieram uma primeira entrega, focada em turmas e atividades, e a
construção do backend de verdade: login com JWT, isolamento entre escolas, professores, alunos,
etapas, critérios, notas e planilhas. Os Marcos 1 a 6 (avaliação, desempenho, ciclo escolar,
gerenciamento de alunos, exclusão de nota e ano letivo) estão concluídos. A história completa está em
[historico-do-projeto.md](historico-do-projeto.md).

## O que ainda falta

Planejado em [roadmap.md](roadmap.md) para antes da apresentação:

- **Transferência de aluno com histórico**;
- **Gestão completa de professores** (editar, reenviar convite, desativar);
- **IA**, com insights acadêmicos explicáveis para o Professor. A IA vai trabalhar sobre os dados
  que o motor de cálculo já produz; ela não calcula nem altera notas.

Decisões ainda em aberto: verificação em duas etapas (obrigatória, opcional ou só para a
Coordenação) e se professores da mesma turma podem alterar atividades e notas criadas por outro
professor.

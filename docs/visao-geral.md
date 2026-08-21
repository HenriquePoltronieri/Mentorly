# Visão Geral

## O que é o Mentorly

O Mentorly é um sistema para ajudar a coordenação e os professores a organizar turmas e
atividades escolares.

A ideia surgiu porque, na escola, o controle de turmas e das atividades passadas para
cada uma costuma ficar espalhado em cadernos, planilhas e mensagens. A gente quis fazer
um lugar só onde a coordenação consegue cadastrar as turmas e acompanhar quantas
atividades cada uma tem.

O público que pensamos foi coordenadores pedagógicos e professores do Ensino Fundamental
e Médio.

## Ideia inicial

Quando o grupo começou, o plano era bem maior. As telas do aplicativo foram desenhadas
pensando em:

- coordenação e professores;
- alunos;
- lançamento de notas;
- etapas do ano letivo;
- critérios de avaliação;
- importação de alunos e notas por planilha;
- login com verificação em duas etapas;
- alguns recursos de IA para sugerir onde a turma estava com dificuldade.

Boa parte dessas telas chegou a ser feita no Flutter antes de existir um backend para
elas. Elas continuam no projeto, mas não conversam com a API, porque os endpoints delas
nunca foram desenvolvidos.

## Produto atual

Conforme o projeto avançou, ficou claro que dava para fazer muita coisa pela metade ou
poucas coisas inteiras. O grupo preferiu a segunda opção e concentrou esta entrega em:

- gestão de turmas (cadastrar, listar, editar e excluir);
- gestão de atividades de cada turma (cadastrar, listar, editar e excluir);
- busca de atividades por termo, com ordenação;
- relatório de turmas com a contagem de atividades.

São 10 funcionalidades, e todas funcionam do começo ao fim: a pessoa usa a tela no
Flutter, a informação vai para a API em Flask e é gravada no banco MySQL.

A escolha por turmas e atividades foi porque essas duas entidades já tinham Model,
Controller e Service prontos no backend, então dava para fechar a integração completa
sem precisar criar entidades novas.

## O que não está pronto

Tudo que foi listado na ideia inicial e não aparece no produto atual continua sem
backend: professores, alunos, notas, etapas, critérios, planilhas, login e IA. As telas
existem, mas não funcionam. Não estamos apresentando isso como entregue.

Como o login não tem backend, colocamos na tela inicial um atalho chamado
"Entrar no painel da coordenação" só para conseguir chegar nas telas que funcionam.

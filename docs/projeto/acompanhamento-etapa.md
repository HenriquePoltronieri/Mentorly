# Acompanhamento de notas e orientação pedagógica

A lista de alunos mostra os pontos originais das avaliações lançadas na etapa
atual. Um trabalho de 2 pontos aparece como `2/2` ou `1/2`, sem converter essa
pontuação em nota final. No detalhe do aluno, resumos, atividades e gráficos
mostram os pontos reais, como `2 de 2`. A média da turma por atividade também
usa os pontos reais daquela avaliação. Cada atividade mantém seu valor máximo.
As métricas normalizadas continuam disponíveis internamente para comparação e IA.

Cada etapa mostra a nota mínima para passar na escala configurada pela
coordenação, mesmo no início. Com notas lançadas e critérios válidos, mostra
também a pontuação ponderada e quanto falta para alcançar o mínimo. Essa
projeção considera os pesos dos critérios e as atividades cadastradas; novas
avaliações podem mudar o resultado. Sem notas, não inventa uma pontuação.

## Alertas

- Com início e término configurados, o período final começa aos 80% da duração
  da etapa. Com apenas o término, começa 14 dias antes dele. Sem datas, aguarda
  o fechamento explícito pelo professor.
- Antes do período final, o aluno com avaliações lançadas permanece **Em
  andamento**. Uma queda, um zero ou uma nota pendente isolada não emite alerta.
- Os pontos são ponderados pelos mesmos critérios usados no boletim. Notas
  ausentes mantêm os pontos possíveis; critérios sem atividades mantêm sua
  parcela disponível. A projeção usa as atividades cadastradas e pode mudar
  com novas avaliações ou recuperação.
- **Alto**: no período final, nem o máximo possível nas atividades cadastradas
  alcança a nota mínima. **Médio**: pelo menos 80% da parcela ponderada está
  avaliada, o desempenho está abaixo do mínimo e ainda é possível alcançá-lo.
- Configuração inválida ou ausência de avaliações permanece **Sem dados**.
  As etapas anteriores não alteram o alerta da etapa atual.

## Chat individual

O botão **Como ajudar este aluno?** abre uma conversa separada por sessão,
turma e aluno, com uma pergunta pronta que o professor pode editar e enviar.
As menores notas desse aluno orientam sugestões de revisão, exercícios com
devolutiva e recuperação. A menor média da turma não substitui a análise
individual. Perguntas sobre pontuação exibem os pontos reais da etapa.

Identificadores de alunos de outra turma são recusados antes de consultar o
provedor. Um aluno inexistente retorna 404. O modelo seleciona fatos e medidas;
o backend renderiza os nomes e números dos registros, sem permitir que a IA
altere notas ou invente resultados.

## Regressões

`backend/scripts/test_acompanhamento_etapa.py` cobre início e final da etapa,
datas ausentes, pesos, avaliações pendentes, recuperação, filtro por etapa,
orientação individual e pontos originais.

`frontend/app_mentorly/test/acompanhamento_aluno_test.dart` verifica a lista em
320 px e a abertura/envio da conversa com o identificador correto do aluno.

`backend/scripts/smoke_api.py` verifica o alerta somente após o fechamento
quando não há datas, além do isolamento por escola e ano letivo. O professor
consulta alunos; o cadastro, edição, exclusão e importação cabem à Coordenação.

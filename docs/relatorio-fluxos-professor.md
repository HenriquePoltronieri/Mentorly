# Entrega dos fluxos do professor — 12/10/2026

Implementação na ordem A → B → C → D → diagnóstico E0 → chat E1, preservando alterações locais e identidade visual.

- A: perfil/painel com `MenuCard`, borda de 1 px, cantos 18 px, padding 20 × 16, ícone 44 × 44, distância de 16 px, hover/pressed e espaço entre cards.
- B: professor somente consulta alunos. Rotas antigas de cadastro, edição, exclusão, importação e modelo de importação retornam 403. Diálogos compartilhados também restringem acesso.
- C1: nome/e-mail com validação inline, turmas opcionais com chips, botão fixo, busca e novo professor no topo. Professor e vínculos na mesma transação. Convite pendente até a senha ser definida; compartilhamento manual quando o e-mail falha.
- C2: página única, turma pré-selecionada, etapa atual, valor configurado, date picker, descrição opcional, botão fixo e acesso direto às notas. O critério de maior peso já configurado na etapa é selecionado automaticamente para preservar o motor acadêmico sem adicionar um campo ao formulário.
- C3: lançamento em lote, validação, teclado numérico, foco seguinte, contador, botão fixo, aplicar mesma nota e Ausente/Não entregou (zero + observação). Importação de notas e correção assistida preservadas.
- D: aba Estatísticas, gráficos `fl_chart`, filtro de etapa, resumo, ranking e detalhe individual comparado à turma. Médias comparáveis na escala proporcional de 0 a 10; notas originais/máximos na lista. Boletim ponderado existente acessível. Risco Sem dados quando faltam evidências.
- E1: Flask/Groq, histórico por sessão/turma em memória, nova conversa, chips, digitação, repetir, atalhos, limites de mensagem/histórico e rate limit por professor. IDs alheios/respostas inválidas recusados. IA seleciona fatos e medidas; backend renderiza nomes/números reais. Contexto sem e-mail, telefone, matrícula ou documento.

## Diagnóstico E0

Localizados e testados insights, geração de atividade, correção assistida e feedback, incluindo frontend, backend e contratos.

A configuração inicial não disponibilizava chave ao processo. Após a atualização do `.env`, `AI_API_KEY` foi carregada. Conforme a orientação final, o backend mantém `AI_API_KEY`, `AI_BASE_URL`, `AI_MODEL` e `AI_TIMEOUT`; não usa `GROQ_API_KEY`. Nenhuma chave foi impressa ou colocada no Flutter.

Flutter esperava 15 segundos, mas o backend podia fazer duas tentativas. IA agora tem prazo de 50 segundos no app e teto de 20 segundos por tentativa no backend. Erros amigáveis com repetir. Testes de parsing, timeout, contrato e privacidade passaram; não foi encontrado defeito que exigisse substituir os contratos existentes.

A base real tem uma atividade e zero notas. Insights/feedback recusaram corretamente a análise por falta de avaliações. Geração de atividade e correção assistida fizeram chamadas reais à Groq e passaram pelos validadores, sem gravar resultados.

## Validação

- `python backend/scripts/test_unitarios.py`: **225 testes passaram**, incluindo 18 novas regressões.
- `flutter test --reporter expanded`: **124 testes passaram**, incluindo formulário essencial, entrega, histórico/retry, filtros, gráficos com notas em largura móvel e regressões existentes.
- `flutter analyze --no-pub`: **zero erros, zero warnings, 87 infos**, de nomes de arquivos existentes/APIs antigas. Nenhum arquivo renomeado ou regra desativada. Saída: `flutter-analyze-fluxos.txt`.
- Estatísticas reais de turma/aluno/dashboard: **200**. Professor cadastrar/remover/importar alunos: **403**, sem escrita.
- `python backend/scripts/validar_chat_real.py`: três perguntas reais deram **200** pelo Flask/Groq; evidências conferidas com MySQL; contagens de aluno/atividade/nota inalteradas.
- `git diff --check`: passou, somente avisos LF/CRLF de arquivos já existentes.

Perguntas reais: “qual aluno está com mais risco?”, “quais medidas aplicar?” e “onde a turma tem mais dificuldade?”. Respostas reconheceram um aluno, uma atividade e ausência de notas; sugeriram conferir lançamentos/entregas e conversar individualmente, sem inventar média ou diagnóstico.

**Limite:** o MySQL está sem notas, portanto não é possível confirmar ranking com notas reais nessa base. Normalização/tendências/risco com notas foram testados com fixtures exclusivamente em memória, sem criar dados falsos permanentes.

Flask iniciado em `http://127.0.0.1:5000`, sem reinstalar schema/procedures. Lista de arquivos: `arquivos-fluxos-professor.txt`.

Documentação: [Groq](https://console.groq.com/docs/openai), [fl_chart](https://pub.dev/packages/fl_chart).

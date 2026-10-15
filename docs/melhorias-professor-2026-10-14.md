# Experiência do professor — 14/10/2026

O início do professor agora mostra trabalho pendente com acesso direto ao lançamento, turmas vinculadas no ano atual, retornos de intervenções e alunos com sinais de risco. Login, primeiro acesso e recuperação da sessão levam ao painel.

## Interface

- Telas de trabalho com fundo claro, cards sólidos, bordas discretas e azul para a ação principal. As telas de acesso preservam os elementos da marca.
- Navegação lateral nas três áreas principais em desktop; navegação inferior em celular/tablet. Telas internas preservam o retorno ao contexto de origem.
- Busca por nome/disciplina nas listas de turmas e atividades, rótulos mais curtos e indicadores de totais menores.
- Conteúdo e ações adaptados a 320, 768 e 1280 pixels.

## Funcionalidades

1. **Pendências:** atividades de etapas abertas do ano atual com quantidade de alunos sem nota. Uma pendência de lançamento não é tratada como confirmação de falta de entrega.
2. **Grade da turma:** em Minhas turmas → turma → Grade de notas. Alunos por linha, atividades por coluna, edição por teclado, busca, seleção de etapa e filtro de pendências. A tabela tem rolagem horizontal. O salvamento valida também campos ocultos por filtros. Cada atividade é salva em uma transação; se uma falhar, a mensagem informa as atividades concluídas e mantém as alterações restantes.
3. **Reaproveitamento:** em Atividades → turma → ícone de copiar. Abre um novo formulário com título, descrição, valor e etapa quando compatível. A turma e a nova data são revisadas antes do POST. Nenhuma nota é copiada e a atividade original não é alterada.
4. **Rascunhos locais:** grade e lançamento guardam alterações neste dispositivo, separadas por servidor/conta/recurso. A recuperação exige revisão e não aplica campos cuja nota oficial mudou desde o rascunho. São rascunhos locais, sem sincronização entre dispositivos. O botão de salvar publica as notas no servidor.
5. **Acompanhamento pedagógico:** no perfil do aluno, o botão de acompanhamento abre intervenções com descrição, data de retorno e histórico. O professor pode marcar o retorno como realizado. Registros são privados ao professor, dentro das turmas a que ele tem acesso. Ano encerrado bloqueia escrita.
6. **Resumo para reunião:** botão na grade abre relatório HTML de impressão com aluno, situação de acompanhamento, pontos da etapa selecionada/atual, quantidade de avaliações sem nota e intervenções do professor. Use Imprimir / Salvar em PDF no navegador. O filtro por nome/pendências da tela não limita o relatório; a etapa selecionada limita os dados acadêmicos.

## Situações de avaliação

“Ausente”, “Não entregou” e “Não corrigido” ficam em `atividade_situacao`, separadas da nota. Selecionar uma situação não preenche zero. Para atribuir zero, o professor precisa digitar o valor. Valores preenchidos continuam participando do cálculo da escola, inclusive quando acompanhados de uma situação.

Notas zero registradas em versões anteriores permanecem como estão: não é possível inferir retrospectivamente se o zero foi atribuído pelo professor. Excluir uma nota continua sendo uma ação explícita. O motor de notas ponderadas não foi alterado.

## Banco e execução

`database/professor_workspace.sql` cria apenas `atividade_situacao` e `acompanhamento_pedagogico`, com `CREATE TABLE IF NOT EXISTS`. A instalação está conectada a `install_schema()`; `python backend/app.py` aplica a extensão ao iniciar. Para servidores que usam `create_app()` por WSGI, executar a instalação antes de reiniciar os workers:

```powershell
cd backend
python -c "from database.connection import install_professor_workspace; install_professor_workspace()"
```

As tabelas foram instaladas na base local configurada, sem alterações nas notas. A validação integrada usa exclusivamente `mentorly_interface_regressao`, cria uma escola temporária e remove seus dados ao terminar. Não envia e-mails nem consulta IA.

## Verificação

- 254 testes de backend aprovados.
- 132 testes Flutter aprovados, incluindo preservação do rascunho ao excluir outra nota.
- Análise Flutter sem erros e warnings; permanecem 87 infos anteriores de nomenclatura e APIs depreciadas.
- Build Web release aprovado.
- Integração com MySQL: SQL das pendências, situação sem nota zero, grade, intervenções, conclusão de retorno, relatório, nova atividade sem copiar notas e bloqueio de etapa fechada.
- Navegador Edge: início e grade em 320/768/1280 pixels, com dados fictícios apenas na escola temporária de QA.

Comandos:

```powershell
python backend/scripts/test_unitarios.py
cd frontend/app_mentorly
flutter test --no-pub
flutter analyze --no-pub --no-fatal-infos
```

Para integração sem navegador: `python backend/scripts/validar_trabalho_professor.py --sem-visual`. Para as capturas, iniciar o backend de QA (`servir_validacao.py`), servir o build na porta 18080 com API na porta 5001 e rodar o mesmo script sem essa opção.

Capturas: [início desktop](profissional-inicio-1280.png), [início celular](profissional-inicio-320.png), [grade desktop](profissional-grade-1280.png), [grade celular](profissional-grade-320.png).

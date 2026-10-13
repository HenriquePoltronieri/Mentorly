# Mentorly — redesign com vidro e Poppins

Revisão local concluída em 12/10/2026. Esta direção visual substitui a orientação anterior de evitar vidro e gradientes; as correções de permissões, cache, assistente e convites foram preservadas.

## Implementação

O tema único está em `frontend/app_mentorly/lib/app/theme.dart`: fundo #E6E6E6, azul e verde-água descritos no pedido, tipografia Poppins, raios, espaçamentos, sombras, campos e botões em pílula. A densidade é padrão e os controles principais têm alvo mínimo de 48 px. Os campos usam fonte de pelo menos 14 px; textos de apoio usam 12–13 px.

A logo fornecida foi copiada de `lib/assets/logo.png` para `assets/images/logo.png`, sem alterar a imagem original. Assets e fontes estão declarados no pubspec. Poppins Light, Regular, Medium e SemiBold estão em `assets/fonts/`, com a licença OFL. Origem: [repositório oficial Google Fonts](https://github.com/google/fonts/tree/main/ofl/poppins).

`identidade_visual.dart` concentra fundo por perfil, marca, formas orgânicas desenhadas em CustomPainter, card translúcido e moldura de acesso. `barra_mentorly.dart` reúne a navegação e o menu de conta dos dois papéis. As manchas usam RadialGradient estático dentro de RepaintBoundary. Os cards usam branco semitransparente e sombra leve; não há BackdropFilter nem blur em listas.

| Tela/área | Resultado |
| --- | --- |
| Escolha de perfil | Card central, pergunta solicitada, hierarquia/quadro em ícones outlined, opções inteiras clicáveis, separador “Ou”, foco e Enter funcionando. |
| Coordenação: login/cadastro | Dois painéis no desktop e tablet. Formulário e boas-vindas trocam de lado com animação de 280 ms. No celular ficam em coluna, com alternância Criar conta/Já tenho conta. Validação durante a edição, erros legíveis e mostrar/ocultar senha. |
| Professor: login | Card único, mancha verde/ciano/azul, Email e Senha; orientação para primeiro acesso por convite. |
| Professor: convite | Título Criar senha, e-mail obtido do token e somente leitura, Nova senha/Confirmar senha, regras visíveis e botão Criar senha e entrar. Convites inválidos/usados/expirados bloqueiam o envio e orientam pedir outro. Erros temporários permitem tentar novamente. |
| Professor: dashboard | Logo, Dashboard/Turmas/Atividades, aba ativa em pílula azul, e-mail com menu de conta/Sair. Saudação com o nome real, dois cards com totais do backend e painel de alunos em risco com nota/meta. |
| Professor: turmas/atividades/boletim | Cabeçalho e linguagem visual compartilhados, fundo do professor e superfície translúcida. Funcionalidades acadêmicas preservadas. |
| Coordenação: painel | Nome cadastrado, ano atual, configuração e convites pendentes; tarefas administrativas em cards translúcidos. Sem atividades ou desempenho acadêmico. |
| Assistente: três passos | Mesma identidade, progresso e navegação. Pesos continuam visíveis, com borda, rótulo e %, soma válida e persistência atômica. Rascunhos e reabertura do salvo preservados. |
| Professores | Lista e cadastro com status, reenvio e cópia de convite; novo cabeçalho e campos em pílula. |
| Turmas/alunos/vínculos/anos | Listas, formulários, ações e estados anteriores preservados, com tema compartilhado e menus adaptados à largura. |

## Convite e regra de risco

Foi adicionado `POST /api/auth/consultar-convite`. O token segue no corpo, evitando sua exposição em logs de URL. A consulta valida hash, prazo, uso e habilitação; retorna apenas o e-mail e não consome o convite. Possui limite por origem. A criação de senha mantém o consumo único e a autenticação automática já existentes.

A regra de alunos em risco já existia no backend e foi reaproveitada: considera as turmas vinculadas ao professor no ano atual e a etapa atual desse ano. Um aluno entra na lista quando o cálculo está completo e sua nota calculada é menor que `nota_minima` da etapa. Notas incompletas não viram zero nem risco automaticamente; são acompanhadas no boletim. Não foram introduzidos limites fixos de aprovação. Os totais também vêm da API.

## Desvios e decisões

- Cores aproximadas conforme os valores do pedido; não houve arquivo Figma ou prints adicionais para amostrar pixels.
- Vidro obtido com transparência sólida, sem BackdropFilter, para reduzir custo de composição.
- Fontes e alvos de toque maiores que os detalhes minúsculos do mockup, conforme exigência de usabilidade.
- Confirmar senha foi mantido também no cadastro da Coordenação para evitar erros de digitação.
- Textos decorativos de canto aparecem nos acessos em telas grandes; ficam ocultos nas menores. Nas áreas internas a marca está na barra, com prioridade para os dados.
- Login Google e Esqueceu a senha ficaram ocultos: o backend não oferece OAuth Google nem recuperação de senha. Implementar esses fluxos é uma etapa separada, permitida como decisão futura no pedido.
- O cadastro atual da Coordenação guarda um único nome, utilizado como identificação da escola. Não há campo separado para nome da pessoa responsável; separar os dois exige uma definição de cadastro e persistência. Não foi inventado um segundo nome no painel.

## Desempenho e verificação

Poppins está embutida. A investigação identificou que CanvasKit ainda baixava Roboto como fallback quando essa família não constava no manifesto. O pubspec agora registra a Poppins Regular local também sob esse alias técnico. O comportamento está documentado no [código oficial do renderizador Flutter](https://github.com/flutter/engine/blob/main/lib/web_ui/lib/src/engine/canvaskit/fonts.dart). O Web antecipa os arquivos de fonte por preload; a captura de rede confirmou ausência de fontes externas.

As medições de telas ficam em [antes](telas-vidro-antes.json) e [depois](telas-vidro-depois.json); a medição intermediária com fallback remoto foi preservada em [investigação](telas-vidro-antes-fallback-local.json). O script `backend/scripts/medir_telas.py` mede o release no Edge em 1280×900, da navegação/ação até o conteúdo acessível pronto, usando a escola de QA e a mesma conta de professor. Os tempos incluem autenticação, rede local, transição e renderização; não são benchmarks de produção.

| Medição | Antes | Release final | Diferença |
| --- | ---: | ---: | ---: |
| Acesso inicial, navegador novo | 982,90 ms | 1.471,92 ms | +489,02 ms |
| Login até painel da Coordenação | 565,85 ms | 805,75 ms | +239,90 ms |
| Login até dashboard do Professor | 713,66 ms | 907,83 ms | +194,17 ms |
| Intervalo mediano entre frames do painel carregado | 6,90 ms | 6,90 ms | 0,00 ms |
| Intervalos acima de 33 ms em 120 frames | 0 | 0 | 0 |

A [amostra anterior do redesign](telas-vidro-amostra-anterior.json) também foi mantida: 1.613,98 / 1.064,64 / 1.179,12 ms, respectivamente. A captura final usa CanvasKit servido localmente; nenhuma fonte externa foi carregada. O backend respondeu aos logins em 173,32 e 175,66 ms nessa captura.

Não se deve afirmar ausência de regressão nos tempos de abertura: as amostras posteriores ficaram acima da primeira amostra anterior. A duração do backend de autenticação também variou entre execuções, portanto a diferença não pode ser atribuída integralmente ao layout. A mediana dos intervalos de 120 frames permaneceu perto de 6,9–7,0 ms, sem intervalos acima de 33 ms nessa amostra. Isso indica estabilidade do painel já carregado nessa condição, não garantia de fluidez em todo dispositivo ou durante todo fluxo.

Validação concluída:

- 118 testes Flutter aprovados, incluindo todos os caminhos de etapas, retorno/reabertura, permissões, falha de envio, sessão, e-mail somente leitura e login após cadastro inválido em celular/tablet.
- 207 testes unitários backend aprovados e 10 regressões integradas com banco isolado. Consulta de convite ausente, inválido, expirado, usado ou de professor desativado não expõe e-mail.
- Análise sem erros ou warnings. `flutter analyze --no-fatal-infos` aprovado; permanecem 90 informações de nomenclatura camelCase e APIs depreciadas já existentes. O comando padrão ainda considera essas informações fatais; não foram ocultadas em regras novas.
- Build Web release gerado com renderizador e fontes locais.
- Edge em 320, 768 e 1280 px: teclado/Enter, alternância de cadastro, mensagens de validação sem cortes, navegação, assistente, pesos sem cortes, convite somente leitura, criação de senha, dashboard e token usado. O envio externo ficou desligado no servidor de QA; não foram enviados novos e-mails reais nesta etapa.

Capturas: [perfil](vidro-perfil-desktop.png), [login](vidro-login-desktop.png), [cadastro](vidro-cadastro-desktop.png), [tablet](vidro-login-768.png), [celular](vidro-login-320.png), [Coordenação](vidro-coordenacao-1280.png), [critérios](vidro-criterios-mobile.png), [convite](vidro-convite-mobile.png), [convite usado](vidro-convite-usado-mobile.png), [Professor desktop](vidro-professor-1280.png), [Professor celular](vidro-professor-320.png).

O card de acesso acompanha a altura do formulário e dos erros, preservando a troca de lados. No tablet, a barra do professor reduz a marca ao ícone para manter as três abas e a conta sem cortes; com fontes ampliadas, passa ao menu compacto. Exemplos: [cadastro inválido no tablet](vidro-cadastro-erros-768.png) e [dashboard no tablet](vidro-professor-768.png).

Para reproduzir o build de QA, na pasta `frontend/app_mentorly`:

```powershell
flutter build web --release --no-wasm-dry-run --no-web-resources-cdn --dart-define=API_URL=http://127.0.0.1:5001/api
```

Na raiz do projeto, mantenha `python -u backend/scripts/servir_validacao.py` e `python -m http.server 18080 --bind 127.0.0.1 --directory frontend/app_mentorly/build/web` em terminais separados. Com o banco de QA existente, execute `python backend/scripts/validar_visual_vidro.py` e depois `python backend/scripts/medir_telas.py docs/telas-vidro-depois.json`. A digitação ocorre antes do início da cronometragem dos logins; a automação confere o input de edição do Flutter, pois o nó semântico de senha pode permanecer vazio durante o foco.

Prévia local: http://127.0.0.1:18080, backend de QA na porta 5001, banco isolado `mentorly_interface_regressao`. Conta fictícia de Coordenação: `validacao@escola.invalid`, senha `validacao123`. A prévia exige que os dois processos estejam em execução. Não houve implantação em produção; `backend/.env` e seus segredos foram preservados.

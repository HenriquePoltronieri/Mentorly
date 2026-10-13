# Mentorly — correções e revisão da interface

Validação local em 11/10/2026, com Flask, MySQL e Flutter Web no Edge. O convite real enviado por `mentorly.noreply@gmail.com` foi aceito pelo Gmail e o destinatário confirmou recebimento na caixa de entrada. As credenciais permaneceram em `backend/.env`, ignorado pelo Git.

## 1. Correções e causas

| Problema | Causa encontrada | Resultado |
| --- | --- | --- |
| Coordenação acessava dados acadêmicos | Rotas e serviços permitiam acesso administrativo a atividades, boletins e fechamento de etapas. | Endpoints acadêmicos exigem Professor e recusam Coordenação com 403. Rotas, telas e serviço exclusivos de boletim/relatório da Coordenação foram removidos. O professor tem boletim e fechamento/reabertura, com verificação de vínculo. |
| Pesos cortados ou sem indicação | O campo herdava a borda invisível do tema (`BorderSide.none`), não tinha rótulo e usava apenas 90 px. Critérios novos começavam com controller vazio, resultando em soma zero. A tela usava Column com Spacer e rodapé em Row sem acomodar telas estreitas. | Campos com borda explícita, rótulo Peso, sufixo %, 120 px e teclado numérico. Tela rolável e rodapé que quebra linha. Soma acompanha a edição: laranja enquanto inválida, verde com check em 100%. Alterar critérios redistribui centésimos sem perder o total. |
| Erro ao concluir o ano | O assistente gravava partes separadamente, podia recriar etapas e perder referências/configurações ao voltar. Validações e erros não protegiam o conjunto completo. | Rascunho compartilhado entre os três passos; conclusão por um PUT transacional. Valida mínima < pontos, valores finitos, duas casas decimais e soma exata de 100. Reaproveita IDs existentes; alterações incompatíveis com atividades vinculadas retornam 409 e preservam a configuração anterior. |
| E-mail não enviado | Configuração original usava nomes SMTP diferentes dos MAIL solicitados. A autenticação real do Gmail também falhou com a credencial anterior; a conexão era encerrada na autenticação em 587 e 465. | MAIL_* tem prioridade, aliases antigos seguem compatíveis, STARTTLS e certificado são verificados. Depois da substituição privada pela senha de app, envio real funcionou. Log registra etapa e exceção, sem senha ou link. |
| Convite abria sem token | A rota com query string não correspondia à chave exata no mapa do Flutter; o fragmento era reduzido ao caminho, perdendo o token. | `/#/definir-senha?token=...` é preservado e seus parâmetros chegam à tela. Só nova senha e confirmação são editáveis; token identifica o professor. Criação de senha autentica e abre suas turmas. |
| Lista ficava carregando após cadastro | A conclusão do cadastro permanecia presa ao fluxo de diálogo/carregamento, e requisições não tinham limite geral de espera. | Cadastro libera o estado antes do diálogo; retorno atualiza a lista. API tem timeout de 15 segundos, mensagens legíveis, retry e estados vazios nas telas revisadas. Falha de SMTP não desfaz o cadastro e oferece Copiar link. |
| Aluno salvo não aparecia ao fechar com Escape | A lista só atualizava quando o diálogo retornava explicitamente `true`; Escape e toque fora retornavam `null` mesmo depois de um cadastro. | Coordenação e Professor atualizam a lista depois de qualquer fechamento. O cache evita nova consulta quando nada mudou. |
| Lentidão | Conectar ao MySQL por `localhost` neste Windows levava cerca de dois segundos; várias conexões por leitura e consultas por etapa/professor/aluno multiplicavam o atraso. | Loopback local usa 127.0.0.1; leituras compartilham conexão por requisição, fechada ao final. Critérios, vínculos e dados acadêmicos são carregados em lote. Flutter usa cache de 30 segundos, deduplicação e chamadas independentes em paralelo. Escritas e troca de sessão invalidam o cache. |

Os convites usam token aleatório seguro, hash SHA-256 no banco, validade de 48 horas e consumo único com atualização condicional. Reenviar ou gerar novo link invalida o anterior. O link aparece somente na emissão para a Coordenação autenticada, nunca na listagem geral. Tokens antigos são migrados para hash sem alterar o link já enviado.

O envio SMTP continua síncrono, conforme a alternativa permitida no pedido: timeout de socket de até três segundos por operação. Isso não é um teto absoluto de três segundos para toda a requisição. Não foi introduzida fila de e-mails.

## 2. Tempos antes e depois

| Endpoint | Antes | Depois |
| --- | ---: | ---: |
| GET /api/coordenacao/professores | 4.093,30 ms | 4,40 ms |
| GET /api/config/etapas | 10.208,18 ms | 24,22 ms |
| GET /api/config/anos-letivos | 2.044,68 ms | 14,96 ms |
| GET /api/classes | 4.103,32 ms | 15,15 ms |
| GET /api/dashboard/resumo | 2.094,45 ms | 15,36 ms |

Medição com o cliente de teste Flask, banco local e o mesmo cadastro existente, sem alterar dados: uma execução de cada endpoint por versão, com um professor e três etapas. Não inclui rede pública, renderização Flutter nem envio SMTP e não constitui benchmark de produção. Evidências: [antes](desempenho-antes.json), [depois](desempenho-depois.json), script `backend/scripts/medir_desempenho.py`.

O backend também registra duração, status e contagem de consultas auxiliares por rota e envia `Server-Timing`. Um teste integrado compara o boletim de 1 e 41 alunos: a quantidade de consultas permanece constante e os resultados são equivalentes ao cálculo anterior. Não há evidência local de cold start; a hospedagem de produção não foi informada nem medida. Paginação geral de todas as listas não foi implementada nesta alteração.

## 3. Configurar Gmail, em ordem

1. Entre na conta `mentorly.noreply@gmail.com` e ative a verificação em duas etapas em Segurança da Conta Google.
2. Abra [Senhas de app](https://myaccount.google.com/apppasswords), crie uma para Mentorly e copie a senha de 16 caracteres. Use essa senha, nunca a senha normal da conta. A exigência de duas etapas e as possíveis restrições da conta estão na [documentação do Google](https://support.google.com/accounts/answer/185833?hl=pt-BR).
3. No computador local, mantenha os valores abaixo em `backend/.env`. Use `backend/.env.example` apenas como modelo público. Os passos da credencial já foram realizados e validados nesta sessão.

   ```dotenv
   MAIL_SERVER=smtp.gmail.com
   MAIL_PORT=587
   MAIL_USERNAME=mentorly.noreply@gmail.com
   MAIL_PASSWORD=COLOQUE_A_SENHA_DE_APP_LOCALMENTE
   MAIL_FROM=mentorly.noreply@gmail.com
   MAIL_USE_SSL=false
   MAIL_TIMEOUT=3
   FRONTEND_URL=http://localhost:3000
   CONVITE_EXPIRACAO_HORAS=48
   DEV_EXPOSE_AUTH_CODES=false
   ```

   Porta 587 usa STARTTLS, conforme a [configuração SMTP do Gmail](https://support.google.com/mail/answer/7104828?hl=pt-BR). Não acrescente `/#/definir-senha` a FRONTEND_URL: o backend monta essa parte.

4. Ajuste `FRONTEND_URL` para a origem real onde o frontend abre. Localmente, use a porta em que iniciou o Flutter. Na prévia isolada desta sessão é `http://127.0.0.1:18080`; em produção deve ser o endereço público HTTPS acessível pelo professor. Um link localhost só funciona no computador que serve o app.
5. Na hospedagem, cadastre essas mesmas variáveis na configuração do serviço do backend; não envie `.env` para o Git. Variáveis já definidas no processo têm prioridade sobre o arquivo local. Reinicie o backend depois de mudar valores. Configure também uma SECRET_KEY persistente e os dados do banco nesse ambiente.
6. Cadastre um professor de teste com endereço que você autoriza receber o convite. Confira o status na lista e abra o e-mail “Seu acesso ao Mentorly”. Clique em “Criar minha senha”, defina e confirme a senha, confira o acesso às turmas e teste sair/entrar. Se falhar, veja o log SMTP, use Reenviar convite ou Copiar link. Nesta sessão houve envio real e confirmação de caixa de entrada; criação de senha e login foram verificados separadamente com um professor fictício da base de QA, preservando o convite real recebido.
7. Confira se a hospedagem permite SMTP de saída. Por exemplo, [serviços gratuitos do Render bloqueiam as portas SMTP 25, 465 e 587](https://render.com/changelog/free-web-services-will-no-longer-allow-outbound-traffic-to-smtp-ports). Se esse for seu ambiente, a alternativa é um serviço de e-mail transacional por API HTTPS ou um plano que permita SMTP. Essa integração adicional depende da hospedagem escolhida e não foi implementada sem essa informação.

## 4. Telas revisadas

| Área | Mudança |
| --- | --- |
| Seleção de perfil e login | Formulários com largura confortável, título claro, foco inicial, teclado/Enter, senha visível sob demanda e erro junto ao formulário. |
| Definir senha | Token da URL, apenas dois campos de senha, regras visíveis, explicação para convite expirado/usado e entrada automática. |
| Painel da Coordenação | Nome da escola, ano atual, pendências de configuração/convites e tarefas administrativas; sem indicadores acadêmicos. |
| Assistente do ano | Progresso de três passos, rascunho ao voltar, campos Mínimo para aprovação/Pontos da etapa, total do ano, pesos visíveis e conclusão validada. |
| Professores e cadastro | Lista com status, Reenviar convite, geração/cópia de link, formulários e erro de entrega sem bloquear a lista. |
| Turmas e alunos | Listas com separadores, ação principal, formulários mais claros, limites de largura e estados de carregamento/erro/vazio. |
| Vínculos e anos letivos | Organização em listas, seleção legível, carregamento independente em paralelo e feedback de erro. |
| Professor: painel, turmas e atividades | Navegação móvel por menu, nome da pessoa, indicadores e ações mais claros, listas e estados completos nas telas revisadas. |
| Professor: alunos e boletim | Ações adaptadas à largura, tabela rolável, carregamento/erro e fechamento/reabertura com confirmação de alcance. |

Tema central em `lib/app/theme.dart`: Material 3, fundo off-white, azul acinzentado, espaçamento consistente, controles principais de 48 px, bordas discretas e menos decoração. Componentes de página e formulários compartilham limites de largura. Localização Material em português do Brasil. As telas de detalhes acadêmicos e diálogos de IA não receberam uma reconstrução visual integral; herdam o tema.

Capturas: [acesso](interface-acesso.png), [login](interface-login-desktop.png), [coordenação desktop](interface-coordenacao-desktop.png), [tablet](interface-coordenacao-768.png), [celular](interface-coordenacao-320.png), [critérios](interface-criterios-mobile.png), [senha](interface-senha-mobile.png), [professores](interface-professores-desktop.png), [formulário de turma](interface-turma-formulario-mobile.png), [turmas](interface-turmas-mobile.png), [alunos](interface-alunos-mobile.png), [vínculos](interface-vinculos-mobile.png), [boletim](interface-boletim-mobile.png), [turmas do professor](interface-professor-turmas-mobile.png), [painel do professor](interface-professor-mobile.png).

## 5. Verificação e limites

- 116 testes Flutter aprovados, incluindo 1/2/3/4 etapas e personalizado, retorno entre passos, reabertura do salvo, erro do servidor e cache/sessão.
- 207 testes unitários backend aprovados; 9 regressões com banco isolado aprovadas; 40 verificações de migração aprovadas em processos separados.
- Smoke API: 948 verificações, nenhuma falha.
- `flutter analyze`: nenhum erro ou warning; 90 informações remanescentes de nomenclatura camelCase de arquivos e APIs `withOpacity` depreciadas. O comando padrão acusa esses itens; não foram ocultados com regras novas no projeto.
- Build Flutter Web local gerado com os recursos do renderizador incluídos, sem depender do CDN para abrir a prévia.
- Fluxos no Edge nas larguras 320, 768 e 1280: configuração completa, cadastro com falha simulada de SMTP e recuperação da lista, token da URL, definição de senha, login e recusa da área de Professor à sessão de Coordenação. Conferências adicionais verificaram cadastro de turma/aluno, atualização após Escape, vínculo e boletim móvel com professor ativo. Os scripts `validar_interface.py` e `revisar_boletim.py` reproduzem as conferências; repetições rápidas podem atingir o limite de tentativas de login. Testes backend também conferem os 403.
- Credenciais não foram copiadas para código, relatório ou respostas. Alterações prévias nos registradores de plugins e no asset de logo foram preservadas.

O fechamento de etapa continua tendo o alcance original do modelo: escola e ano, não uma etapa independente por professor/turma. Agora a ação cabe ao professor vinculado, e a interface avisa o alcance antes de confirmar. Uma mudança para fechamento por turma exige nova definição de regra e alteração do modelo.

A prévia usa a escola e o banco isolados `mentorly_interface_regressao`, backend na porta 5001 e frontend na 18080. Para revisar localmente, abra http://127.0.0.1:18080 e selecione Coordenação; a conta fictícia é `validacao@escola.invalid`, senha `validacao123`. Esses valores pertencem somente ao ambiente de QA. Os testes de regressão usam outra base isolada. Não houve implantação em produção. Endereço público do app e eventuais bloqueios de SMTP devem ser definidos na hospedagem real.

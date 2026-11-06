# Perguntas da apresentação — respostas curtas

## Qual arquitetura vocês usaram?

**Resposta para decorar: cliente-servidor em camadas.**

Usamos uma arquitetura cliente-servidor organizada em camadas. O Flutter é o cliente; o Flask é
a API; e o MySQL é a persistência. No backend, separamos Route, Controller, Service e
Model/Repository. Ela lembra MVC, mas o nome mais correto para o projeto é **arquitetura em
camadas**, porque existe uma camada de Service para as regras de negócio.

## Como vocês usaram essa arquitetura?

**Resposta para decorar: tela chama, rota recebe, serviço decide e banco guarda.**

A tela Flutter chama um Service Dart, que passa pelo `ApiService` e envia HTTP/JSON. A Route Flask
confere autenticação e papel; o Controller lê a requisição; o Service valida acesso e aplica as
regras; e a Model ou o Repository usa SQL parametrizado no MySQL. A resposta percorre o caminho
contrário até a tela.

Fluxo: **Flutter → ApiService → Route → Controller → Service → Model/Repository → MySQL**.

## Por que vocês escolheram essa arquitetura?

**Resposta para decorar: separar para proteger, testar e manter.**

Porque cada parte fica com uma responsabilidade. A interface pode mudar sem reescrever o cálculo,
as regras ficam protegidas no backend e não podem ser burladas escondendo ou mostrando botões,
e cada camada pode ser testada separadamente. Também facilita encontrar erros e trabalhar em
equipe.

Arquivos para mostrar: `frontend/app_mentorly/lib/core/services/apiService.dart`,
`backend/routes/activity_routes.py`, `backend/controllers/activity_controller.py`,
`backend/services/activity/create_activity.py` e `backend/models/atividade_model.py`.

## Como o campo de e-mail é validado?

**Resposta para decorar: formato, envio e código.**

O Flutter e o backend conferem o formato. Depois o Mentorly envia um código de seis dígitos para
o endereço. A conta da Coordenação só é criada quando o código correto volta. Assim não basta
digitar um e-mail com aparência válida: a pessoa precisa ter acesso à caixa postal.

Arquivos principais: `frontend/app_mentorly/lib/core/utils/validators.dart`,
`backend/services/entrada.py`, `backend/services/auth/verificacao_duas_etapas.py` e
`backend/services/auth/cadastro_coordenacao.py`.

## Como vocês enviaram e-mail? Onde está o arquivo?

**Resposta para decorar: o Service monta, o SMTP entrega.**

O arquivo `backend/services/email_service.py` cria a mensagem e usa SMTP com TLS para entregar o
código e o convite. Servidor, conta e senha de aplicativo ficam em `backend/.env`, nunca no Git.
O cadastro de professor chama esse Service e gera um link com token único, prazo de validade e
uso único.

## Como vocês enviam o código de seis dígitos?

**Resposta para decorar: aleatório, 15 minutos e uso único.**

O backend usa o módulo seguro `secrets` do Python para sortear um número entre 000000 e 999999.
Ele salva o código ligado ao e-mail, com prazo de 15 minutos, e invalida qualquer código anterior.
O `email_service.py` envia a mensagem por SMTP com TLS. Quando o usuário confirma, o banco aceita
somente um código correto, não expirado e ainda não usado; depois o marca como usado. O sistema
também limita envios e tentativas para dificultar força bruta.

## Como cadastraram a conta de administrador?

**Resposta para decorar: admin não tem cadastro público.**

A conta é criada pelo terminal com `python scripts/criar_admin.py`. A senha não aparece enquanto
é digitada e é salva como hash, não como texto. O iniciador também pede o primeiro administrador
automaticamente se ainda não existir nenhum.

## Como é calculada a porcentagem da nota?

**Resposta para decorar: pontos, peso e escala.**

Para cada critério, o Mentorly divide os pontos obtidos pelos pontos planejados, aplica o peso do
critério e soma as contribuições. No final, converte o percentual para a nota máxima da etapa.
Atividade sem nota não vira zero, e uma atividade de 2 pontos não vira nota 10 sozinha. O cálculo
fica centralizado em `backend/services/academico/calculo.py`; o Flutter apenas exibe o resultado.

Para o consolidado do ano, entram somente etapas fechadas e completas, e o sistema calcula a
média dos percentuais dessas etapas.

A Coordenação define, em cada etapa, o peso e o máximo de pontos de Provas, Trabalhos,
Comportamento e outros critérios. O Professor escolhe um desses tipos ao criar a atividade. O
backend impede que a soma das atividades ultrapasse o máximo configurado.

## Como frontend, backend e banco foram ligados?

**Resposta para decorar: Flutter chama, Flask decide, MySQL guarda.**

O Flutter usa `ApiService` para enviar HTTP/JSON para `/api`. Uma rota Flask recebe, o Controller
trata a requisição, o Service aplica as regras e Model/Repository consulta o MySQL. A resposta
volta em JSON para a tela.

Fluxo curto: **Flutter → API Flask → Service → Model/Repository → MySQL**.

## Como vocês controlam o acesso?

**Resposta para decorar: situação, prazo e conferência em toda requisição.**

O administrador escolhe teste, assinatura paga, cortesia, pendente ou suspensa e pode definir uma
validade. Isso fica nas tabelas `acesso_escola` e `acesso_historico`. Os decorators do backend
consultam esse acesso em toda rota protegida. Se a escola estiver suspensa ou vencida, Coordenação
e Professores recebem 403, inclusive com tokens antigos; não é apenas um botão escondido na tela.

O admin usa sessão HttpOnly e proteção CSRF, e uma escola comum não consegue virar administrador.

## Como funciona a IA? Como vocês fizeram e em quais arquivos ela está?

**Resposta para decorar: o sistema calcula, a IA interpreta e o professor decide.**

Primeiro o Mentorly calcula notas, percentuais e alertas com regras fixas do backend. Depois envia
para a IA somente um resumo acadêmico, sem nome, matrícula ou e-mail do aluno. A IA transforma
esses números em pontos de atenção e sugestões pedagógicas. Ela não altera nota, não salva
atividade e não decide aprovação: o professor sempre revisa e decide.

O cliente central está em `backend/services/ia/client.py`. Os casos de uso ficam em
`backend/services/ia/gerar_insights_turma.py`, `gerar_atividade.py`, `corrigir_resposta.py` e
`gerar_feedback.py`. No Flutter, as telas principais são `insightsTurmaScreen.dart`,
`gerarAtividadeIaDialog.dart`, `corrigirRespostaIaDialog.dart` e agora a própria
`grade_notas_screen.dart`.

Frase curta para lembrar: **“Mentorly calcula; IA sugere; professor decide.”**

## Como funcionam os arquivos anexados às atividades?

**Resposta para decorar: privado, validado e ligado à atividade.**

O Professor escolhe até dez arquivos PDF, imagem, Office, TXT ou CSV de até 8 MB cada. O backend confere
o papel, o vínculo do professor com a turma, a extensão e a assinatura real do arquivo. O conteúdo
fica no MySQL ligado à atividade, participa do backup e só pode ser baixado por uma rota privada
com autorização curta. Na tela de correção, o material aparece junto das notas para evitar que o
professor procure o arquivo em outro lugar.

Arquivos principais: `backend/services/activity/anexos.py`,
`backend/models/atividade_anexo_model.py`, `backend/routes/activity_routes.py` e
`frontend/app_mentorly/lib/features/professor/widgets/atividade_anexos.dart`.

# QA, segurança e acesso comercial — 15/10/2026

Complemento desta revisão: [QA administrativo em Flutter](qa-admin-2026-10-15.md),
com os resultados atualizados e a confirmação de MySQL com SQL direto.

## Resultado e alcance

Foram revisados cálculos, permissões de escola/professor, autenticação, planilhas,
requisições repetidas, fluxos de acesso e preparação para hospedagem. Os testes
de integração usam exclusivamente `mentorly_qa_completa`, com dados fictícios.
Os testes antigos de migração usam bancos descartáveis derivados desse nome.
A base pessoal não foi usada para gravar dados de QA.

As alterações locais que já existiam no repositório foram preservadas.
O relatório descreve uma revisão de aplicação e dependências, não uma
certificação de segurança nem um teste de invasão da futura infraestrutura.

## Correções e comportamento resultante

| Área | Encontrado | Resultado |
|---|---|---|
| Nota da etapa | Poucos pontos cadastrados podiam ser ampliados para toda a escala | Base mínima por critério; 2 de 2 não vira 10 numa etapa de 10 |
| Planejamento | Uma atividade pequena podia aparentar etapa completa | Pontuação parcial, planejamento incompleto e pontos ainda não planejados explícitos |
| IA pedagógica | Algumas respostas mostravam média normalizada `/10` como número principal | Pontos reais ou aproveitamento percentual identificado, sem chamar de nota final |
| Precisão das notas | O MySQL podia arredondar silenciosamente valores com mais de duas casas | Recusa com mensagem, tanto manualmente quanto na importação |
| Importação legada | Atividade sem máximo permitia validar nota sem teto na planilha | Exige configurar o máximo antes de importar |
| Downloads | URL com separador incorreto e JWT completo na URL | Permissão de dois minutos para um único caminho; JWT não autentica pela query |
| Cliques repetidos | Chamadas iguais podiam ser enviadas juntas | POST/PUT/DELETE iguais compartilham envio em andamento; falha permite nova tentativa |
| Confirmação de fechamento | Vários diálogos podiam ser abertos antes de começar o envio | Trava começa antes da confirmação |
| Administração | Ainda não existia | Login próprio, sem cadastro público, senha com hash, sessão HttpOnly e CSRF; senha administrativa sem quantidade mínima de caracteres |
| Alteração simultânea de acesso | Duas telas poderiam sobrescrever uma liberação | Versão do registro, transação e histórico; formulário antigo é recusado |
| Autorização comercial | Sessão antiga continuaria autorizada após vencimento | Verificação de acesso no backend para coordenação e professores, inclusive downloads |
| JWT | Claims ausentes ou papel inesperado não eram validados explicitamente | Exige expiração, identidade, papel permitido e coerência da escola |
| Tentativas de autenticação | Limites só em memória e por e-mail | Limite agregado por origem, cadastro/ativação/admin protegidos e persistência MySQL em produção |
| Concorrência no limitador | Teste revelou deadlock ao disputar a mesma chave | Trava exclusiva desde o upsert; 20 chamadas simultâneas respeitam o limite |
| Login | Ausência de conta e conta desativada podiam ser diferenciadas antes da senha | Hash verificado também para conta inexistente; estado desativado só após senha correta |
| Novas senhas de escola/professor | Mínimo de seis caracteres | Mínimo de oito; login de contas existentes continua aceitando a senha já definida |
| E-mails | Cadastro de escola e edição de professor sem formato validado no servidor | Formato verificado antes de gravar/enviar |
| Planilhas | XLSX muito comprimido podia consumir muita memória | Limite de tamanho expandido, linhas, colunas e células; fechamento do workbook |
| Planilhas | Cabeçalhos repetidos sobrescreviam valores; nomes podiam virar fórmulas no Excel | Cabeçalhos repetidos recusados; nomes/matrículas exportados como texto |
| HTTP | CORS aberto e cabeçalhos de proteção incompletos | Origens explícitas, no-store em dados privados, proteção contra iframe/sniffing e CSP no admin |
| Produção | Era possível iniciar com configuração local/insegura | Verificação de HTTPS, segredos, conta MySQL, SMTP, hosts e chave de backup |
| Dependências | Avisos públicos em Flask, Werkzeug e PyJWT antigos | Versões atualizadas e nova auditoria sem avisos conhecidos no ambiente auditado |

## Regra de notas com exemplos

A parcela prevista de um critério é `nota máxima da etapa × peso / 100`.
A base é o maior valor entre a soma dos máximos das atividades cadastradas e
essa parcela. Os pontos já obtidos são aplicados nessa base. Notas ausentes
continuam ausentes; não são convertidas em zero.

Para uma etapa de 10 pontos e um critério de 100%:

- Somente uma atividade de 2 pontos, com nota 2: **2 pontos parciais**, sem nota final.
- Acrescentar uma atividade de 8 pontos ainda sem nota: os 2 pontos continuam 2.
- Lançar 4 na atividade de 8: resultado **6 de 10**.
- Se o planejamento usa uma escala maior, por exemplo 20 pontos, o total é
  ponderado na escala da etapa: 10 de 20 corresponde a 5 de 10.

A etapa só recebe resultado completo quando os critérios ativos somam 100%,
o planejamento cobre a parcela de cada critério e todas as atividades desses
critérios têm nota. O arredondamento do resultado permanece no final.
Nenhuma nota lançada foi reescrita: a mudança está no cálculo e na apresentação.
Etapas antigas que antes recebiam nota final com poucos pontos planejados podem
passar a mostrar pontuação parcial. Reabra a etapa e complete o planejamento
quando for esse o caso; confira a escala e os pesos com a coordenação.

## Planos e administração

Há um plano inicial, **Mentorly Escolar**. Cada escola guarda plano, situação,
validade e versão. Novas escolas recebem 14 dias de teste. A migração concede
uma única vez o mesmo prazo às escolas existentes, sem renovar em reinicializações.

Em `/admin`, os responsáveis podem conceder teste, assinatura paga manual,
cortesia com ou sem prazo, suspensão ou espera de liberação. A data é inclusiva
no fuso de Brasília. Mudanças preservam histórico com autor e motivo.
Suspender ou vencer não apaga dados; bloqueia as funções pedagógicas e permite
consultar a situação do acesso. A área administrativa não entrega dados dos alunos.

Cadastro da escola e criação do teste são feitos na mesma transação.
A instalação das tabelas comerciais é aditiva e pode ser repetida.

## Validação executada

| Verificação | Evidência |
|---|---|
| 282 testes unitários Python | `qa-backend-final.log` |
| 951 verificações ponta a ponta da API | `qa-smoke-api-final.log` |
| 15 testes novos com MySQL real | `qa-integracao-final.log` |
| 142 testes Flutter, incluindo acesso/cliques e larguras 320/1280 | `qa-flutter-final.log` |
| Análise Flutter: 0 erros, 0 warnings, 87 infos de estilo | `qa-flutter-analyze-final.log` |
| Build Flutter Web release, API relativa e recursos locais | `qa-build-web.log` |
| Isolamento por chaves estrangeiras e procedures | `qa-smoke-db.log` |
| Migração de ano: 24 verificações | `qa-migracao-ano.log` |
| Migração de transferência: 8 verificações | `qa-migracao-transferencia.log` |
| Migração de professor: 8 verificações | `qa-migracao-professor.log` |
| Backup criptografado + restauração real em outro banco | `qa-backup-restauracao.log` |
| Iniciador unificado, banco, backup, app/admin/API | `qa-iniciador.log` |
| Edge: login real, suspensão, cortesia, liberação e recarga | `qa-visual.log` |
| Auditoria de pacotes antes/depois | `qa-dependencias-antes.json`, `qa-dependencias-depois.json` |

O teste de restauração conferiu as tabelas de escolas, notas, administradores,
acessos e histórico, além das cinco procedures. A chave dos testes é efêmera;
as cópias sem utilidade foram removidas. O banco original não foi sobrescrito.

Capturas revisadas: `qa-admin-desktop.png`, `qa-admin-mobile.png`,
`qa-acesso-bloqueado-mobile.png`, `qa-acesso-bloqueado-desktop.png` e
`qa-acesso-liberado-desktop.png`. Não houve erro JavaScript nos fluxos testados.

## Operação e limites da entrega

- O iniciador local reúne frontend, API e administração em um único endereço.
  O primeiro administrador é criado pelo próprio usuário no terminal.
- A publicação na internet não foi realizada. Domínio, hospedagem, credenciais
  de SMTP, HTTPS do provedor e armazenamento externo dependem das contas de vocês.
- Não foram enviados e-mails reais nem feitas chamadas pagas de IA nas suítes.
  SMTP e IA usam dublês nos testes automatizados de regressão.
- O backup local é gerado antes da migração pelo iniciador. Foram entregues
  comando, criptografia, retenção, restauração e modelo de tarefa diária.
  O agendamento na hospedagem e a cópia externa ainda precisam ser configurados.
- Assinatura paga é uma liberação manual. Não há checkout nem webhook financeiro
  nesta entrega. Nenhum valor comercial ou diferenciação de recursos foi inventado.
- O agrupamento de envios evita cliques simultâneos no mesmo aplicativo.
  Não é uma garantia de execução única para todo tipo de escrita após falha de
  rede, reinício ou edição em várias abas. A administração tem versão no banco;
  notas usam chave única por aluno/atividade.
- As comparações internas de aproveitamento ainda usam percentual/escala
  comparável para ordenar atividades. A nota final oficial vem do motor acadêmico.

Guia de uso e hospedagem: [hospedagem-e-acessos.md](hospedagem-e-acessos.md).

Referências consultadas:
[segurança Flask](https://flask.palletsprojects.com/en/stable/web-security/),
[implantação Flask](https://flask.palletsprojects.com/en/stable/deploying/) e
[autorização OWASP](https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html).

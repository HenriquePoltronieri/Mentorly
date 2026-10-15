# Como abrir o Mentorly e administrar os acessos

## No seu computador: um comando

Na pasta principal do projeto, dê dois cliques em **Iniciar Mentorly.cmd**.
Ou execute no PowerShell:

```powershell
.\iniciar.ps1
```

O iniciador prepara as dependências em `.venv`, compila o aplicativo na primeira
execução, confere o MySQL e inicia tudo no mesmo servidor. Você precisa ter
Python, Flutter e MySQL instalados e os dados corretos em `backend/.env`.
Ele preserva as configurações já existentes nesse arquivo.

Se já houver banco, gera um backup criptografado antes das migrações. Uma falha
no backup interrompe a atualização para permitir conferir o motivo.
O MySQL instalado neste computador inclui o `mysqldump`; em outra máquina pode
ser necessário preencher `MYSQLDUMP_PATH` no `.env`.

No primeiro uso, o terminal pede seu nome, e-mail e uma senha administrativa
de sua escolha, sem quantidade mínima de caracteres. A senha precisa estar
preenchida e ser repetida igual. Ela não aparece enquanto você digita.
Não existe conta administrativa padrão nem cadastro público de administrador.

- Aplicativo: **http://localhost:5000**
- Administração de vocês: **http://localhost:5000/admin**
- Verificação do servidor e banco: **http://localhost:5000/health**

Mantenha o terminal aberto. Para encerrar, pressione `Ctrl+C`.
Você não precisa iniciar frontend e backend em terminais separados nesse modo.
O endereço `localhost` funciona somente neste computador. O iniciador não
publica o sistema na internet.

Depois de alterar telas Dart, atualize a versão compilada:

```powershell
.\iniciar.ps1 -Recompilar
```

Para criar outro administrador ou redefinir a senha de um administrador existente,
com o banco já preparado:

```powershell
.\.venv\Scripts\python.exe backend/scripts/criar_admin.py
```

Informar um e-mail administrativo existente redefine sua senha e invalida as
sessões administrativas anteriores. Contas de coordenação e professor são
independentes das contas administrativas.

## Como uma escola acessa

1. Abra o aplicativo e escolha **Coordenação → Criar conta**.
2. Cada nova escola recebe **14 dias de teste**, no plano inicial **Mentorly Escolar**.
3. A coordenação configura o ano letivo, cadastra professores e convida a equipe.
4. Professores entram com suas próprias contas, usando o acesso da mesma escola.

Escolas que já estavam no banco recebem um teste de 14 dias na primeira migração.
Reiniciar ou atualizar não renova esse prazo. Nenhuma nota é apagada.

No menu **Conta → Plano e acesso da escola**, a pessoa consulta plano, situação
e validade. Se o acesso vencer ou for suspenso, o aplicativo mostra essa tela.
O usuário pode sair da conta ou verificar uma nova liberação. Seus dados são
preservados; as funções pedagógicas ficam bloqueadas no servidor.

## Como vocês liberam acesso sem pagamento

1. Entre em `/admin` com o e-mail e a senha administrativos.
2. Busque a escola por nome ou e-mail.
3. Clique em **Gerenciar acesso** e escolha o plano, a situação e a validade.
4. Escreva o motivo e clique em **Salvar acesso**.

| Situação | Comportamento |
|---|---|
| Teste gratuito | Libera até a data escolhida; exige validade |
| Assinatura paga | Liberação manual após vocês conferirem o recebimento; exige validade |
| Cortesia | Libera sem cobrança; pode ter validade ou ficar sem prazo |
| Suspensa | Bloqueia imediatamente o uso, inclusive com sessão antiga |
| Aguardando liberação | Mantém a conta cadastrada com uso bloqueado |

A validade inclui o dia inteiro no horário de Brasília. O painel registra quem
alterou, quando e por qual motivo. Reenvio do mesmo formulário não duplica a
alteração; uma versão antiga pede para atualizar a página.

Para demonstrar a uma escola, cadastre uma conta com dados fictícios e marque
**Cortesia**. Não é necessário comprar assinatura nem simular pagamento.
A administração gerencia o acesso e vê os dados de cadastro das escolas; ela
não abre as notas e informações dos alunos.

O painel faz parte do aplicativo Flutter. `/admin` abre a mesma aplicação na
tela administrativa; não é preciso iniciar outro frontend. O login administrativo
usa cookie HttpOnly e proteção CSRF, separado do login das escolas. Ao sair,
as sessões anteriores dessa mesma conta administrativa são invalidadas.

O banco continua sendo **MySQL**, com consultas SQL diretas pelo driver Python
PyMySQL, sem ORM. Não foi adotado outro banco para planos ou administradores.

Existe um plano inicial. O cadastro de planos está na tabela `plano`; preços,
checkout e cobrança automática não foram implementados nesta entrega.

## Hospedar na internet

O código está preparado para hospedagem WSGI com MySQL. A contratação, o domínio,
o SMTP real e o agendamento externo dependem das contas de vocês.
Use `deploy/production.env.example` como referência. Não publique seu `.env`.

1. Prepare um MySQL compatível com o schema e as cinco procedures do projeto.
   Crie o banco no painel do provedor. Use um usuário com senha e privilégios
   limitados a esse banco. Evite `root`; use credencial de migração separada
   quando o provedor permitir. Configure `DB_SSL_CA` se o banco exigir TLS.
2. Instale `backend/requirements.txt` em um ambiente virtual da hospedagem.
3. Configure `SECRET_KEY` longa, `APP_ENV=production`, domínios autorizados,
   `FRONTEND_URL` HTTPS, SMTP com TLS/SSL, `BACKUP_KEY` e a pasta privada de backups.
   O aplicativo recusa iniciar em produção com configurações essenciais inseguras.
4. Compile o Flutter localmente e envie **somente `build/web`** como frontend:

   ```powershell
   cd frontend/app_mentorly
   flutter build web --release --no-web-resources-cdn --dart-define=API_URL=/api
   ```

   Configure `WEB_BUILD_DIR` com o caminho absoluto dessa pasta no servidor.
   Para frontend em outro domínio, compile com
   `--dart-define=API_URL=https://api.seu-dominio.com.br/api` e autorize sua origem
   em `CORS_ORIGINS`. O mesmo domínio simplifica a operação.
5. Com o banco já criado pelo provedor, aplique as migrações e procedures:

   ```bash
   cd backend
   python -c "from database.connection import install_schema, install_procedures; install_schema(); install_procedures()"
   python scripts/criar_admin.py
   ```

6. Configure a aplicação WSGI para importar `app` de `backend/wsgi.py`, com
   `backend` no caminho de importação. Se o provedor pedir um arquivo WSGI:

   ```python
   import sys
   sys.path.insert(0, '/caminho/absoluto/Mentorly/backend')
   from wsgi import app as application
   ```

   A hospedagem fornece o servidor WSGI. O iniciador local usa apenas a
   biblioteca padrão Python; ele não deve ser exposto diretamente na internet.
   Coloque HTTPS no proxy/provedor. `python app.py` é o servidor de desenvolvimento.
   Ative `TRUSTED_PROXY_HOPS=1` **somente** quando todas as conexões passarem por
   um proxy confiável que substitua os cabeçalhos de encaminhamento.
7. Confira `/health`, login de escola, convite de professor, administração,
   suspensão/cortesia, backup e restauração no ambiente da hospedagem.

Na internet, o uso será por `https://seu-dominio.com.br` e a administração por
`https://seu-dominio.com.br/admin`. Escolas e professores só abrem o navegador;
o servidor da hospedagem permanece ligado por vocês.

Os limites de tentativas usam o MySQL em produção, compartilhados entre os
processos. Em desenvolvimento usam memória para facilitar os testes.

## E-mails

Preencha `MAIL_SERVER`, `MAIL_PORT`, `MAIL_USERNAME`, `MAIL_PASSWORD`, `MAIL_FROM`
e TLS/SSL. A senha deve ser uma credencial de envio do provedor; para Gmail,
uma senha de aplicativo quando disponível na conta. Configure o remetente
autorizado e o domínio no painel do provedor.

O SMTP real não é testado pelas suítes para não enviar mensagens a terceiros.
Sem entrega, a coordenação ainda consegue copiar o convite e compartilhar pelo
canal que já usa. Em produção, `DEV_EXPOSE_AUTH_CODES` e `FLASK_DEBUG` ficam desligados.

## Backups e recuperação

O iniciador cria uma `BACKUP_KEY` ausente sem mostrá-la no terminal e a guarda
no `.env` local. Guarde uma cópia segura dessa chave separada dos backups.
Sem a chave, não é possível recuperar os arquivos.

Para gerar manualmente a partir da raiz:

```powershell
.\.venv\Scripts\python.exe backend/scripts/backup.py
```

O script usa `mysqldump`, inclui tabelas e procedures, comprime, criptografa e
verifica a leitura do arquivo antes de finalizar. Guarda as últimas 14 cópias
por padrão; ajuste `BACKUP_RETENCAO`. A senha do MySQL não vai nos argumentos
do comando. Proteja a conta do sistema operacional que executa os backups.

Na hospedagem, crie uma tarefa diária conforme `deploy/backup.cron.example`,
ajuste caminhos/fuso e copie os arquivos `.enc` para armazenamento externo
privado. Esse agendamento e a cópia externa não são criados automaticamente.
No Windows, o Agendador de Tarefas pode executar o Python da `.venv` com o
argumento `backend/scripts/backup.py` e a pasta principal como diretório inicial.

Para recuperar sem sobrescrever a base original:

```powershell
.\.venv\Scripts\python.exe backend/scripts/restaurar_backup.py backups/ARQUIVO.sql.gz.enc --banco mentorly_restauracao_conferencia
```

Escolha um nome de banco novo com o prefixo exigido. O script recusa um banco
que já existe. Confira os dados restaurados antes de alterar `DB_NAME` no `.env`.
Uma credencial que só acessa o banco de produção não consegue criar o banco de
recuperação; use uma credencial autorizada para essa operação.

Referências usadas: [implantação Flask](https://flask.palletsprojects.com/en/stable/deploying/),
[segurança Flask](https://flask.palletsprojects.com/en/stable/web-security/) e
[autorização OWASP](https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html).

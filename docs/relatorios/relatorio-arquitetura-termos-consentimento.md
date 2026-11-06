# Arquitetura dos termos e do consentimento

Os dois DOCX em `docs/termos/` têm versões de texto publicadas em `backend/termos_docs/`. O serviço `backend/services/termos.py` identifica cada versão pelo SHA-256, valida as escolhas e consulta a decisão vigente. A tabela `decisao_termo` registra cada aceite, recusa ou revogação com usuário, versão e data, sem apagar o histórico.

No cadastro da Coordenação e no primeiro acesso do Professor, as duas escolhas são explícitas. Conta ou senha e decisões são gravadas na mesma transação. O Flutter mostra os documentos e oferece a tela `/termos` para contas antigas, novas versões e revisão das escolhas. A API expõe os documentos, o estado atual, o registro das decisões e o histórico em `/api/termos/`.

## Travas aplicadas pelo backend

- **Termo de Uso:** sem aceite da versão vigente, as rotas protegidas respondem `403 termos_pendentes`. O usuário ainda pode consultar os termos e registrar sua decisão.
- **Consentimento:** a recusa ou revogação mantém o uso básico, mas os cinco endpoints de IA respondem `403 consentimento_necessario`.
- **Versão:** a API rejeita decisões enviadas com hash antigo. Ao publicar outra versão, o usuário precisa decidir novamente.

Os decorators de autenticação consultam o banco em cada chamada protegida. Assim, os bloqueios também valem para requisições diretas à API; o redirecionamento no Flutter apenas conduz o usuário à tela correta.

**Validação:** passaram 9 testes Flutter, 12 testes de regressão, 28 de segurança e 16 de integração. O smoke test amplo ainda para em um cenário acadêmico posterior, sem relação com os termos. Antes da publicação externa, é preciso preencher os dados do controlador nos DOCX e revisar a referência à Política de Privacidade.

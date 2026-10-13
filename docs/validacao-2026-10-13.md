# Validação antes do push — 13/10/2026

## Resultados

| Verificação | Resultado |
| --- | --- |
| `python backend/scripts/test_unitarios.py` | 240 testes passaram |
| `flutter test --no-pub` | 126 testes passaram |
| `python backend/scripts/test_correcoes_mentorly.py` | 10 testes de integração passaram |
| `python backend/scripts/smoke_api.py` | 951 verificações, nenhuma falha |
| `python backend/scripts/smoke_db.py` | Leitura, escrita, isolamento, ano letivo e procedures passaram |
| Migrações de ano letivo, transferência e professor habilitado | 24 + 8 + 8 verificações passaram |
| `flutter analyze --no-pub --no-fatal-infos` | Nenhum erro ou warning; 87 infos de estilo existentes |
| `flutter build web --no-pub` | Compilação de produção e dry run Wasm passaram |
| `python -m compileall -q backend` | Todos os arquivos Python compilaram |

A API e o banco foram testados na base separada `mentorly_push_validacao`.
Os testes de integração usam `mentorly_correcao_regressao`; as migrações usam
bases temporárias próprias. Nenhum teste utilizou a base pessoal, enviou
e-mail real ou chamou um provedor de IA externo. A qualidade do texto gerado
pelo provedor não é garantida por estes testes; seus contratos, erros e uso
dos fatos são cobertos por dublês.

## Ajustes durante a validação

- O teste amplo da API foi atualizado para as permissões atuais: somente a
  Coordenação gerencia alunos. O professor continua lançando e importando notas.
- As verificações de risco sem datas agora aguardam o fechamento e também
  verificam a ausência de alerta durante a etapa aberta.
- O chat retorna 404 para aluno inexistente, com uma regressão específica.
- A verificação de arquivos preparados para o commit não encontrou credenciais
  nos padrões examinados. O `.env`, builds, logs e capturas locais de QA não
  fazem parte do envio.

As regras do acompanhamento estão em [acompanhamento-etapa.md](acompanhamento-etapa.md).

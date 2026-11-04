# Diagrama de classes e entidades do Mentorly

Este desenho foi conferido com as Models em `backend/models/` e com as tabelas dos três arquivos de instalação: `schema.sql`, `professor_workspace.sql` e `comercial.sql`. Ele representa o que o sistema realmente persiste hoje, inclusive anexos, situações de entrega, acompanhamento pedagógico e controle administrativo.

```mermaid
classDiagram
    class Coordenacao {
      +int id
      +string nome
      +string email
      +string senha_hash
      +string telefone
    }
    class AnoLetivo {
      +int id
      +int coordenacao_id
      +int ano
      +enum status
    }
    class Professor {
      +int id
      +int coordenacao_id
      +string nome
      +string email
      +string disciplina
      +string senha_hash
      +bool habilitado
      +string convite_token
      +datetime convite_expira_em
    }
    class Turma {
      +int id
      +int coordenacao_id
      +int ano_letivo
      +string nome
      +string disciplina
      +string turno
    }
    class ProfessorTurma {
      +int id
      +int coordenacao_id
      +int professor_id
      +int turma_id
    }
    class Aluno {
      +int id
      +int turma_id
      +string nome
      +string matricula
      +string email
    }
    class AlunoTurmaHistorico {
      +int id
      +int aluno_id
      +int coordenacao_id
      +int turma_id
      +int ano_letivo
      +date data_inicio
      +date data_fim
      +string motivo
    }
    class Etapa {
      +int id
      +int coordenacao_id
      +int ano_letivo
      +string nome
      +int ordem
      +decimal nota_minima
      +decimal nota_maxima
      +bool ativa
      +bool fechada
    }
    class Criterio {
      +int id
      +int coordenacao_id
      +int etapa_id
      +string nome
      +decimal peso
      +decimal nota_maxima
    }
    class Atividade {
      +int id
      +int coordenacao_id
      +int turma_id
      +int professor_id
      +int etapa_id
      +int criterio_id
      +string titulo
      +text descricao
      +datetime data_entrega
      +decimal nota_maxima
    }
    class AtividadeAnexo {
      +int id
      +int coordenacao_id
      +int atividade_id
      +int professor_id
      +string nome_original
      +string tipo_mime
      +int tamanho_bytes
      +blob conteudo
    }
    class Nota {
      +int id
      +int atividade_id
      +int aluno_id
      +decimal valor
      +string observacao
    }
    class AtividadeSituacao {
      +int atividade_id
      +int aluno_id
      +string situacao
    }
    class AcompanhamentoPedagogico {
      +int id
      +int professor_id
      +int turma_id
      +int aluno_id
      +text descricao
      +date retorno_em
      +bool concluido
    }

    Coordenacao "1" *-- "0..*" AnoLetivo : configura
    Coordenacao "1" *-- "0..*" Professor : cadastra
    Coordenacao "1" *-- "0..*" Turma : mantém
    AnoLetivo "1" o-- "0..*" Turma : organiza
    AnoLetivo "1" o-- "0..*" Etapa : organiza
    Professor "1" -- "0..*" ProfessorTurma : participa
    Turma "1" -- "0..*" ProfessorTurma : recebe
    Turma "1" *-- "0..*" Aluno : matrícula atual
    Aluno "1" *-- "1..*" AlunoTurmaHistorico : preserva histórico
    Turma "1" -- "0..*" AlunoTurmaHistorico : registra período
    AnoLetivo "1" -- "0..*" AlunoTurmaHistorico : identifica ano
    Etapa "1" *-- "0..*" Criterio : distribui pontos
    Turma "1" *-- "0..*" Atividade : recebe
    Professor "1" -- "0..*" Atividade : cria
    Etapa "1" -- "0..*" Atividade : classifica
    Criterio "1" -- "0..*" Atividade : limita pontuação
    Atividade "1" *-- "0..*" AtividadeAnexo : possui
    Professor "1" -- "0..*" AtividadeAnexo : envia
    Atividade "1" *-- "0..*" Nota : recebe
    Aluno "1" -- "0..*" Nota : obtém
    Atividade "1" *-- "0..*" AtividadeSituacao : registra
    Aluno "1" -- "0..*" AtividadeSituacao : tem situação
    Professor "1" -- "0..*" AcompanhamentoPedagogico : acompanha
    Turma "1" -- "0..*" AcompanhamentoPedagogico : contextualiza
    Aluno "1" -- "0..*" AcompanhamentoPedagogico : recebe intervenção
```

`ProfessorTurma` resolve a relação muitos-para-muitos entre professores e turmas. `Nota` e `AtividadeSituacao` são diferentes de propósito: a primeira guarda um valor numérico; a segunda guarda “Ausente”, “Não entregou” ou “Não corrigido”, sem transformar pendência em nota zero. `AtividadeAnexo` guarda o arquivo no banco, ligado à atividade, para que ele entre no backup e não fique exposto em uma pasta pública.

## Autenticação, administração e infraestrutura

```mermaid
classDiagram
    class CodigoVerificacao {
      +int id
      +string email
      +string codigo
      +datetime expira_em
      +bool usado
    }
    class Administrador {
      +int id
      +string nome
      +string email
      +string senha_hash
      +bool ativo
      +int versao_sessao
    }
    class Plano {
      +string codigo
      +string nome
    }
    class AcessoEscola {
      +int coordenacao_id
      +string plano_codigo
      +enum situacao
      +date valido_ate
      +int versao
    }
    class AcessoHistorico {
      +int id
      +int coordenacao_id
      +int administrador_id
      +string situacao
      +string plano_codigo
      +date valido_ate
      +string motivo
    }
    class LimiteRequisicao {
      +string chave
      +double expira_em
      +int contador
    }

    Coordenacao "1" *-- "0..1" AcessoEscola : possui acesso
    Plano "1" o-- "0..*" AcessoEscola : define plano
    Coordenacao "1" *-- "0..*" AcessoHistorico : possui auditoria
    Administrador "1" -- "0..*" AcessoHistorico : registra mudança
```

`CodigoVerificacao` fica ligado ao e-mail, sem chave estrangeira, porque é criado antes da conta existir. `LimiteRequisicao` é uma entidade de infraestrutura usada para impedir abuso em login, códigos, convites e IA; ela não se relaciona ao domínio escolar. `ConfiguracaoAno`, em `backend/models/configuracao_ano_model.py`, não é tabela nem entidade: é uma fachada de persistência transacional que atualiza etapas e critérios juntos.

As entidades CRUD herdam de `db.Model`, mas o projeto usa SQL parametrizado nos métodos das Models e dos Repositories. `AtividadeSituacao` e `AcompanhamentoPedagogico` são tabelas ativas acessadas pelo service de trabalho do professor e ainda não têm uma classe ORM própria; por isso aparecem no diagrama como entidades persistidas, e não como classes Python.

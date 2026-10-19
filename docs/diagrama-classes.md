# Diagrama de classes do domínio

As classes abaixo estão em `backend/models/` e herdam de `db.Model`. Os atributos correspondem às colunas mapeadas no MySQL. As multiplicidades representam os vínculos do domínio; o isolamento entre escolas também é garantido pelas chaves estrangeiras compostas em `backend/database/schema.sql`.

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
      +string status
    }
    class Professor {
      +int id
      +int coordenacao_id
      +string nome
      +string email
      +bool habilitado
      +string convite_token
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
      +int turma_id
      +int ano_letivo
      +date data_inicio
      +date data_fim
    }
    class Etapa {
      +int id
      +int coordenacao_id
      +int ano_letivo
      +string nome
      +int ordem
      +bool fechada
    }
    class Criterio {
      +int id
      +int etapa_id
      +string nome
      +decimal peso
      +decimal nota_maxima
    }
    class Atividade {
      +int id
      +int turma_id
      +int professor_id
      +int etapa_id
      +int criterio_id
      +string titulo
      +decimal nota_maxima
    }
    class Nota {
      +int id
      +int atividade_id
      +int aluno_id
      +decimal valor
    }
    class CodigoVerificacao {
      +int id
      +string email
      +string codigo
      +datetime expira_em
    }
    class Administrador {
      +int id
      +string nome
      +string email
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
      +string situacao
      +date valido_ate
      +int versao
    }
    class AcessoHistorico {
      +int id
      +int coordenacao_id
      +int administrador_id
      +string situacao
      +string motivo
    }
    Coordenacao "1" *-- "0..*" AnoLetivo : configura
    Coordenacao "1" *-- "0..*" Professor : cadastra
    Coordenacao "1" *-- "0..*" Turma : mantém
    AnoLetivo "1" o-- "0..*" Turma : organiza
    AnoLetivo "1" o-- "0..*" Etapa : organiza
    Professor "1" -- "0..*" ProfessorTurma : vínculos
    Turma "1" -- "0..*" ProfessorTurma : vínculos
    Turma "1" *-- "0..*" Aluno : matricula
    Aluno "1" *-- "0..*" AlunoTurmaHistorico : histórico
    Turma "1" -- "0..*" AlunoTurmaHistorico : período
    Etapa "1" *-- "0..*" Criterio : define
    Turma "1" *-- "0..*" Atividade : recebe
    Professor "1" -- "0..*" Atividade : cria
    Etapa "1" -- "0..*" Atividade : avalia
    Criterio "1" -- "0..*" Atividade : classifica
    Atividade "1" *-- "0..*" Nota : recebe
    Aluno "1" -- "0..*" Nota : obtém
    Coordenacao "1" *-- "0..1" AcessoEscola : acesso
    Plano "1" o-- "0..*" AcessoEscola : contratado
    Coordenacao "1" *-- "0..*" AcessoHistorico : auditoria
    Administrador "1" -- "0..*" AcessoHistorico : registra
```

`ProfessorTurma` representa a relação muitos-para-muitos entre professores e turmas. `CodigoVerificacao` é usado no fluxo de autenticação e não possui chave estrangeira. Não há herança entre entidades do domínio; todas herdam da infraestrutura `db.Model`. Os campos de data, descrição e configuração adicionais aparecem nas Models e no schema SQL, mas foram omitidos do desenho para manter a leitura.

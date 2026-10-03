-- =====================================================
-- Mentorly - Schema do banco de dados (MySQL 8+)
--
-- Regra central do desenho: cada login de Coordenacao e uma ESCOLA.
-- Todo dado pedagogico pendura, direta ou indiretamente, em uma
-- coordenacao_id. As tabelas de vinculo carregam a coordenacao_id
-- de proposito (redundancia intencional) para que o proprio MySQL
-- impeca cruzar dados de escolas diferentes.
-- =====================================================

-- -----------------------------------------------------
-- coordenacao = escola. E a raiz do isolamento.
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS coordenacao (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    nome        VARCHAR(150) NOT NULL,
    email       VARCHAR(150) NOT NULL,
    senha_hash  VARCHAR(255) NOT NULL,
    telefone    VARCHAR(30)  NULL,
    created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_coordenacao_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- ano_letivo: o cadastro de anos de CADA escola (Marco 6).
--
-- E a fonte de verdade de "quais anos a escola tem" e de "qual e o atual".
-- turma e etapa guardam o numero do ano, mas esse numero e chave estrangeira
-- composta (coordenacao_id, ano_letivo) para ca: o banco recusa turma ou
-- etapa de um ano que a escola nao cadastrou, e nunca cruza escolas.
--
-- status: planejamento (preparando o proximo ano), atual (o ano em curso,
-- que o dashboard e a etapa atual usam) ou encerrado (dados continuam
-- disponiveis; so nao nasce turma nem etapa nova nele).
--
-- Uma escola tem NO MAXIMO um ano atual: atual_unico vale 1 so quando
-- status = 'atual' e NULL nos demais, e o indice unico permite varios NULL
-- mas nenhum 1 repetido. E o jeito de o proprio MySQL garantir a regra sem
-- trigger. A coluna e gerada: nunca entra em INSERT nem UPDATE.
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS ano_letivo (
    id             INT AUTO_INCREMENT PRIMARY KEY,
    coordenacao_id INT NOT NULL,
    ano            INT NOT NULL,
    status         ENUM('planejamento', 'atual', 'encerrado')
                       NOT NULL DEFAULT 'planejamento',
    atual_unico    TINYINT GENERATED ALWAYS AS (IF(status = 'atual', 1, NULL)) VIRTUAL,
    created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_ano_letivo_escola_ano (coordenacao_id, ano),
    UNIQUE KEY uk_ano_letivo_atual (coordenacao_id, atual_unico),
    CONSTRAINT fk_ano_letivo_coordenacao
        FOREIGN KEY (coordenacao_id) REFERENCES coordenacao (id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- professor pertence a UMA coordenacao.
-- senha_hash comeca nulo: a coordenacao cadastra o professor e ele
-- recebe um convite por email para criar a propria senha.
--
-- uk_professor_escola (coordenacao_id, id) parece redundante com a PK,
-- mas e ela que da o indice necessario para a FK composta de
-- professor_turma logo abaixo. O mesmo vale para turma.
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS professor (
    id                INT AUTO_INCREMENT PRIMARY KEY,
    coordenacao_id    INT NOT NULL,
    nome              VARCHAR(150) NOT NULL,
    email             VARCHAR(150) NOT NULL,
    disciplina        VARCHAR(100) NULL,
    senha_hash        VARCHAR(255) NULL,
    habilitado        TINYINT(1) NOT NULL DEFAULT 1,
    convite_token     VARCHAR(64)  NULL,
    convite_expira_em DATETIME     NULL,
    created_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_professor_email (email),
    UNIQUE KEY uk_professor_escola (coordenacao_id, id),
    KEY idx_professor_coordenacao (coordenacao_id),
    KEY idx_professor_habilitado (coordenacao_id, habilitado),
    KEY idx_professor_convite (convite_token),
    CONSTRAINT fk_professor_coordenacao
        FOREIGN KEY (coordenacao_id) REFERENCES coordenacao (id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- turma pertence a UMA coordenacao (ponto critico do desenho) e a UM ano
-- letivo dessa escola (Marco 6). ano_letivo e o numero do ano e, ao mesmo
-- tempo, a FK composta para ano_letivo: e a unica fonte do ano da turma.
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS turma (
    id             INT AUTO_INCREMENT PRIMARY KEY,
    coordenacao_id INT NOT NULL,
    nome           VARCHAR(120) NOT NULL,
    descricao      TEXT NULL,
    disciplina     VARCHAR(100) NULL,
    turno          VARCHAR(30)  NULL,
    ano_letivo     INT NOT NULL,
    created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_turma_nome_escola (coordenacao_id, nome),
    UNIQUE KEY uk_turma_escola (coordenacao_id, id),
    KEY idx_turma_ano (coordenacao_id, ano_letivo),
    CONSTRAINT fk_turma_coordenacao
        FOREIGN KEY (coordenacao_id) REFERENCES coordenacao (id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_turma_ano_letivo
        FOREIGN KEY (coordenacao_id, ano_letivo)
        REFERENCES ano_letivo (coordenacao_id, ano)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- professor_turma: o vinculo que a Coordenacao cria.
-- Um professor pode ter varias turmas; uma turma pode ter varios professores.
--
-- As duas FKs sao COMPOSTAS e passam pela coordenacao_id. Efeito pratico:
-- vincular o professor da escola A a uma turma da escola B e recusado pelo
-- proprio banco, nao so pela query. O isolamento vira invariante.
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS professor_turma (
    id             INT AUTO_INCREMENT PRIMARY KEY,
    coordenacao_id INT NOT NULL,
    professor_id   INT NOT NULL,
    turma_id       INT NOT NULL,
    created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_professor_turma (professor_id, turma_id),
    KEY idx_pt_turma (coordenacao_id, turma_id),
    KEY idx_pt_professor (coordenacao_id, professor_id),
    CONSTRAINT fk_pt_turma
        FOREIGN KEY (coordenacao_id, turma_id) REFERENCES turma (coordenacao_id, id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_pt_professor
        FOREIGN KEY (coordenacao_id, professor_id) REFERENCES professor (coordenacao_id, id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- aluno chega na escola pela turma (turma_id -> turma.coordenacao_id).
-- Nao duplica coordenacao_id porque aluno nunca muda de escola sem
-- mudar de turma.
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS aluno (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    turma_id   INT NOT NULL,
    nome       VARCHAR(150) NOT NULL,
    matricula  VARCHAR(50)  NULL,
    email      VARCHAR(150) NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_aluno_matricula_turma (turma_id, matricula),
    KEY idx_aluno_turma (turma_id),
    CONSTRAINT fk_aluno_turma
        FOREIGN KEY (turma_id) REFERENCES turma (id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- aluno_turma_historico: trilha de matriculas do aluno.
--
-- aluno.turma_id continua sendo a referencia rapida e a fonte das listas
-- atuais. Esta tabela preserva cada periodo: ha exatamente um vinculo aberto
-- por aluno (data_fim NULL), e a transferencia fecha o anterior e abre o
-- proximo na mesma transacao que atualiza aluno.turma_id.
--
-- coordenacao_id e redundante de proposito: a FK composta com turma impede
-- que um historico aponte uma turma de outra escola. ano_letivo tambem e FK
-- para o cadastro de anos da mesma escola, portanto nao fica como numero
-- solto. ON DELETE CASCADE em aluno acompanha a politica ja existente de
-- exclusao fisica do aluno e evita orfaos.
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS aluno_turma_historico (
    id                       INT AUTO_INCREMENT PRIMARY KEY,
    aluno_id                 INT NOT NULL,
    coordenacao_id           INT NOT NULL,
    turma_id                 INT NOT NULL,
    ano_letivo               INT NOT NULL,
    data_inicio              DATE NOT NULL,
    data_fim                 DATE NULL,
    motivo                   VARCHAR(255) NULL,
    vinculo_aberto_aluno_id  INT GENERATED ALWAYS AS
        (IF(data_fim IS NULL, aluno_id, NULL)) VIRTUAL,
    created_at               DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at               DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_ath_vinculo_aberto (vinculo_aberto_aluno_id),
    KEY idx_ath_aluno_inicio (aluno_id, data_inicio, id),
    KEY idx_ath_turma (coordenacao_id, turma_id),
    KEY idx_ath_ano (coordenacao_id, ano_letivo),
    CONSTRAINT fk_ath_aluno
        FOREIGN KEY (aluno_id) REFERENCES aluno (id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_ath_turma
        FOREIGN KEY (coordenacao_id, turma_id)
        REFERENCES turma (coordenacao_id, id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_ath_ano_letivo
        FOREIGN KEY (coordenacao_id, ano_letivo)
        REFERENCES ano_letivo (coordenacao_id, ano)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- etapa: configuracao PADRAO DA ESCOLA para um ano letivo.
-- Nao e recriada a cada acesso: a chave (coordenacao_id, ano_letivo, ordem)
-- garante que reconfigurar atualiza em vez de duplicar. ano_letivo e FK
-- composta para o cadastro de anos da escola (Marco 6); o indice dessa FK e
-- o proprio uk_etapa_ordem, que comeca por (coordenacao_id, ano_letivo).
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS etapa (
    id             INT AUTO_INCREMENT PRIMARY KEY,
    coordenacao_id INT NOT NULL,
    nome           VARCHAR(80) NOT NULL,
    ordem          INT NOT NULL,
    ano_letivo     INT NOT NULL,
    data_inicio    DATE NULL,
    data_fim       DATE NULL,
    nota_minima    DECIMAL(5,2) NULL,
    nota_maxima    DECIMAL(5,2) NULL,
    ativa          TINYINT(1) NOT NULL DEFAULT 1,
    fechada        TINYINT(1) NOT NULL DEFAULT 0,
    created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_etapa_ordem (coordenacao_id, ano_letivo, ordem),
    UNIQUE KEY uk_etapa_escola (coordenacao_id, id),
    CONSTRAINT fk_etapa_coordenacao
        FOREIGN KEY (coordenacao_id) REFERENCES coordenacao (id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_etapa_ano_letivo
        FOREIGN KEY (coordenacao_id, ano_letivo)
        REFERENCES ano_letivo (coordenacao_id, ano)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- criterio de avaliacao dentro de uma etapa (Provas, Trabalhos, ...).
-- FK composta com a etapa para nao cruzar escolas.
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS criterio (
    id             INT AUTO_INCREMENT PRIMARY KEY,
    coordenacao_id INT NOT NULL,
    etapa_id       INT NOT NULL,
    nome           VARCHAR(80) NOT NULL,
    peso           DECIMAL(5,2) NOT NULL DEFAULT 0,
    nota_maxima    DECIMAL(5,2) NOT NULL DEFAULT 10,
    created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_criterio_nome_etapa (etapa_id, nome),
    UNIQUE KEY uk_criterio_escola (coordenacao_id, id),
    KEY idx_criterio_etapa (coordenacao_id, etapa_id),
    CONSTRAINT fk_criterio_etapa
        FOREIGN KEY (coordenacao_id, etapa_id) REFERENCES etapa (coordenacao_id, id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- atividade e conteudo pedagogico: so o Professor cria.
-- professor_id nunca vem do cliente, sai sempre do token.
--
-- coordenacao_id e redundante de proposito, pela mesma razao de
-- professor_turma: as FKs para turma, etapa e criterio sao COMPOSTAS e
-- passam pela escola, entao o proprio MySQL recusa uma atividade que use
-- a etapa ou o criterio de outra coordenacao. Um id adulterado no corpo da
-- requisicao nao atravessa nem que o service falhe.
--
-- etapa_id e criterio_id continuam NULL-aveis por causa das atividades
-- legadas, criadas antes desta regra. Em FK composta o MySQL nao checa a
-- constraint quando alguma coluna da chave e NULL, entao a linha antiga
-- segue valida - nenhum dado precisa ser destruido.
--
-- As duas FKs usam ON DELETE RESTRICT, nao SET NULL: e o unico modo valido
-- quando uma coluna da chave (coordenacao_id) e NOT NULL - SET NULL exigiria
-- zerar as duas colunas juntas, o que violaria o NOT NULL. Na pratica isso
-- significa que a Coordenacao nao pode excluir uma etapa ou criterio que
-- ja tenha atividade usando - o que e a regra certa mesmo.
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS atividade (
    id             INT AUTO_INCREMENT PRIMARY KEY,
    coordenacao_id INT NOT NULL,
    turma_id       INT NOT NULL,
    professor_id   INT NOT NULL,
    etapa_id       INT NULL,
    criterio_id    INT NULL,
    titulo         VARCHAR(200) NOT NULL,
    descricao      TEXT NULL,
    data_entrega   DATETIME NULL,
    nota_maxima    DECIMAL(5,2) NULL,
    created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    KEY idx_atividade_turma (coordenacao_id, turma_id),
    KEY idx_atividade_professor (professor_id),
    KEY idx_atividade_etapa (coordenacao_id, etapa_id),
    KEY idx_atividade_criterio (coordenacao_id, criterio_id),
    CONSTRAINT fk_atividade_turma
        FOREIGN KEY (coordenacao_id, turma_id) REFERENCES turma (coordenacao_id, id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_atividade_professor
        FOREIGN KEY (professor_id) REFERENCES professor (id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_atividade_etapa
        FOREIGN KEY (coordenacao_id, etapa_id) REFERENCES etapa (coordenacao_id, id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_atividade_criterio
        FOREIGN KEY (coordenacao_id, criterio_id) REFERENCES criterio (coordenacao_id, id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- nota: uma por (atividade, aluno). Lancada so pelo Professor.
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS nota (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    atividade_id INT NOT NULL,
    aluno_id     INT NOT NULL,
    valor        DECIMAL(5,2) NOT NULL,
    observacao   VARCHAR(255) NULL,
    created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_nota_atividade_aluno (atividade_id, aluno_id),
    KEY idx_nota_aluno (aluno_id),
    CONSTRAINT fk_nota_atividade
        FOREIGN KEY (atividade_id) REFERENCES atividade (id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_nota_aluno
        FOREIGN KEY (aluno_id) REFERENCES aluno (id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- codigo_verificacao: verificacao em duas etapas do login/cadastro.
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS codigo_verificacao (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    email      VARCHAR(150) NOT NULL,
    codigo     VARCHAR(10)  NOT NULL,
    expira_em  DATETIME NOT NULL,
    usado      TINYINT(1) NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_codigo_email (email, usado)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

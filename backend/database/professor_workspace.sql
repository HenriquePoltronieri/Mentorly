-- Extensoes aditivas: nenhuma nota ou regra de calculo e alterada.
CREATE TABLE IF NOT EXISTS atividade_situacao (
    atividade_id INT NOT NULL,
    aluno_id INT NOT NULL,
    situacao VARCHAR(30) NOT NULL,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (atividade_id, aluno_id),
    FOREIGN KEY (atividade_id) REFERENCES atividade(id) ON DELETE CASCADE,
    FOREIGN KEY (aluno_id) REFERENCES aluno(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS acompanhamento_pedagogico (
    id INT AUTO_INCREMENT PRIMARY KEY,
    professor_id INT NOT NULL,
    turma_id INT NOT NULL,
    aluno_id INT NOT NULL,
    descricao TEXT NOT NULL,
    retorno_em DATE NOT NULL,
    concluido TINYINT(1) NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_acompanhamento_professor (professor_id, retorno_em),
    FOREIGN KEY (professor_id) REFERENCES professor(id) ON DELETE CASCADE,
    FOREIGN KEY (turma_id) REFERENCES turma(id) ON DELETE CASCADE,
    FOREIGN KEY (aluno_id) REFERENCES aluno(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

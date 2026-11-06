CREATE TABLE IF NOT EXISTS decisao_termo (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    coordenacao_id INT NOT NULL,
    professor_id INT NULL,
    documento ENUM('uso', 'consentimento') NOT NULL,
    versao VARCHAR(32) NOT NULL,
    sha256 CHAR(64) NOT NULL,
    decisao ENUM('aceito', 'recusado', 'revogado') NOT NULL,
    registrado_em DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    KEY idx_decisao_coordenacao (coordenacao_id, professor_id, documento, id),
    CONSTRAINT fk_decisao_coordenacao FOREIGN KEY (coordenacao_id)
        REFERENCES coordenacao(id) ON DELETE CASCADE,
    CONSTRAINT fk_decisao_professor FOREIGN KEY (professor_id)
        REFERENCES professor(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

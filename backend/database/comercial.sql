-- Instalacao aditiva: nunca apaga escolas, notas ou senhas existentes.
CREATE TABLE IF NOT EXISTS administrador (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(150) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    senha_hash VARCHAR(255) NOT NULL,
    ativo BOOLEAN NOT NULL DEFAULT TRUE,
    versao_sessao INT NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS plano (
    codigo VARCHAR(40) PRIMARY KEY,
    nome VARCHAR(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Limites compartilhados entre os processos da hospedagem.
CREATE TABLE IF NOT EXISTS limite_requisicao (
    chave CHAR(64) PRIMARY KEY,
    expira_em DOUBLE NOT NULL,
    contador INT NOT NULL DEFAULT 0,
    INDEX idx_limite_expiracao (expira_em)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO plano(codigo, nome) VALUES ('escolar', 'Mentorly Escolar');

CREATE TABLE IF NOT EXISTS acesso_escola (
    coordenacao_id INT PRIMARY KEY,
    plano_codigo VARCHAR(40) NOT NULL DEFAULT 'escolar',
    situacao ENUM('teste','paga','cortesia','suspensa','pendente') NOT NULL DEFAULT 'teste',
    valido_ate DATE NULL,
    versao INT NOT NULL DEFAULT 1,
    atualizado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (coordenacao_id) REFERENCES coordenacao(id) ON DELETE CASCADE,
    FOREIGN KEY (plano_codigo) REFERENCES plano(codigo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS acesso_historico (
    id INT AUTO_INCREMENT PRIMARY KEY,
    coordenacao_id INT NOT NULL,
    administrador_id INT NOT NULL,
    situacao VARCHAR(20) NOT NULL,
    plano_codigo VARCHAR(40) NOT NULL,
    valido_ate DATE NULL,
    motivo VARCHAR(500) NOT NULL,
    criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (coordenacao_id) REFERENCES coordenacao(id) ON DELETE CASCADE,
    FOREIGN KEY (administrador_id) REFERENCES administrador(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

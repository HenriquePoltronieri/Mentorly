-- =====================================================
-- Mentorly - Procedures do Banco de Dados
-- Consultas que nao se resolvem com CRUD simples.
--
-- Todas recebem p_coordenacao_id: nenhuma procedure enxerga o sistema
-- inteiro, so a escola de quem chamou. O valor vem sempre do token,
-- nunca de parametro enviado pelo cliente.
--
-- O arquivo usa DELIMITER $$ para que possa ser executado tanto pelo
-- cliente do MySQL quanto pelo parser de database/connection.py.
-- =====================================================

DROP PROCEDURE IF EXISTS sp_relatorio_turmas_atividades;
DROP PROCEDURE IF EXISTS sp_buscar_atividades;
DROP PROCEDURE IF EXISTS sp_professores_por_coordenacao;
DROP PROCEDURE IF EXISTS sp_resumo_sistema;
DROP PROCEDURE IF EXISTS sp_turmas_do_professor;
DROP PROCEDURE IF EXISTS sp_alunos_em_risco;
DROP PROCEDURE IF EXISTS sp_usuarios_por_role;

DELIMITER $$

-- 1. Relatorio de turmas da escola com a contagem de atividades de cada uma.
--    LEFT JOIN + GROUP BY + ORDER BY.
--    Aliases em ingles porque relatorioTurmasScreen ja le id/name/description.
CREATE PROCEDURE sp_relatorio_turmas_atividades(IN p_coordenacao_id INT)
BEGIN
    SELECT
        t.id,
        t.nome        AS name,
        t.descricao   AS description,
        COUNT(a.id)   AS total_atividades
    FROM turma t
    LEFT JOIN atividade a ON a.turma_id = t.id
    WHERE t.coordenacao_id = p_coordenacao_id
    GROUP BY t.id, t.nome, t.descricao
    ORDER BY total_atividades DESC, t.nome ASC;
END$$

-- 2. Busca de atividades por termo no titulo, com ordenacao.
--    p_professor_id NULL  -> todas as turmas da escola (visao da Coordenacao).
--    p_professor_id != NULL -> so as turmas vinculadas aquele professor.
CREATE PROCEDURE sp_buscar_atividades(
    IN p_coordenacao_id INT,
    IN p_professor_id   INT,
    IN p_termo          VARCHAR(200),
    IN p_ordenar_por    VARCHAR(50),
    IN p_direcao        VARCHAR(10)
)
BEGIN
    IF p_ordenar_por IS NULL OR p_ordenar_por = '' THEN
        SET p_ordenar_por = 'due_date';
    END IF;

    IF p_direcao IS NULL OR (p_direcao <> 'ASC' AND p_direcao <> 'DESC') THEN
        SET p_direcao = 'ASC';
    END IF;

    SELECT
        a.id,
        a.titulo        AS title,
        a.descricao     AS description,
        a.turma_id      AS class_id,
        t.nome          AS class_name,
        a.data_entrega  AS due_date,
        a.created_at,
        a.updated_at
    FROM atividade a
    INNER JOIN turma t ON t.id = a.turma_id
    WHERE t.coordenacao_id = p_coordenacao_id
      AND (p_termo IS NULL OR p_termo = '' OR a.titulo LIKE CONCAT('%', p_termo, '%'))
      AND (
            p_professor_id IS NULL
            OR EXISTS (
                SELECT 1 FROM professor_turma pt
                WHERE pt.turma_id = t.id AND pt.professor_id = p_professor_id
            )
          )
    ORDER BY
        CASE WHEN p_ordenar_por = 'title'    AND p_direcao = 'ASC'  THEN a.titulo END ASC,
        CASE WHEN p_ordenar_por = 'title'    AND p_direcao = 'DESC' THEN a.titulo END DESC,
        CASE WHEN p_ordenar_por = 'due_date' AND p_direcao = 'ASC'  THEN a.data_entrega END ASC,
        CASE WHEN p_ordenar_por = 'due_date' AND p_direcao = 'DESC' THEN a.data_entrega END DESC,
        CASE WHEN p_ordenar_por = 'class'    AND p_direcao = 'ASC'  THEN t.nome END ASC,
        CASE WHEN p_ordenar_por = 'class'    AND p_direcao = 'DESC' THEN t.nome END DESC,
        a.id ASC;
END$$

-- 3. Professores da escola, em ordem alfabetica, com a contagem de turmas.
--    Substitui sp_usuarios_por_role, que devolvia todos os professores
--    do sistema sem nenhum filtro de escola.
CREATE PROCEDURE sp_professores_por_coordenacao(IN p_coordenacao_id INT)
BEGIN
    SELECT
        p.id,
        p.nome,
        p.email,
        p.disciplina,
        (p.senha_hash IS NOT NULL) AS ativo,
        COUNT(pt.id) AS total_turmas,
        p.created_at,
        p.updated_at
    FROM professor p
    LEFT JOIN professor_turma pt ON pt.professor_id = p.id
    WHERE p.coordenacao_id = p_coordenacao_id
    GROUP BY p.id, p.nome, p.email, p.disciplina, p.senha_hash, p.created_at, p.updated_at
    ORDER BY p.nome ASC;
END$$

-- 4. Resumo da escola (nao do sistema): subconsultas agregadas.
CREATE PROCEDURE sp_resumo_sistema(IN p_coordenacao_id INT)
BEGIN
    SELECT
        (SELECT COUNT(*) FROM turma WHERE coordenacao_id = p_coordenacao_id)     AS total_turmas,
        (SELECT COUNT(*) FROM professor WHERE coordenacao_id = p_coordenacao_id) AS total_professores,
        (SELECT COUNT(*) FROM atividade a
            INNER JOIN turma t ON t.id = a.turma_id
            WHERE t.coordenacao_id = p_coordenacao_id)                           AS total_atividades,
        (SELECT COUNT(*) FROM aluno al
            INNER JOIN turma t ON t.id = al.turma_id
            WHERE t.coordenacao_id = p_coordenacao_id)                           AS total_alunos,
        (SELECT COUNT(DISTINCT a.turma_id) FROM atividade a
            INNER JOIN turma t ON t.id = a.turma_id
            WHERE t.coordenacao_id = p_coordenacao_id)                           AS turmas_com_atividades;
END$$

-- 5. Turmas vinculadas a um professor, com a contagem de alunos.
--    E a fonte de GET /api/professor/turmas: o professor so ve o que a
--    Coordenacao vinculou a ele.
CREATE PROCEDURE sp_turmas_do_professor(IN p_professor_id INT)
BEGIN
    SELECT
        t.id,
        t.nome        AS nome,
        t.descricao   AS descricao,
        t.disciplina  AS disciplina,
        t.turno       AS turno,
        t.ano_letivo  AS anoLetivo,
        (SELECT COUNT(*) FROM aluno al WHERE al.turma_id = t.id) AS totalAlunos
    FROM turma t
    INNER JOIN professor_turma pt ON pt.turma_id = t.id
    WHERE pt.professor_id = p_professor_id
    ORDER BY t.nome ASC;
END$$

-- 6. Alunos em risco: media abaixo da nota minima definida pela Coordenacao
--    para o ano letivo. Considera so as turmas vinculadas ao professor.
CREATE PROCEDURE sp_alunos_em_risco(IN p_professor_id INT, IN p_ano_letivo INT)
BEGIN
    SELECT
        al.id,
        al.nome,
        t.nome AS turma,
        ROUND(AVG(n.valor), 2) AS media,
        e.nota_minima
    FROM aluno al
    INNER JOIN turma t            ON t.id = al.turma_id
    INNER JOIN professor_turma pt ON pt.turma_id = t.id AND pt.professor_id = p_professor_id
    INNER JOIN nota n             ON n.aluno_id = al.id
    INNER JOIN atividade a        ON a.id = n.atividade_id
    LEFT JOIN etapa e             ON e.coordenacao_id = t.coordenacao_id
                                 AND e.ano_letivo = p_ano_letivo
                                 AND e.ordem = 1
    GROUP BY al.id, al.nome, t.nome, e.nota_minima
    HAVING e.nota_minima IS NOT NULL AND AVG(n.valor) < e.nota_minima
    ORDER BY media ASC;
END$$

DELIMITER ;

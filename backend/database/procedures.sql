-- =====================================================
-- Mentorly - Procedures do Banco de Dados
-- Funcionalidades além do CRUD básico
-- =====================================================

-- 1. Relatório de turmas com contagem de atividades
--    Usa LEFT JOIN + GROUP BY + ORDER BY
CREATE PROCEDURE IF NOT EXISTS sp_relatorio_turmas_atividades()
BEGIN
    SELECT
        c.id,
        c.name,
        c.description,
        COUNT(a.id) AS total_atividades
    FROM classes c
    LEFT JOIN activities a ON a.class_id = c.id
    GROUP BY c.id, c.name, c.description
    ORDER BY total_atividades DESC, c.name ASC;
END;

-- 2. Busca de atividades por termo (título) com ordenação
--    Usa WHERE (LIKE) + ORDER BY
CREATE PROCEDURE IF NOT EXISTS sp_buscar_atividades(
    IN p_termo VARCHAR(200),
    IN p_ordenar_por VARCHAR(50),
    IN p_direcao VARCHAR(10)
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
        a.title,
        a.description,
        a.class_id,
        c.name AS class_name,
        a.due_date,
        a.created_at,
        a.updated_at
    FROM activities a
    LEFT JOIN classes c ON c.id = a.class_id
    WHERE p_termo IS NULL
       OR p_termo = ''
       OR a.title LIKE CONCAT('%', p_termo, '%')
    ORDER BY
        CASE WHEN p_ordenar_por = 'title' AND p_direcao = 'ASC' THEN a.title END ASC,
        CASE WHEN p_ordenar_por = 'title' AND p_direcao = 'DESC' THEN a.title END DESC,
        CASE WHEN p_ordenar_por = 'due_date' AND p_direcao = 'ASC' THEN a.due_date END ASC,
        CASE WHEN p_ordenar_por = 'due_date' AND p_direcao = 'DESC' THEN a.due_date END DESC,
        CASE WHEN p_ordenar_por = 'class' AND p_direcao = 'ASC' THEN c.name END ASC,
        CASE WHEN p_ordenar_por = 'class' AND p_direcao = 'DESC' THEN c.name END DESC,
        a.id ASC;
END;

-- 3. Usuários filtrados por papel (role), ordenados por nome
--    Usa WHERE + ORDER BY
CREATE PROCEDURE IF NOT EXISTS sp_usuarios_por_role(IN p_role VARCHAR(20))
BEGIN
    SELECT
        id,
        name,
        email,
        role,
        created_at,
        updated_at
    FROM users
    WHERE role = p_role
    ORDER BY name ASC;
END;

-- 4. Resumo geral do sistema (dashboard)
--    Usa subconsultas agregadas (COUNT)
CREATE PROCEDURE IF NOT EXISTS sp_resumo_sistema()
BEGIN
    SELECT
        (SELECT COUNT(*) FROM classes) AS total_turmas,
        (SELECT COUNT(*) FROM activities) AS total_atividades,
        (SELECT COUNT(*) FROM users) AS total_usuarios,
        (SELECT COUNT(DISTINCT class_id) FROM activities) AS turmas_com_atividades;
END;
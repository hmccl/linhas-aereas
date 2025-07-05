-- Função para cadastro de aeronave
-- Preenche tabelas: Aeronave, Mapa, Assento
-- Parâmetros: modelo da aeronave, número total de assentos
CREATE OR REPLACE FUNCTION cadastrar_aeronave(
    p_modelo TEXT,
    p_num_assentos INTEGER
) RETURNS INTEGER AS $$
DECLARE
    v_cod_aeronave INTEGER;
    v_num_assento TEXT;
    i INTEGER;
BEGIN
    -- Validações básicas
    IF p_modelo IS NULL OR TRIM(p_modelo) = '' THEN
        RAISE EXCEPTION 'Modelo da aeronave não pode ser vazio';
    END IF;
    
    IF p_num_assentos <= 0 THEN
        RAISE EXCEPTION 'Número de assentos deve ser maior que zero';
    END IF;
    
    -- Insere a aeronave e obtém o código gerado
    INSERT INTO aeronave (modelo) 
    VALUES (p_modelo) 
    RETURNING cod_aeronave INTO v_cod_aeronave;
    
    -- Gera os assentos automaticamente (formato: 1A, 1B, 1C, 1D, 2A, 2B, etc.)
    FOR i IN 1..p_num_assentos LOOP
        -- Calcula a fileira (a cada 4 assentos incrementa a fileira)
        -- Formato: fileira + letra (A, B, C, D)
        v_num_assento := CEIL(i::NUMERIC / 4)::TEXT || 
                        CASE (i - 1) % 4
                            WHEN 0 THEN 'A'
                            WHEN 1 THEN 'B'
                            WHEN 2 THEN 'C'
                            WHEN 3 THEN 'D'
                        END;
        
        -- Insere o assento na tabela assento (se não existir)
        INSERT INTO assento (num_assento) 
        VALUES (v_num_assento) 
        ON CONFLICT (num_assento) DO NOTHING;
        
        -- Insere no mapa da aeronave
        INSERT INTO mapa (cod_aeronave, num_assento) 
        VALUES (v_cod_aeronave, v_num_assento);
    END LOOP;
    
    -- Retorna o código da aeronave cadastrada
    RETURN v_cod_aeronave;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Em caso de erro, faz rollback automático
        RAISE EXCEPTION 'Erro ao cadastrar aeronave: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- Exemplo de uso:
-- SELECT cadastrar_aeronave('Boeing 737-800', 180);
-- SELECT cadastrar_aeronave('Airbus A320', 150);

-- Função auxiliar para consultar aeronaves cadastradas
CREATE OR REPLACE FUNCTION listar_aeronaves()
RETURNS TABLE(
    codigo INTEGER,
    modelo TEXT,
    total_assentos BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.cod_aeronave,
        a.modelo,
        COUNT(m.num_assento) as total_assentos
    FROM aeronave a
    LEFT JOIN mapa m ON a.cod_aeronave = m.cod_aeronave
    GROUP BY a.cod_aeronave, a.modelo
    ORDER BY a.cod_aeronave;
END;
$$ LANGUAGE plpgsql;

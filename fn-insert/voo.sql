-- Função para cadastro de voo
-- Preenche tabelas: Voo, Itinerario
-- Parâmetros: data partida, data chegada, código aeronave, aeroporto origem, aeroporto destino
CREATE OR REPLACE FUNCTION cadastrar_voo(
    p_dt_partida DATE,
    p_dt_chegada DATE,
    p_cod_aeronave INTEGER,
    p_aeroporto_origem TEXT,
    p_aeroporto_destino TEXT
) RETURNS INTEGER AS $$
DECLARE
    v_cod_voo INTEGER;
    v_aeroporto_origem_upper TEXT;
    v_aeroporto_destino_upper TEXT;
BEGIN
    -- Validações básicas
    IF p_dt_partida IS NULL THEN
        RAISE EXCEPTION 'Data de partida não pode ser nula';
    END IF;
    
    IF p_dt_chegada IS NULL THEN
        RAISE EXCEPTION 'Data de chegada não pode ser nula';
    END IF;
    
    IF p_cod_aeronave IS NULL THEN
        RAISE EXCEPTION 'Código da aeronave não pode ser nulo';
    END IF;
    
    IF p_aeroporto_origem IS NULL OR TRIM(p_aeroporto_origem) = '' THEN
        RAISE EXCEPTION 'Aeroporto de origem não pode ser vazio';
    END IF;
    
    IF p_aeroporto_destino IS NULL OR TRIM(p_aeroporto_destino) = '' THEN
        RAISE EXCEPTION 'Aeroporto de destino não pode ser vazio';
    END IF;
    
    -- Normaliza os códigos dos aeroportos
    v_aeroporto_origem_upper := UPPER(TRIM(p_aeroporto_origem));
    v_aeroporto_destino_upper := UPPER(TRIM(p_aeroporto_destino));
    
    -- Valida se a data de partida não é posterior à data de chegada
    IF p_dt_partida > p_dt_chegada THEN
        RAISE EXCEPTION 'Data de partida não pode ser posterior à data de chegada';
    END IF;
    
    -- Valida se as datas não são no passado
    IF p_dt_partida < CURRENT_DATE THEN
        RAISE EXCEPTION 'Data de partida não pode ser no passado';
    END IF;
    
    -- Valida se a aeronave existe
    IF NOT EXISTS (SELECT 1 FROM aeronave WHERE cod_aeronave = p_cod_aeronave) THEN
        RAISE EXCEPTION 'Aeronave com código % não existe', p_cod_aeronave;
    END IF;
    
    -- Valida se o aeroporto de origem existe
    IF NOT EXISTS (SELECT 1 FROM aeroporto WHERE cod_aeroporto = v_aeroporto_origem_upper) THEN
        RAISE EXCEPTION 'Aeroporto de origem % não existe', v_aeroporto_origem_upper;
    END IF;
    
    -- Valida se o aeroporto de destino existe
    IF NOT EXISTS (SELECT 1 FROM aeroporto WHERE cod_aeroporto = v_aeroporto_destino_upper) THEN
        RAISE EXCEPTION 'Aeroporto de destino % não existe', v_aeroporto_destino_upper;
    END IF;
    
    -- Valida se origem e destino são diferentes
    IF v_aeroporto_origem_upper = v_aeroporto_destino_upper THEN
        RAISE EXCEPTION 'Aeroporto de origem e destino devem ser diferentes';
    END IF;
    
    -- Verifica se a aeronave está disponível no período
    IF EXISTS (
        SELECT 1 FROM voo v
        WHERE v.cod_aeronave = p_cod_aeronave
        AND (
            (p_dt_partida BETWEEN v.dt_partida AND v.dt_chegada) OR
            (p_dt_chegada BETWEEN v.dt_partida AND v.dt_chegada) OR
            (v.dt_partida BETWEEN p_dt_partida AND p_dt_chegada)
        )
    ) THEN
        RAISE EXCEPTION 'Aeronave não está disponível no período solicitado';
    END IF;
    
    -- Insere o voo e obtém o código gerado
    INSERT INTO voo (dt_partida, dt_chegada, cod_aeronave) 
    VALUES (p_dt_partida, p_dt_chegada, p_cod_aeronave) 
    RETURNING cod_voo INTO v_cod_voo;
    
    -- Insere o itinerário de origem
    INSERT INTO itinerario (tipo_voo, cod_voo, cod_aeroporto) 
    VALUES ('ORIGEM', v_cod_voo, v_aeroporto_origem_upper);
    
    -- Insere o itinerário de destino
    INSERT INTO itinerario (tipo_voo, cod_voo, cod_aeroporto) 
    VALUES ('DESTINO', v_cod_voo, v_aeroporto_destino_upper);
    
    -- Retorna o código do voo cadastrado
    RETURN v_cod_voo;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Em caso de erro, faz rollback automático
        RAISE EXCEPTION 'Erro ao cadastrar voo: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- Função auxiliar para listar voos
CREATE OR REPLACE FUNCTION listar_voos()
RETURNS TABLE(
    codigo_voo INTEGER,
    data_partida DATE,
    data_chegada DATE,
    modelo_aeronave TEXT,
    origem TEXT,
    cidade_origem TEXT,
    destino TEXT,
    cidade_destino TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        v.cod_voo,
        v.dt_partida,
        v.dt_chegada,
        a.modelo,
        io.cod_aeroporto as origem,
        ao.cidade as cidade_origem,
        id.cod_aeroporto as destino,
        ad.cidade as cidade_destino
    FROM voo v
    INNER JOIN aeronave a ON v.cod_aeronave = a.cod_aeronave
    INNER JOIN itinerario io ON v.cod_voo = io.cod_voo AND io.tipo_voo = 'ORIGEM'
    INNER JOIN itinerario id ON v.cod_voo = id.cod_voo AND id.tipo_voo = 'DESTINO'
    INNER JOIN aeroporto ao ON io.cod_aeroporto = ao.cod_aeroporto
    INNER JOIN aeroporto ad ON id.cod_aeroporto = ad.cod_aeroporto
    ORDER BY v.dt_partida, v.cod_voo;
END;
$$ LANGUAGE plpgsql;

-- Função auxiliar para buscar voo por código
CREATE OR REPLACE FUNCTION buscar_voo(p_cod_voo INTEGER)
RETURNS TABLE(
    codigo_voo INTEGER,
    data_partida DATE,
    data_chegada DATE,
    codigo_aeronave INTEGER,
    modelo_aeronave TEXT,
    total_assentos BIGINT,
    origem TEXT,
    cidade_origem TEXT,
    destino TEXT,
    cidade_destino TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        v.cod_voo,
        v.dt_partida,
        v.dt_chegada,
        v.cod_aeronave,
        a.modelo,
        COUNT(m.num_assento) as total_assentos,
        io.cod_aeroporto as origem,
        ao.cidade as cidade_origem,
        id.cod_aeroporto as destino,
        ad.cidade as cidade_destino
    FROM voo v
    INNER JOIN aeronave a ON v.cod_aeronave = a.cod_aeronave
    INNER JOIN mapa m ON a.cod_aeronave = m.cod_aeronave
    INNER JOIN itinerario io ON v.cod_voo = io.cod_voo AND io.tipo_voo = 'ORIGEM'
    INNER JOIN itinerario id ON v.cod_voo = id.cod_voo AND id.tipo_voo = 'DESTINO'
    INNER JOIN aeroporto ao ON io.cod_aeroporto = ao.cod_aeroporto
    INNER JOIN aeroporto ad ON id.cod_aeroporto = ad.cod_aeroporto
    WHERE v.cod_voo = p_cod_voo
    GROUP BY v.cod_voo, v.dt_partida, v.dt_chegada, v.cod_aeronave, a.modelo, 
             io.cod_aeroporto, ao.cidade, id.cod_aeroporto, ad.cidade;
END;
$$ LANGUAGE plpgsql;

-- Função auxiliar para verificar disponibilidade de aeronave
CREATE OR REPLACE FUNCTION verificar_disponibilidade_aeronave(
    p_cod_aeronave INTEGER,
    p_dt_partida DATE,
    p_dt_chegada DATE
) RETURNS BOOLEAN AS $$
DECLARE
    v_conflitos INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_conflitos
    FROM voo v
    WHERE v.cod_aeronave = p_cod_aeronave
    AND (
        (p_dt_partida BETWEEN v.dt_partida AND v.dt_chegada) OR
        (p_dt_chegada BETWEEN v.dt_partida AND v.dt_chegada) OR
        (v.dt_partida BETWEEN p_dt_partida AND p_dt_chegada)
    );
    
    RETURN v_conflitos = 0;
END;
$$ LANGUAGE plpgsql;

-- Exemplos de uso:
/*
-- Cadastrar um voo de São Paulo para Rio de Janeiro
SELECT cadastrar_voo('2024-12-15', '2024-12-15', 1, 'GRU', 'SDU');

-- Cadastrar um voo de Brasília para Salvador
SELECT cadastrar_voo('2024-12-20', '2024-12-20', 2, 'BSB', 'SSA');

-- Verificar disponibilidade de aeronave
SELECT verificar_disponibilidade_aeronave(1, '2024-12-16', '2024-12-16');

-- Listar todos os voos
SELECT * FROM listar_voos();

-- Buscar voo específico
SELECT * FROM buscar_voo(1);
*/

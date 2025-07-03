-- Função para cadastro de compra
-- Preenche tabelas: Reserva, Passagem, Passagem_Voo, Parcela
-- Parâmetros: código do voo, nome do passageiro, valor da passagem, código do pagamento, número de parcelas
CREATE OR REPLACE FUNCTION cadastrar_compra(
    p_cod_voo INTEGER,
    p_nome_passageiro TEXT,
    p_valor_passagem NUMERIC,
    p_cod_pagamento TEXT,
    p_num_parcelas INTEGER DEFAULT 1
) RETURNS INTEGER AS $$
DECLARE
    v_cod_reserva INTEGER;
    v_cod_passagem INTEGER;
    v_cod_aeronave INTEGER;
    v_num_assento TEXT;
    v_valor_parcela NUMERIC;
    v_dt_parcela DATE;
    i INTEGER;
    v_cod_pagamento_upper TEXT;
BEGIN
    -- Validações básicas
    IF p_cod_voo IS NULL THEN
        RAISE EXCEPTION 'Código do voo não pode ser nulo';
    END IF;
    
    IF p_nome_passageiro IS NULL OR TRIM(p_nome_passageiro) = '' THEN
        RAISE EXCEPTION 'Nome do passageiro não pode ser vazio';
    END IF;
    
    IF p_valor_passagem IS NULL OR p_valor_passagem <= 0 THEN
        RAISE EXCEPTION 'Valor da passagem deve ser maior que zero';
    END IF;
    
    IF p_cod_pagamento IS NULL OR TRIM(p_cod_pagamento) = '' THEN
        RAISE EXCEPTION 'Código do pagamento não pode ser vazio';
    END IF;
    
    IF p_num_parcelas IS NULL OR p_num_parcelas <= 0 THEN
        RAISE EXCEPTION 'Número de parcelas deve ser maior que zero';
    END IF;
    
    -- Normaliza código do pagamento
    v_cod_pagamento_upper := UPPER(TRIM(p_cod_pagamento));
    
    -- Valida se o voo existe
    IF NOT EXISTS (SELECT 1 FROM voo WHERE cod_voo = p_cod_voo) THEN
        RAISE EXCEPTION 'Voo com código % não existe', p_cod_voo;
    END IF;
    
    -- Valida se o tipo de pagamento existe
    IF NOT EXISTS (SELECT 1 FROM pagamento WHERE cod_pagamento = v_cod_pagamento_upper) THEN
        RAISE EXCEPTION 'Tipo de pagamento % não existe', v_cod_pagamento_upper;
    END IF;
    
    -- Valida se o voo não é no passado
    IF EXISTS (SELECT 1 FROM voo WHERE cod_voo = p_cod_voo AND dt_partida < CURRENT_DATE) THEN
        RAISE EXCEPTION 'Não é possível comprar passagem para voo no passado';
    END IF;
    
    -- Obtém o código da aeronave do voo
    SELECT cod_aeronave INTO v_cod_aeronave
    FROM voo 
    WHERE cod_voo = p_cod_voo;
    
    -- Busca um assento disponível automaticamente
    SELECT m.num_assento INTO v_num_assento
    FROM mapa m
    WHERE m.cod_aeronave = v_cod_aeronave
    AND m.num_assento NOT IN (
        SELECT pv.num_assento 
        FROM passagem_voo pv 
        WHERE pv.cod_voo = p_cod_voo
    )
    ORDER BY 
        -- Ordena por fileira (número) e depois por letra
        CAST(REGEXP_REPLACE(m.num_assento, '[A-Z]', '', 'g') AS INTEGER),
        RIGHT(m.num_assento, 1)
    LIMIT 1;
    
    -- Verifica se há assentos disponíveis
    IF v_num_assento IS NULL THEN
        RAISE EXCEPTION 'Não há assentos disponíveis para o voo %', p_cod_voo;
    END IF;
    
    -- Validações específicas para PIX (não pode ser parcelado)
    IF v_cod_pagamento_upper = 'PIX' AND p_num_parcelas > 1 THEN
        RAISE EXCEPTION 'Pagamento via PIX não pode ser parcelado';
    END IF;
    
    -- Validações para cartão de débito (não pode ser parcelado)
    IF v_cod_pagamento_upper = 'CD' AND p_num_parcelas > 1 THEN
        RAISE EXCEPTION 'Pagamento via Cartão de Débito não pode ser parcelado';
    END IF;
    
    -- Validações para cartão de crédito (máximo 12 parcelas)
    IF v_cod_pagamento_upper = 'CC' AND p_num_parcelas > 12 THEN
        RAISE EXCEPTION 'Cartão de Crédito permite no máximo 12 parcelas';
    END IF;
    
    -- PASSO 1: Inserir na tabela Reserva
    INSERT INTO reserva (dt_reserva, valor_total, cod_pagamento) 
    VALUES (CURRENT_DATE, 0, v_cod_pagamento_upper) 
    RETURNING cod_reserva INTO v_cod_reserva;
    
    -- PASSO 2: Inserir na tabela Passagem
    INSERT INTO passagem (nome_passageiro, valor_passagem, cod_reserva) 
    VALUES (TRIM(p_nome_passageiro), p_valor_passagem, v_cod_reserva) 
    RETURNING cod_passagem INTO v_cod_passagem;
    
    -- PASSO 3: Inserir na tabela Passagem_Voo
    INSERT INTO passagem_voo (cod_passagem, cod_voo, num_assento) 
    VALUES (v_cod_passagem, p_cod_voo, v_num_assento);
    
    -- PASSO 4: Atualizar valor_total na tabela Reserva
    UPDATE reserva 
    SET valor_total = (
        SELECT SUM(valor_passagem) 
        FROM passagem 
        WHERE cod_reserva = v_cod_reserva
    )
    WHERE cod_reserva = v_cod_reserva;
    
    -- PASSO 5: Inserir parcelas na tabela Parcela
    v_valor_parcela := p_valor_passagem / p_num_parcelas;
    v_dt_parcela := CURRENT_DATE;
    
    FOR i IN 1..p_num_parcelas LOOP
        -- Para a primeira parcela, usar a data atual
        -- Para as demais, adicionar 30 dias para cada parcela
        IF i > 1 THEN
            v_dt_parcela := CURRENT_DATE + (30 * i);
        END IF;
        
        -- Ajusta o valor da última parcela para compensar arredondamentos
        IF i = p_num_parcelas THEN
            v_valor_parcela := p_valor_passagem - (v_valor_parcela * (p_num_parcelas - 1));
        END IF;
        
        INSERT INTO parcela (cod_reserva, valor_parcela, dt_parcela) 
        VALUES (v_cod_reserva, v_valor_parcela, v_dt_parcela);
    END LOOP;
    
    -- Retorna o código da reserva criada
    RETURN v_cod_reserva;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Em caso de erro, faz rollback automático
        RAISE EXCEPTION 'Erro ao processar compra: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- Função auxiliar para consultar detalhes de uma compra/reserva
CREATE OR REPLACE FUNCTION consultar_compra(p_cod_reserva INTEGER)
RETURNS TABLE(
    cod_reserva INTEGER,
    dt_reserva DATE,
    valor_total NUMERIC,
    tipo_pagamento TEXT,
    nome_pagamento TEXT,
    cod_passagem INTEGER,
    cod_passageiro INTEGER,
    nome_passageiro TEXT,
    valor_passagem NUMERIC,
    cod_voo INTEGER,
    num_assento TEXT,
    dt_partida DATE,
    dt_chegada DATE,
    origem TEXT,
    cidade_origem TEXT,
    destino TEXT,
    cidade_destino TEXT,
    modelo_aeronave TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.cod_reserva,
        r.dt_reserva,
        r.valor_total,
        r.cod_pagamento,
        pg.nome,
        p.cod_passagem,
        p.cod_passageiro,
        p.nome_passageiro,
        p.valor_passagem,
        v.cod_voo,
        pv.num_assento,
        v.dt_partida,
        v.dt_chegada,
        io.cod_aeroporto as origem,
        ao.cidade as cidade_origem,
        id.cod_aeroporto as destino,
        ad.cidade as cidade_destino,
        a.modelo
    FROM reserva r
    INNER JOIN pagamento pg ON r.cod_pagamento = pg.cod_pagamento
    INNER JOIN passagem p ON r.cod_reserva = p.cod_reserva
    INNER JOIN passagem_voo pv ON p.cod_passagem = pv.cod_passagem
    INNER JOIN voo v ON pv.cod_voo = v.cod_voo
    INNER JOIN aeronave a ON v.cod_aeronave = a.cod_aeronave
    INNER JOIN itinerario io ON v.cod_voo = io.cod_voo AND io.tipo_voo = 'ORIGEM'
    INNER JOIN itinerario id ON v.cod_voo = id.cod_voo AND id.tipo_voo = 'DESTINO'
    INNER JOIN aeroporto ao ON io.cod_aeroporto = ao.cod_aeroporto
    INNER JOIN aeroporto ad ON id.cod_aeroporto = ad.cod_aeroporto
    WHERE r.cod_reserva = p_cod_reserva;
END;
$$ LANGUAGE plpgsql;

-- Função auxiliar para consultar parcelas de uma reserva
CREATE OR REPLACE FUNCTION consultar_parcelas(p_cod_reserva INTEGER)
RETURNS TABLE(
    cod_parcela INTEGER,
    cod_reserva INTEGER,
    valor_parcela NUMERIC,
    dt_parcela DATE,
    numero_parcela INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pa.cod_parcela,
        pa.cod_reserva,
        pa.valor_parcela,
        pa.dt_parcela,
        ROW_NUMBER() OVER (ORDER BY pa.dt_parcela)::INTEGER as numero_parcela
    FROM parcela pa
    WHERE pa.cod_reserva = p_cod_reserva
    ORDER BY pa.dt_parcela;
END;
$$ LANGUAGE plpgsql;

-- Função auxiliar para verificar assentos disponíveis em um voo
CREATE OR REPLACE FUNCTION consultar_assentos_disponiveis(p_cod_voo INTEGER)
RETURNS TABLE(
    num_assento TEXT,
    disponivel BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        m.num_assento,
        CASE 
            WHEN pv.num_assento IS NULL THEN TRUE 
            ELSE FALSE 
        END as disponivel
    FROM mapa m
    INNER JOIN voo v ON m.cod_aeronave = v.cod_aeronave
    LEFT JOIN passagem_voo pv ON pv.cod_voo = v.cod_voo AND pv.num_assento = m.num_assento
    WHERE v.cod_voo = p_cod_voo
    ORDER BY 
        CAST(REGEXP_REPLACE(m.num_assento, '[A-Z]', '', 'g') AS INTEGER),
        RIGHT(m.num_assento, 1);
END;
$$ LANGUAGE plpgsql;

-- Exemplos de uso:
/*
-- Fazer uma compra simples (PIX à vista)
SELECT cadastrar_compra(1, 'João Silva', 299.90, 'PIX', 1);

-- Fazer uma compra parcelada no cartão de crédito
SELECT cadastrar_compra(2, 'Maria Santos', 599.80, 'CC', 3);

-- Consultar detalhes da compra
SELECT * FROM consultar_compra(1);

-- Consultar parcelas da reserva
SELECT * FROM consultar_parcelas(2);

-- Verificar assentos disponíveis em um voo
SELECT * FROM consultar_assentos_disponiveis(1);
*/

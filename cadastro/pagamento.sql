-- Função para cadastro de tipo de pagamento
-- Preenche tabela: Pagamento
-- Parâmetros: código do pagamento, nome do tipo de pagamento
CREATE OR REPLACE FUNCTION cadastrar_tipo_pagamento(
    p_cod_pagamento TEXT,
    p_nome TEXT
) RETURNS TEXT AS $$
DECLARE
    v_cod_pagamento_upper TEXT;
    v_nome_normalized TEXT;
BEGIN
    -- Validações básicas
    IF p_cod_pagamento IS NULL OR TRIM(p_cod_pagamento) = '' THEN
        RAISE EXCEPTION 'Código do pagamento não pode ser vazio';
    END IF;
    
    IF p_nome IS NULL OR TRIM(p_nome) = '' THEN
        RAISE EXCEPTION 'Nome do tipo de pagamento não pode ser vazio';
    END IF;
    
    -- Normaliza o código (maiúsculo e remove espaços)
    v_cod_pagamento_upper := UPPER(TRIM(p_cod_pagamento));
    v_nome_normalized := TRIM(p_nome);
    
    -- Valida os tipos de pagamento permitidos
    IF v_cod_pagamento_upper NOT IN ('PIX', 'CC', 'CD') THEN
        RAISE EXCEPTION 'Código de pagamento inválido. Tipos permitidos: PIX, CC (Cartão de Crédito), CD (Cartão de Débito)';
    END IF;
    
    -- Valida se o nome corresponde ao código
    CASE v_cod_pagamento_upper
        WHEN 'PIX' THEN
            IF UPPER(v_nome_normalized) != 'PIX' THEN
                RAISE EXCEPTION 'Para código PIX, o nome deve ser "PIX"';
            END IF;
        WHEN 'CC' THEN
            IF UPPER(v_nome_normalized) NOT IN ('CARTÃO DE CRÉDITO', 'CARTAO DE CREDITO') THEN
                RAISE EXCEPTION 'Para código CC, o nome deve ser "Cartão de Crédito"';
            END IF;
            v_nome_normalized := 'Cartão de Crédito';
        WHEN 'CD' THEN
            IF UPPER(v_nome_normalized) NOT IN ('CARTÃO DE DÉBITO', 'CARTAO DE DEBITO') THEN
                RAISE EXCEPTION 'Para código CD, o nome deve ser "Cartão de Débito"';
            END IF;
            v_nome_normalized := 'Cartão de Débito';
    END CASE;
    
    -- Verifica se o tipo de pagamento já existe
    IF EXISTS (SELECT 1 FROM pagamento WHERE cod_pagamento = v_cod_pagamento_upper) THEN
        RAISE EXCEPTION 'Tipo de pagamento com código % já existe', v_cod_pagamento_upper;
    END IF;
    
    -- Insere o tipo de pagamento
    INSERT INTO pagamento (cod_pagamento, nome) 
    VALUES (v_cod_pagamento_upper, v_nome_normalized);
    
    -- Retorna o código do pagamento cadastrado
    RETURN v_cod_pagamento_upper;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Em caso de erro, relança a exceção
        RAISE EXCEPTION 'Erro ao cadastrar tipo de pagamento: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- Função auxiliar para listar tipos de pagamento cadastrados
CREATE OR REPLACE FUNCTION listar_tipos_pagamento()
RETURNS TABLE(
    codigo TEXT,
    nome TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.cod_pagamento,
        p.nome
    FROM pagamento p
    ORDER BY p.cod_pagamento;
END;
$$ LANGUAGE plpgsql;

-- Função auxiliar para buscar tipo de pagamento por código
CREATE OR REPLACE FUNCTION buscar_tipo_pagamento(p_codigo TEXT)
RETURNS TABLE(
    codigo TEXT,
    nome TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.cod_pagamento,
        p.nome
    FROM pagamento p
    WHERE p.cod_pagamento = UPPER(TRIM(p_codigo));
END;
$$ LANGUAGE plpgsql;

-- Função para cadastrar todos os tipos de pagamento padrão
CREATE OR REPLACE FUNCTION cadastrar_tipos_pagamento_padrao()
RETURNS TEXT AS $$
DECLARE
    v_resultado TEXT := '';
BEGIN
    -- Cadastra PIX
    BEGIN
        PERFORM cadastrar_tipo_pagamento('PIX', 'PIX');
        v_resultado := v_resultado || 'PIX cadastrado com sucesso. ';
    EXCEPTION
        WHEN OTHERS THEN
            v_resultado := v_resultado || 'PIX: ' || SQLERRM || '. ';
    END;
    
    -- Cadastra Cartão de Crédito
    BEGIN
        PERFORM cadastrar_tipo_pagamento('CC', 'Cartão de Crédito');
        v_resultado := v_resultado || 'Cartão de Crédito cadastrado com sucesso. ';
    EXCEPTION
        WHEN OTHERS THEN
            v_resultado := v_resultado || 'CC: ' || SQLERRM || '. ';
    END;
    
    -- Cadastra Cartão de Débito
    BEGIN
        PERFORM cadastrar_tipo_pagamento('CD', 'Cartão de Débito');
        v_resultado := v_resultado || 'Cartão de Débito cadastrado com sucesso. ';
    EXCEPTION
        WHEN OTHERS THEN
            v_resultado := v_resultado || 'CD: ' || SQLERRM || '. ';
    END;
    
    RETURN TRIM(v_resultado);
END;
$$ LANGUAGE plpgsql;

-- Exemplos de uso:
/*
-- Cadastrar tipos de pagamento individualmente
SELECT cadastrar_tipo_pagamento('PIX', 'PIX');
SELECT cadastrar_tipo_pagamento('CC', 'Cartão de Crédito');
SELECT cadastrar_tipo_pagamento('CD', 'Cartão de Débito');

-- Ou cadastrar todos de uma vez
SELECT cadastrar_tipos_pagamento_padrao();

-- Listar todos os tipos de pagamento
SELECT * FROM listar_tipos_pagamento();

-- Buscar tipo específico
SELECT * FROM buscar_tipo_pagamento('PIX');
*/

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

-- Exemplos de uso:
/*
-- Cadastrar tipos de pagamento individualmente
SELECT cadastrar_tipo_pagamento('PIX', 'PIX');
SELECT cadastrar_tipo_pagamento('CC', 'Cartão de Crédito');
SELECT cadastrar_tipo_pagamento('CD', 'Cartão de Débito');

-- Listar todos os tipos de pagamento
SELECT * FROM listar_tipos_pagamento();
*/

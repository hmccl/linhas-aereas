-- Função para cadastro de aeroporto
-- Preenche tabela: Aeroporto
-- Parâmetros: código IATA de 3 letras, cidade do aeroporto
CREATE OR REPLACE FUNCTION cadastrar_aeroporto(
    p_cod_aeroporto TEXT,
    p_cidade TEXT
) RETURNS TEXT AS $$
DECLARE
    v_cod_aeroporto_upper TEXT;
BEGIN
    -- Validações básicas
    IF p_cod_aeroporto IS NULL OR TRIM(p_cod_aeroporto) = '' THEN
        RAISE EXCEPTION 'Código do aeroporto não pode ser vazio';
    END IF;
    
    IF p_cidade IS NULL OR TRIM(p_cidade) = '' THEN
        RAISE EXCEPTION 'Cidade não pode ser vazia';
    END IF;
    
    -- Converte código para maiúsculo e remove espaços
    v_cod_aeroporto_upper := UPPER(TRIM(p_cod_aeroporto));
    
    -- Valida se o código tem exatamente 3 caracteres
    IF LENGTH(v_cod_aeroporto_upper) != 3 THEN
        RAISE EXCEPTION 'Código do aeroporto deve ter exatamente 3 letras (formato IATA)';
    END IF;
    
    -- Valida se o código contém apenas letras
    IF v_cod_aeroporto_upper !~ '^[A-Z]{3}$' THEN
        RAISE EXCEPTION 'Código do aeroporto deve conter apenas letras (A-Z)';
    END IF;
    
    -- Verifica se o aeroporto já existe
    IF EXISTS (SELECT 1 FROM aeroporto WHERE cod_aeroporto = v_cod_aeroporto_upper) THEN
        RAISE EXCEPTION 'Aeroporto com código % já existe', v_cod_aeroporto_upper;
    END IF;
    
    -- Insere o aeroporto
    INSERT INTO aeroporto (cod_aeroporto, cidade) 
    VALUES (v_cod_aeroporto_upper, TRIM(p_cidade));
    
    -- Retorna o código do aeroporto cadastrado
    RETURN v_cod_aeroporto_upper;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Em caso de erro, relança a exceção
        RAISE EXCEPTION 'Erro ao cadastrar aeroporto: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- Função auxiliar para listar aeroportos cadastrados
CREATE OR REPLACE FUNCTION listar_aeroportos()
RETURNS TABLE(
    codigo TEXT,
    cidade TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.cod_aeroporto,
        a.cidade
    FROM aeroporto a
    ORDER BY a.cod_aeroporto;
END;
$$ LANGUAGE plpgsql;

-- Função auxiliar para buscar aeroporto por código
CREATE OR REPLACE FUNCTION buscar_aeroporto(p_codigo TEXT)
RETURNS TABLE(
    codigo TEXT,
    cidade TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.cod_aeroporto,
        a.cidade
    FROM aeroporto a
    WHERE a.cod_aeroporto = UPPER(TRIM(p_codigo));
END;
$$ LANGUAGE plpgsql;

-- Exemplos de uso com aeroportos brasileiros:
/*
SELECT cadastrar_aeroporto('GRU', 'São Paulo');
SELECT cadastrar_aeroporto('SDU', 'Rio de Janeiro');
SELECT cadastrar_aeroporto('BSB', 'Brasília');
SELECT cadastrar_aeroporto('CGH', 'São Paulo');
SELECT cadastrar_aeroporto('SSA', 'Salvador');
SELECT cadastrar_aeroporto('FOR', 'Fortaleza');
SELECT cadastrar_aeroporto('REC', 'Recife');
SELECT cadastrar_aeroporto('POA', 'Porto Alegre');
SELECT cadastrar_aeroporto('CWB', 'Curitiba');
SELECT cadastrar_aeroporto('BEL', 'Belém');
SELECT cadastrar_aeroporto('MAO', 'Manaus');
SELECT cadastrar_aeroporto('VIX', 'Vitória');
SELECT cadastrar_aeroporto('CNF', 'Belo Horizonte');
SELECT cadastrar_aeroporto('FLN', 'Florianópolis');
SELECT cadastrar_aeroporto('THE', 'Teresina');
*/

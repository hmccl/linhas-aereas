-- Função para remoção de aeroporto (HARD DELETE)
-- Remove da tabela: Aeroporto
-- Parâmetro: código IATA de 3 letras do aeroporto
CREATE OR REPLACE FUNCTION deletar_aeroporto(
    p_cod_aeroporto TEXT
) RETURNS TEXT AS $$
DECLARE
    v_cod_aeroporto_upper TEXT;
    v_cidade TEXT;
    v_count_itinerarios INTEGER;
    v_voos_conflito TEXT;
BEGIN
    -- Validações básicas
    IF p_cod_aeroporto IS NULL OR TRIM(p_cod_aeroporto) = '' THEN
        RAISE EXCEPTION 'Código do aeroporto não pode ser vazio';
    END IF;
    
    -- Normaliza o código do aeroporto
    v_cod_aeroporto_upper := UPPER(TRIM(p_cod_aeroporto));
    
    -- Valida se o código tem exatamente 3 caracteres
    IF LENGTH(v_cod_aeroporto_upper) != 3 THEN
        RAISE EXCEPTION 'Código do aeroporto deve ter exatamente 3 letras (formato IATA)';
    END IF;
    
    -- Valida se o código contém apenas letras
    IF v_cod_aeroporto_upper !~ '^[A-Z]{3}$' THEN
        RAISE EXCEPTION 'Código do aeroporto deve conter apenas letras (A-Z)';
    END IF;
    
    -- Verifica se o aeroporto existe
    SELECT cidade INTO v_cidade 
    FROM aeroporto 
    WHERE cod_aeroporto = v_cod_aeroporto_upper;
    
    IF v_cidade IS NULL THEN
        RAISE EXCEPTION 'Aeroporto com código % não existe', v_cod_aeroporto_upper;
    END IF;
    
    -- Verifica se há itinerários (voos) vinculados ao aeroporto
    SELECT COUNT(*) INTO v_count_itinerarios
    FROM itinerario i
    WHERE i.cod_aeroporto = v_cod_aeroporto_upper;
    
    -- Se há voos vinculados, mostra quais são e impede a remoção
    IF v_count_itinerarios > 0 THEN
        -- Monta string com os códigos dos voos conflitantes
        SELECT STRING_AGG(DISTINCT i.cod_voo::TEXT, ', ' ORDER BY i.cod_voo::TEXT) INTO v_voos_conflito
        FROM itinerario i
        WHERE i.cod_aeroporto = v_cod_aeroporto_upper;
        
        RAISE EXCEPTION 'Não é possível remover o aeroporto %. Existem % voo(s) vinculado(s): %. Remova ou altere estes voos primeiro.',
            v_cod_aeroporto_upper, v_count_itinerarios, v_voos_conflito;
    END IF;
    
    -- Remove o aeroporto
    DELETE FROM aeroporto 
    WHERE cod_aeroporto = v_cod_aeroporto_upper;
    
    -- Retorna mensagem de sucesso
    RETURN FORMAT('Aeroporto %s (%s) removido com sucesso', v_cod_aeroporto_upper, v_cidade);
    
EXCEPTION
    WHEN OTHERS THEN
        -- Em caso de erro, relança a exceção
        RAISE EXCEPTION 'Erro ao deletar aeroporto: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- Função auxiliar para verificar dependências de um aeroporto
CREATE OR REPLACE FUNCTION verificar_dependencias_aeroporto(p_cod_aeroporto TEXT)
RETURNS TABLE(
    codigo_aeroporto TEXT,
    cidade TEXT,
    total_voos INTEGER,
    voos_como_origem INTEGER,
    voos_como_destino INTEGER,
    codigos_voos TEXT,
    pode_deletar BOOLEAN
) AS $$
DECLARE
    v_cod_aeroporto_upper TEXT;
BEGIN
    -- Normaliza o código
    v_cod_aeroporto_upper := UPPER(TRIM(p_cod_aeroporto));
    
    RETURN QUERY
    SELECT 
        a.cod_aeroporto,
        a.cidade,
        COALESCE(total.total_voos, 0)::INTEGER,
        COALESCE(origem.voos_origem, 0)::INTEGER,
        COALESCE(destino.voos_destino, 0)::INTEGER,
        COALESCE(todos_voos.codigos, 'Nenhum'),
        CASE WHEN COALESCE(total.total_voos, 0) = 0 THEN TRUE ELSE FALSE END
    FROM aeroporto a
    LEFT JOIN (
        -- Total de voos (origem + destino)
        SELECT 
            i.cod_aeroporto,
            COUNT(*) as total_voos
        FROM itinerario i
        WHERE i.cod_aeroporto = v_cod_aeroporto_upper
        GROUP BY i.cod_aeroporto
    ) total ON a.cod_aeroporto = total.cod_aeroporto
    LEFT JOIN (
        -- Voos como origem
        SELECT 
            i.cod_aeroporto,
            COUNT(*) as voos_origem
        FROM itinerario i
        WHERE i.cod_aeroporto = v_cod_aeroporto_upper AND i.tipo_voo = 'ORIGEM'
        GROUP BY i.cod_aeroporto
    ) origem ON a.cod_aeroporto = origem.cod_aeroporto
    LEFT JOIN (
        -- Voos como destino
        SELECT 
            i.cod_aeroporto,
            COUNT(*) as voos_destino
        FROM itinerario i
        WHERE i.cod_aeroporto = v_cod_aeroporto_upper AND i.tipo_voo = 'DESTINO'
        GROUP BY i.cod_aeroporto
    ) destino ON a.cod_aeroporto = destino.cod_aeroporto
    LEFT JOIN (
        -- Lista de códigos dos voos
        SELECT 
            i.cod_aeroporto,
            STRING_AGG(DISTINCT i.cod_voo::TEXT, ', ' ORDER BY i.cod_voo::TEXT) as codigos
        FROM itinerario i
        WHERE i.cod_aeroporto = v_cod_aeroporto_upper
        GROUP BY i.cod_aeroporto
    ) todos_voos ON a.cod_aeroporto = todos_voos.cod_aeroporto
    WHERE a.cod_aeroporto = v_cod_aeroporto_upper;
END;
$$ LANGUAGE plpgsql;

-- Função para listar aeroportos que podem ser deletados
CREATE OR REPLACE FUNCTION listar_aeroportos_deletaveis()
RETURNS TABLE(
    codigo_aeroporto TEXT,
    cidade TEXT,
    status TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.cod_aeroporto,
        a.cidade,
        CASE 
            WHEN i.cod_aeroporto IS NULL THEN 'Pode ser deletado'
            ELSE 'Possui voos vinculados'
        END as status
    FROM aeroporto a
    LEFT JOIN itinerario i ON a.cod_aeroporto = i.cod_aeroporto
    GROUP BY a.cod_aeroporto, a.cidade
    ORDER BY 
        CASE WHEN COUNT(i.cod_aeroporto) = 0 THEN 0 ELSE 1 END,
        a.cod_aeroporto;
END;
$$ LANGUAGE plpgsql;

-- Função para forçar remoção de aeroporto (remove voos associados primeiro)
-- USO COM CUIDADO - REMOVE TODOS OS VOOS VINCULADOS!
CREATE OR REPLACE FUNCTION deletar_aeroporto_forcado(
    p_cod_aeroporto TEXT,
    p_confirmar BOOLEAN DEFAULT FALSE
) RETURNS TEXT AS $$
DECLARE
    v_cod_aeroporto_upper TEXT;
    v_cidade TEXT;
    v_voos_removidos INTEGER;
    v_resultado TEXT;
BEGIN
    -- Validação de confirmação
    IF NOT p_confirmar THEN
        RAISE EXCEPTION 'Para usar esta função destrutiva, passe TRUE como segundo parâmetro para confirmar';
    END IF;
    
    -- Validações básicas
    IF p_cod_aeroporto IS NULL OR TRIM(p_cod_aeroporto) = '' THEN
        RAISE EXCEPTION 'Código do aeroporto não pode ser vazio';
    END IF;
    
    v_cod_aeroporto_upper := UPPER(TRIM(p_cod_aeroporto));
    
    -- Verifica se o aeroporto existe
    SELECT cidade INTO v_cidade 
    FROM aeroporto 
    WHERE cod_aeroporto = v_cod_aeroporto_upper;
    
    IF v_cidade IS NULL THEN
        RAISE EXCEPTION 'Aeroporto com código % não existe', v_cod_aeroporto_upper;
    END IF;
    
    -- Remove todos os voos associados (cascata: parcelas, passagem_voo, passagens, reservas)
    WITH voos_para_remover AS (
        SELECT DISTINCT i.cod_voo
        FROM itinerario i
        WHERE i.cod_aeroporto = v_cod_aeroporto_upper
    )
    SELECT COUNT(*) INTO v_voos_removidos FROM voos_para_remover;
    
    -- Remove parcelas primeiro (FK para reserva)
    DELETE FROM parcela 
    WHERE cod_reserva IN (
        SELECT DISTINCT r.cod_reserva
        FROM reserva r
        INNER JOIN passagem p ON r.cod_reserva = p.cod_reserva
        INNER JOIN passagem_voo pv ON p.cod_passagem = pv.cod_passagem
        INNER JOIN itinerario i ON pv.cod_voo = i.cod_voo
        WHERE i.cod_aeroporto = v_cod_aeroporto_upper
    );
    
    -- Remove passagem_voo
    DELETE FROM passagem_voo 
    WHERE cod_voo IN (
        SELECT DISTINCT i.cod_voo
        FROM itinerario i
        WHERE i.cod_aeroporto = v_cod_aeroporto_upper
    );
    
    -- Remove passagens
    DELETE FROM passagem 
    WHERE cod_reserva IN (
        SELECT DISTINCT r.cod_reserva
        FROM reserva r
        INNER JOIN passagem p ON r.cod_reserva = p.cod_reserva
        INNER JOIN passagem_voo pv ON p.cod_passagem = pv.cod_passagem
        INNER JOIN itinerario i ON pv.cod_voo = i.cod_voo
        WHERE i.cod_aeroporto = v_cod_aeroporto_upper
    );
    
    -- Remove reservas
    DELETE FROM reserva 
    WHERE cod_reserva IN (
        SELECT DISTINCT r.cod_reserva
        FROM reserva r
        INNER JOIN passagem p ON r.cod_reserva = p.cod_reserva
        INNER JOIN passagem_voo pv ON p.cod_passagem = pv.cod_passagem
        INNER JOIN itinerario i ON pv.cod_voo = i.cod_voo
        WHERE i.cod_aeroporto = v_cod_aeroporto_upper
    );
    
    -- Remove itinerários
    DELETE FROM itinerario 
    WHERE cod_aeroporto = v_cod_aeroporto_upper;
    
    -- Remove voos órfãos (que não têm mais itinerários)
    DELETE FROM voo 
    WHERE cod_voo NOT IN (SELECT DISTINCT cod_voo FROM itinerario);
    
    -- Remove o aeroporto
    DELETE FROM aeroporto 
    WHERE cod_aeroporto = v_cod_aeroporto_upper;
    
    -- Monta resultado
    v_resultado := FORMAT('Aeroporto %s (%s) removido com sucesso. %s voo(s) e todas as reservas associadas foram removidos.',
                         v_cod_aeroporto_upper, v_cidade, v_voos_removidos);
    
    RETURN v_resultado;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Erro ao deletar aeroporto forçadamente: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- Exemplos de uso:
/*
-- Verificar se um aeroporto pode ser deletado
SELECT * FROM verificar_dependencias_aeroporto('GRU');

-- Listar todos os aeroportos e seu status para deleção
SELECT * FROM listar_aeroportos_deletaveis();

-- Deletar aeroporto (só funciona se não houver voos)
SELECT deletar_aeroporto('VIX');

-- Forçar deleção (CUIDADO: remove todos os voos associados)
SELECT deletar_aeroporto_forcado('GRU', TRUE);
*/

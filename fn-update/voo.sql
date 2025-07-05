-- Função para alterar horário de voo (UPDATE)
-- Atualiza as datas de partida e chegada de um voo
-- Parâmetros: código do voo, nova data de partida, nova data de chegada
-- Restrição: as datas só podem ser adiadas (não podem ser antecipadas)
CREATE OR REPLACE FUNCTION alterar_horario_voo(
    p_cod_voo INTEGER,
    p_nova_dt_partida DATE,
    p_nova_dt_chegada DATE
) RETURNS BOOLEAN AS $$
DECLARE
    v_dt_partida_atual DATE;
    v_dt_chegada_atual DATE;
    v_cod_aeronave INTEGER;
    v_total_passageiros INTEGER;
BEGIN
    -- Validações básicas
    IF p_cod_voo IS NULL THEN
        RAISE EXCEPTION 'Código do voo não pode ser nulo';
    END IF;
    
    IF p_nova_dt_partida IS NULL THEN
        RAISE EXCEPTION 'Nova data de partida não pode ser nula';
    END IF;
    
    IF p_nova_dt_chegada IS NULL THEN
        RAISE EXCEPTION 'Nova data de chegada não pode ser nula';
    END IF;
    
    -- Valida se a nova data de partida não é posterior à nova data de chegada
    IF p_nova_dt_partida > p_nova_dt_chegada THEN
        RAISE EXCEPTION 'Nova data de partida não pode ser posterior à nova data de chegada';
    END IF;
    
    -- Valida se as novas datas não são no passado
    IF p_nova_dt_partida < CURRENT_DATE THEN
        RAISE EXCEPTION 'Nova data de partida não pode ser no passado';
    END IF;
    
    -- Verifica se o voo existe e obtém as datas atuais e código da aeronave
    SELECT dt_partida, dt_chegada, cod_aeronave 
    INTO v_dt_partida_atual, v_dt_chegada_atual, v_cod_aeronave
    FROM voo 
    WHERE cod_voo = p_cod_voo;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Voo com código % não existe', p_cod_voo;
    END IF;
    
    -- Verifica se o voo não é no passado (não pode alterar voos que já partiram)
    IF v_dt_partida_atual < CURRENT_DATE THEN
        RAISE EXCEPTION 'Não é possível alterar voo que já partiu';
    END IF;
    
    -- RESTRIÇÃO: As datas só podem ser adiadas (conforme especificação)
    IF p_nova_dt_partida < v_dt_partida_atual THEN
        RAISE EXCEPTION 'Data de partida só pode ser adiada. Data atual: %, Nova data: %', 
                       v_dt_partida_atual, p_nova_dt_partida;
    END IF;
    
    IF p_nova_dt_chegada < v_dt_chegada_atual THEN
        RAISE EXCEPTION 'Data de chegada só pode ser adiada. Data atual: %, Nova data: %', 
                       v_dt_chegada_atual, p_nova_dt_chegada;
    END IF;
    
    -- Verifica se há passageiros no voo
    SELECT COUNT(*) INTO v_total_passageiros
    FROM passagem_voo pv
    WHERE pv.cod_voo = p_cod_voo;
    
    -- Se há passageiros, exibe aviso sobre necessidade de notificação
    IF v_total_passageiros > 0 THEN
        RAISE NOTICE 'ATENÇÃO: Voo possui % passageiro(s). Será necessário notificar os passageiros sobre a alteração.', 
                    v_total_passageiros;
    END IF;
    
    -- Verifica se a aeronave está disponível no novo período
    -- (excluindo o próprio voo da verificação)
    IF EXISTS (
        SELECT 1 FROM voo v
        WHERE v.cod_aeronave = v_cod_aeronave
        AND v.cod_voo != p_cod_voo  -- Exclui o próprio voo
        AND (
            (p_nova_dt_partida BETWEEN v.dt_partida AND v.dt_chegada) OR
            (p_nova_dt_chegada BETWEEN v.dt_partida AND v.dt_chegada) OR
            (v.dt_partida BETWEEN p_nova_dt_partida AND p_nova_dt_chegada)
        )
    ) THEN
        RAISE EXCEPTION 'Aeronave não está disponível no novo período solicitado';
    END IF;
    
    -- Realiza a atualização das datas
    UPDATE voo 
    SET dt_partida = p_nova_dt_partida,
        dt_chegada = p_nova_dt_chegada
    WHERE cod_voo = p_cod_voo;
    
    -- Verifica se a atualização foi bem-sucedida
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Erro inesperado ao atualizar o voo';
    END IF;
    
    -- Log da alteração (usando RAISE NOTICE para fins de auditoria)
    RAISE NOTICE 'Voo % alterado com sucesso. Partida: % -> %, Chegada: % -> %', 
                p_cod_voo, v_dt_partida_atual, p_nova_dt_partida, 
                v_dt_chegada_atual, p_nova_dt_chegada;
    
    -- Retorna verdadeiro indicando sucesso
    RETURN TRUE;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Em caso de erro, faz rollback automático e relança a exceção
        RAISE EXCEPTION 'Erro ao alterar horário do voo: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- Função auxiliar para consultar histórico de alterações de um voo
-- (Esta seria uma tabela de auditoria em um sistema real)
CREATE OR REPLACE FUNCTION consultar_detalhes_voo_alteracao(p_cod_voo INTEGER)
RETURNS TABLE(
    codigo_voo INTEGER,
    data_partida_atual DATE,
    data_chegada_atual DATE,
    modelo_aeronave TEXT,
    origem TEXT,
    cidade_origem TEXT,
    destino TEXT,
    cidade_destino TEXT,
    total_passageiros BIGINT,
    assentos_ocupados BIGINT,
    assentos_disponiveis BIGINT
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
        ad.cidade as cidade_destino,
        COALESCE(COUNT(DISTINCT pv.cod_passagem), 0) as total_passageiros,
        COALESCE(COUNT(DISTINCT pv.num_assento), 0) as assentos_ocupados,
        COUNT(DISTINCT m.num_assento) - COALESCE(COUNT(DISTINCT pv.num_assento), 0) as assentos_disponiveis
    FROM voo v
    INNER JOIN aeronave a ON v.cod_aeronave = a.cod_aeronave
    INNER JOIN mapa m ON a.cod_aeronave = m.cod_aeronave
    INNER JOIN itinerario io ON v.cod_voo = io.cod_voo AND io.tipo_voo = 'ORIGEM'
    INNER JOIN itinerario id ON v.cod_voo = id.cod_voo AND id.tipo_voo = 'DESTINO'
    INNER JOIN aeroporto ao ON io.cod_aeroporto = ao.cod_aeroporto
    INNER JOIN aeroporto ad ON id.cod_aeroporto = ad.cod_aeroporto
    LEFT JOIN passagem_voo pv ON v.cod_voo = pv.cod_voo
    WHERE v.cod_voo = p_cod_voo
    GROUP BY v.cod_voo, v.dt_partida, v.dt_chegada, a.modelo, 
             io.cod_aeroporto, ao.cidade, id.cod_aeroporto, ad.cidade;
END;
$$ LANGUAGE plpgsql;

-- Função para listar passageiros afetados por uma alteração
CREATE OR REPLACE FUNCTION listar_passageiros_afetados(p_cod_voo INTEGER)
RETURNS TABLE(
    cod_reserva INTEGER,
    cod_passagem INTEGER,
    nome_passageiro TEXT,
    num_assento TEXT,
    valor_passagem NUMERIC,
    dt_reserva DATE,
    tipo_pagamento TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.cod_reserva,
        p.cod_passagem,
        p.nome_passageiro,
        pv.num_assento,
        pv.valor_passagem,
        r.dt_reserva,
        pg.nome as tipo_pagamento
    FROM passagem_voo pv
    INNER JOIN passagem p ON pv.cod_passagem = p.cod_passagem
    INNER JOIN reserva r ON p.cod_reserva = r.cod_reserva
    INNER JOIN pagamento pg ON r.cod_pagamento = pg.cod_pagamento
    WHERE pv.cod_voo = p_cod_voo
    ORDER BY pv.num_assento;
END;
$$ LANGUAGE plpgsql;

-- Exemplos de uso:
/*
-- Verificar detalhes atuais do voo antes da alteração
SELECT * FROM consultar_detalhes_voo_alteracao(1);

-- Listar passageiros que serão afetados
SELECT * FROM listar_passageiros_afetados(1);

-- Alterar o horário do voo (adiando as datas)
SELECT alterar_horario_voo(1, '2025-12-16', '2025-12-16');

-- Verificar se a alteração foi aplicada
SELECT * FROM buscar_voo(1);

-- Exemplo de tentativa inválida (tentar antecipar):
-- SELECT alterar_horario_voo(1, '2025-12-14', '2025-12-14'); -- Deve dar erro

-- Exemplo de alteração com validação de conflito de aeronave:
-- SELECT alterar_horario_voo(1, '2025-12-25', '2025-12-25'); -- Pode dar erro se aeronave estiver ocupada
*/

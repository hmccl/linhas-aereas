-- Função para remoção de aeronave (HARD DELETE)
-- Remove das tabelas: Aeronave, Mapa
-- Parâmetro: código da aeronave
CREATE OR REPLACE FUNCTION deletar_aeronave(
    p_cod_aeronave INTEGER
) RETURNS TEXT AS $$
DECLARE
    v_modelo TEXT;
    v_total_assentos INTEGER;
    v_count_voos INTEGER;
    v_voos_conflito TEXT;
    v_count_voos_futuros INTEGER;
    v_count_voos_passados INTEGER;
BEGIN
    -- Validações básicas
    IF p_cod_aeronave IS NULL THEN
        RAISE EXCEPTION 'Código da aeronave não pode ser nulo';
    END IF;
    
    IF p_cod_aeronave <= 0 THEN
        RAISE EXCEPTION 'Código da aeronave deve ser um número positivo';
    END IF;
    
    -- Verifica se a aeronave existe
    SELECT a.modelo, COUNT(m.num_assento)
    INTO v_modelo, v_total_assentos
    FROM aeronave a
    LEFT JOIN mapa m ON a.cod_aeronave = m.cod_aeronave
    WHERE a.cod_aeronave = p_cod_aeronave
    GROUP BY a.modelo;
    
    IF v_modelo IS NULL THEN
        RAISE EXCEPTION 'Aeronave com código % não existe', p_cod_aeronave;
    END IF;
    
    -- Verifica se há voos vinculados à aeronave
    SELECT COUNT(*) INTO v_count_voos
    FROM voo v
    WHERE v.cod_aeronave = p_cod_aeronave;
    
    -- Se há voos vinculados, verifica se são futuros ou passados
    IF v_count_voos > 0 THEN
        -- Conta voos futuros (que impediriam a remoção)
        SELECT COUNT(*) INTO v_count_voos_futuros
        FROM voo v
        WHERE v.cod_aeronave = p_cod_aeronave 
        AND v.dt_partida >= CURRENT_DATE;
        
        -- Conta voos passados
        SELECT COUNT(*) INTO v_count_voos_passados
        FROM voo v
        WHERE v.cod_aeronave = p_cod_aeronave 
        AND v.dt_partida < CURRENT_DATE;
        
        -- Se há voos futuros, impede a remoção
        IF v_count_voos_futuros > 0 THEN
            -- Monta string com os códigos dos voos futuros conflitantes
            SELECT STRING_AGG(DISTINCT v.cod_voo::TEXT, ', ' ORDER BY v.cod_voo::TEXT) INTO v_voos_conflito
            FROM voo v
            WHERE v.cod_aeronave = p_cod_aeronave 
            AND v.dt_partida >= CURRENT_DATE;
            
            RAISE EXCEPTION 'Não é possível remover a aeronave %. Existem % voo(s) futuro(s) programado(s): %. Cancele ou transfira estes voos primeiro.',
                p_cod_aeronave, v_count_voos_futuros, v_voos_conflito;
        END IF;
        
        -- Se há apenas voos passados, permite a remoção mas informa
        IF v_count_voos_passados > 0 THEN
            RAISE NOTICE 'Aeronave possui % voo(s) histórico(s) que serão mantidos no banco para fins de auditoria', v_count_voos_passados;
        END IF;
    END IF;
    
    -- Remove o mapa de assentos da aeronave primeiro (FK)
    DELETE FROM mapa 
    WHERE cod_aeronave = p_cod_aeronave;
    
    -- Remove a aeronave
    DELETE FROM aeronave 
    WHERE cod_aeronave = p_cod_aeronave;
    
    -- Retorna mensagem de sucesso
    RETURN FORMAT('Aeronave %s (%s) com %s assentos removida com sucesso da frota', 
                  p_cod_aeronave, v_modelo, v_total_assentos);
    
EXCEPTION
    WHEN OTHERS THEN
        -- Em caso de erro, relança a exceção
        RAISE EXCEPTION 'Erro ao deletar aeronave: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- Função auxiliar para verificar dependências de uma aeronave
CREATE OR REPLACE FUNCTION verificar_dependencias_aeronave(p_cod_aeronave INTEGER)
RETURNS TABLE(
    codigo_aeronave INTEGER,
    modelo TEXT,
    total_assentos INTEGER,
    total_voos INTEGER,
    voos_futuros INTEGER,
    voos_passados INTEGER,
    voos_hoje INTEGER,
    codigos_voos_futuros TEXT,
    passageiros_afetados INTEGER,
    pode_deletar BOOLEAN,
    observacoes TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.cod_aeronave,
        a.modelo,
        COALESCE(assentos.total, 0)::INTEGER,
        COALESCE(todos_voos.total, 0)::INTEGER,
        COALESCE(futuros.total, 0)::INTEGER,
        COALESCE(passados.total, 0)::INTEGER,
        COALESCE(hoje.total, 0)::INTEGER,
        COALESCE(futuros.codigos, 'Nenhum'),
        COALESCE(passageiros.total, 0)::INTEGER,
        CASE 
            WHEN COALESCE(futuros.total, 0) = 0 AND COALESCE(hoje.total, 0) = 0 THEN TRUE 
            ELSE FALSE 
        END,
        CASE 
            WHEN COALESCE(futuros.total, 0) > 0 THEN 
                FORMAT('Possui %s voo(s) futuro(s) - cancelar primeiro', futuros.total)
            WHEN COALESCE(hoje.total, 0) > 0 THEN 
                'Possui voo(s) hoje - aguardar conclusão'
            WHEN COALESCE(passados.total, 0) > 0 THEN 
                FORMAT('Possui apenas %s voo(s) histórico(s) - pode deletar', passados.total)
            ELSE 
                'Sem voos vinculados - pode deletar'
        END
    FROM aeronave a
    LEFT JOIN (
        -- Total de assentos
        SELECT cod_aeronave, COUNT(*) as total
        FROM mapa
        WHERE cod_aeronave = p_cod_aeronave
        GROUP BY cod_aeronave
    ) assentos ON a.cod_aeronave = assentos.cod_aeronave
    LEFT JOIN (
        -- Total de voos
        SELECT cod_aeronave, COUNT(*) as total
        FROM voo
        WHERE cod_aeronave = p_cod_aeronave
        GROUP BY cod_aeronave
    ) todos_voos ON a.cod_aeronave = todos_voos.cod_aeronave
    LEFT JOIN (
        -- Voos futuros
        SELECT 
            cod_aeronave, 
            COUNT(*) as total,
            STRING_AGG(DISTINCT cod_voo::TEXT, ', ' ORDER BY cod_voo::TEXT) as codigos
        FROM voo
        WHERE cod_aeronave = p_cod_aeronave AND dt_partida > CURRENT_DATE
        GROUP BY cod_aeronave
    ) futuros ON a.cod_aeronave = futuros.cod_aeronave
    LEFT JOIN (
        -- Voos passados
        SELECT cod_aeronave, COUNT(*) as total
        FROM voo
        WHERE cod_aeronave = p_cod_aeronave AND dt_partida < CURRENT_DATE
        GROUP BY cod_aeronave
    ) passados ON a.cod_aeronave = passados.cod_aeronave
    LEFT JOIN (
        -- Voos hoje
        SELECT cod_aeronave, COUNT(*) as total
        FROM voo
        WHERE cod_aeronave = p_cod_aeronave AND dt_partida = CURRENT_DATE
        GROUP BY cod_aeronave
    ) hoje ON a.cod_aeronave = hoje.cod_aeronave
    LEFT JOIN (
        -- Passageiros afetados (em voos futuros)
        SELECT 
            v.cod_aeronave, 
            COUNT(DISTINCT p.cod_passageiro) as total
        FROM voo v
        INNER JOIN passagem_voo pv ON v.cod_voo = pv.cod_voo
        INNER JOIN passagem p ON pv.cod_passagem = p.cod_passagem
        WHERE v.cod_aeronave = p_cod_aeronave AND v.dt_partida >= CURRENT_DATE
        GROUP BY v.cod_aeronave
    ) passageiros ON a.cod_aeronave = passageiros.cod_aeronave
    WHERE a.cod_aeronave = p_cod_aeronave;
END;
$$ LANGUAGE plpgsql;

-- Função para listar aeronaves que podem ser deletadas
CREATE OR REPLACE FUNCTION listar_aeronaves_deletaveis()
RETURNS TABLE(
    codigo_aeronave INTEGER,
    modelo TEXT,
    total_assentos INTEGER,
    total_voos INTEGER,
    status_delecao TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.cod_aeronave,
        a.modelo,
        COALESCE(assentos.total, 0)::INTEGER,
        COALESCE(todos_voos.total, 0)::INTEGER,
        CASE 
            WHEN futuros.total > 0 THEN 
                FORMAT('BLOQUEADO - %s voo(s) futuro(s)', futuros.total)
            WHEN hoje.total > 0 THEN 
                FORMAT('AGUARDAR - %s voo(s) hoje', hoje.total)
            WHEN passados.total > 0 THEN 
                FORMAT('PODE DELETAR - apenas %s voo(s) histórico(s)', passados.total)
            ELSE 
                'PODE DELETAR - sem voos'
        END as status_delecao
    FROM aeronave a
    LEFT JOIN (
        SELECT cod_aeronave, COUNT(*) as total FROM mapa GROUP BY cod_aeronave
    ) assentos ON a.cod_aeronave = assentos.cod_aeronave
    LEFT JOIN (
        SELECT cod_aeronave, COUNT(*) as total FROM voo GROUP BY cod_aeronave
    ) todos_voos ON a.cod_aeronave = todos_voos.cod_aeronave
    LEFT JOIN (
        SELECT cod_aeronave, COUNT(*) as total FROM voo 
        WHERE dt_partida > CURRENT_DATE GROUP BY cod_aeronave
    ) futuros ON a.cod_aeronave = futuros.cod_aeronave
    LEFT JOIN (
        SELECT cod_aeronave, COUNT(*) as total FROM voo 
        WHERE dt_partida = CURRENT_DATE GROUP BY cod_aeronave
    ) hoje ON a.cod_aeronave = hoje.cod_aeronave
    LEFT JOIN (
        SELECT cod_aeronave, COUNT(*) as total FROM voo 
        WHERE dt_partida < CURRENT_DATE GROUP BY cod_aeronave
    ) passados ON a.cod_aeronave = passados.cod_aeronave
    ORDER BY 
        CASE 
            WHEN COALESCE(futuros.total, 0) = 0 AND COALESCE(hoje.total, 0) = 0 THEN 0 
            ELSE 1 
        END,
        a.cod_aeronave;
END;
$$ LANGUAGE plpgsql;

-- Função para forçar remoção de aeronave (remove voos futuros associados primeiro)
-- USO COM CUIDADO - CANCELA TODOS OS VOOS FUTUROS E REEMBOLSA PASSAGEIROS!
CREATE OR REPLACE FUNCTION deletar_aeronave_forcado(
    p_cod_aeronave INTEGER,
    p_confirmar BOOLEAN DEFAULT FALSE
) RETURNS TEXT AS $$
DECLARE
    v_modelo TEXT;
    v_voos_removidos INTEGER;
    v_passageiros_afetados INTEGER;
    v_resultado TEXT;
BEGIN
    -- Validação de confirmação
    IF NOT p_confirmar THEN
        RAISE EXCEPTION 'Para usar esta função destrutiva, passe TRUE como segundo parâmetro para confirmar';
    END IF;
    
    -- Validações básicas
    IF p_cod_aeronave IS NULL OR p_cod_aeronave <= 0 THEN
        RAISE EXCEPTION 'Código da aeronave deve ser um número positivo';
    END IF;
    
    -- Verifica se a aeronave existe
    SELECT modelo INTO v_modelo 
    FROM aeronave 
    WHERE cod_aeronave = p_cod_aeronave;
    
    IF v_modelo IS NULL THEN
        RAISE EXCEPTION 'Aeronave com código % não existe', p_cod_aeronave;
    END IF;
    
    -- Conta voos futuros e passageiros afetados
    SELECT 
        COUNT(DISTINCT v.cod_voo),
        COUNT(DISTINCT p.cod_passageiro)
    INTO v_voos_removidos, v_passageiros_afetados
    FROM voo v
    LEFT JOIN passagem_voo pv ON v.cod_voo = pv.cod_voo
    LEFT JOIN passagem p ON pv.cod_passagem = p.cod_passagem
    WHERE v.cod_aeronave = p_cod_aeronave 
    AND v.dt_partida >= CURRENT_DATE;
    
    -- Remove todos os voos futuros associados (cascata: parcelas, passagem_voo, passagens, reservas)
    -- Remove parcelas primeiro (FK para reserva)
    DELETE FROM parcela 
    WHERE cod_reserva IN (
        SELECT DISTINCT r.cod_reserva
        FROM reserva r
        INNER JOIN passagem p ON r.cod_reserva = p.cod_reserva
        INNER JOIN passagem_voo pv ON p.cod_passagem = pv.cod_passagem
        INNER JOIN voo v ON pv.cod_voo = v.cod_voo
        WHERE v.cod_aeronave = p_cod_aeronave AND v.dt_partida >= CURRENT_DATE
    );
    
    -- Remove passagem_voo
    DELETE FROM passagem_voo 
    WHERE cod_voo IN (
        SELECT cod_voo FROM voo 
        WHERE cod_aeronave = p_cod_aeronave AND dt_partida >= CURRENT_DATE
    );
    
    -- Remove passagens
    DELETE FROM passagem 
    WHERE cod_reserva IN (
        SELECT DISTINCT r.cod_reserva
        FROM reserva r
        INNER JOIN passagem p ON r.cod_reserva = p.cod_reserva
        INNER JOIN passagem_voo pv ON p.cod_passagem = pv.cod_passagem
        INNER JOIN voo v ON pv.cod_voo = v.cod_voo
        WHERE v.cod_aeronave = p_cod_aeronave AND v.dt_partida >= CURRENT_DATE
    );
    
    -- Remove reservas órfãs
    DELETE FROM reserva 
    WHERE cod_reserva NOT IN (SELECT DISTINCT cod_reserva FROM passagem);
    
    -- Remove itinerários dos voos futuros
    DELETE FROM itinerario 
    WHERE cod_voo IN (
        SELECT cod_voo FROM voo 
        WHERE cod_aeronave = p_cod_aeronave AND dt_partida >= CURRENT_DATE
    );
    
    -- Remove voos futuros
    DELETE FROM voo 
    WHERE cod_aeronave = p_cod_aeronave AND dt_partida >= CURRENT_DATE;
    
    -- Remove mapa de assentos
    DELETE FROM mapa 
    WHERE cod_aeronave = p_cod_aeronave;
    
    -- Remove a aeronave
    DELETE FROM aeronave 
    WHERE cod_aeronave = p_cod_aeronave;
    
    -- Monta resultado
    v_resultado := FORMAT('Aeronave %s (%s) removida com sucesso. %s voo(s) futuro(s) cancelado(s), %s passageiro(s) afetado(s).',
                         p_cod_aeronave, v_modelo, 
                         COALESCE(v_voos_removidos, 0), 
                         COALESCE(v_passageiros_afetados, 0));
    
    RETURN v_resultado;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Erro ao deletar aeronave forçadamente: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- Exemplos de uso:
/*
-- Verificar se uma aeronave pode ser deletada
SELECT * FROM verificar_dependencias_aeronave(1);

-- Listar todas as aeronaves e seu status para deleção
SELECT * FROM listar_aeronaves_deletaveis();

-- Deletar aeronave (só funciona se não houver voos futuros)
SELECT deletar_aeronave(7);

-- Forçar deleção (CUIDADO: cancela todos os voos futuros)
SELECT deletar_aeronave_forcado(1, TRUE);
*/

-- ========================================
-- CONTROLE DE ACESSO SIMPLES
-- Companhia Aérea - 3 Tipos de Usuário
-- ========================================

-- 1. CRIAÇÃO DOS 3 USUÁRIOS
-- =========================

-- Passageiro: só consulta
CREATE USER passageiro WITH PASSWORD 'senha123';

-- Atendente: consulta + vendas
CREATE USER atendente WITH PASSWORD 'senha123';

-- Gerente: tudo
CREATE USER gerente WITH PASSWORD 'senha123';

-- 2. PERMISSÕES POR USUÁRIO
-- =========================

-- PASSAGEIRO: Apenas consultas básicas
GRANT SELECT ON aeroporto TO passageiro;
GRANT SELECT ON voo TO passageiro;
GRANT SELECT ON itinerario TO passageiro;
GRANT SELECT ON aeronave TO passageiro;
GRANT SELECT ON pagamento TO passageiro;

-- ATENDENTE: Consultas + operações de venda
GRANT SELECT ON ALL TABLES IN SCHEMA public TO atendente;
GRANT INSERT, UPDATE ON reserva TO atendente;
GRANT INSERT ON passagem TO atendente;
GRANT INSERT ON passagem_voo TO atendente;
GRANT INSERT ON parcela TO atendente;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO atendente;

-- GERENTE: Acesso total
GRANT ALL ON ALL TABLES IN SCHEMA public TO gerente;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO gerente;

-- 3. FUNÇÕES ESPECÍFICAS POR USUÁRIO
-- ==================================

-- FUNÇÃO PARA PASSAGEIRO: Consultar voos disponíveis
CREATE OR REPLACE FUNCTION consultar_voos_disponiveis()
RETURNS TABLE(
    cod_voo INTEGER,
    data_partida DATE,
    origem TEXT,
    destino TEXT,
    modelo TEXT,
    assentos_livres BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        v.cod_voo,
        v.dt_partida,
        io.cod_aeroporto,
        id.cod_aeroporto,
        a.modelo,
        COUNT(m.num_assento) - COUNT(pv.num_assento) as assentos_livres
    FROM voo v
    INNER JOIN aeronave a ON v.cod_aeronave = a.cod_aeronave
    INNER JOIN mapa m ON a.cod_aeronave = m.cod_aeronave
    INNER JOIN itinerario io ON v.cod_voo = io.cod_voo AND io.tipo_voo = 'ORIGEM'
    INNER JOIN itinerario id ON v.cod_voo = id.cod_voo AND id.tipo_voo = 'DESTINO'
    LEFT JOIN passagem_voo pv ON v.cod_voo = pv.cod_voo AND m.num_assento = pv.num_assento
    WHERE v.dt_partida >= CURRENT_DATE
    GROUP BY v.cod_voo, v.dt_partida, io.cod_aeroporto, id.cod_aeroporto, a.modelo
    ORDER BY v.dt_partida;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION consultar_voos_disponiveis() TO passageiro;

-- FUNÇÃO PARA ATENDENTE: Vender passagem
CREATE OR REPLACE FUNCTION vender_passagem(
    p_cod_voo INTEGER,
    p_nome_passageiro TEXT,
    p_valor_passagem NUMERIC,
    p_cod_pagamento TEXT,
    p_num_parcelas INTEGER DEFAULT 1
) RETURNS INTEGER AS $$
BEGIN
    -- Simplesmente chama a função de compra existente
    RETURN cadastrar_compra(p_cod_voo, p_nome_passageiro, p_valor_passagem, p_cod_pagamento, p_num_parcelas);
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION vender_passagem(INTEGER, TEXT, NUMERIC, TEXT, INTEGER) TO atendente;

-- FUNÇÃO PARA ATENDENTE: Listar passageiros de um voo
CREATE OR REPLACE FUNCTION listar_passageiros_voo(p_cod_voo INTEGER)
RETURNS TABLE(
    nome_passageiro TEXT,
    num_assento TEXT,
    valor_passagem NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.nome_passageiro,
        pv.num_assento,
        pv.valor_passagem
    FROM passagem p
    INNER JOIN passagem_voo pv ON p.cod_passagem = pv.cod_passagem
    WHERE pv.cod_voo = p_cod_voo
    ORDER BY pv.num_assento;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION listar_passageiros_voo(INTEGER) TO atendente;

-- FUNÇÃO PARA GERENTE: Relatório de ocupação
CREATE OR REPLACE FUNCTION relatorio_ocupacao(
    p_data_inicio DATE,
    p_data_fim DATE
) RETURNS TABLE(
    cod_voo INTEGER,
    data_partida DATE,
    origem TEXT,
    destino TEXT,
    total_assentos BIGINT,
    assentos_vendidos BIGINT,
    percentual_ocupacao NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        v.cod_voo,
        v.dt_partida,
        io.cod_aeroporto,
        id.cod_aeroporto,
        COUNT(m.num_assento) as total_assentos,
        COUNT(pv.num_assento) as assentos_vendidos,
        ROUND((COUNT(pv.num_assento) * 100.0 / COUNT(m.num_assento)), 2) as percentual_ocupacao
    FROM voo v
    INNER JOIN aeronave a ON v.cod_aeronave = a.cod_aeronave
    INNER JOIN mapa m ON a.cod_aeronave = m.cod_aeronave
    INNER JOIN itinerario io ON v.cod_voo = io.cod_voo AND io.tipo_voo = 'ORIGEM'
    INNER JOIN itinerario id ON v.cod_voo = id.cod_voo AND id.tipo_voo = 'DESTINO'
    LEFT JOIN passagem_voo pv ON v.cod_voo = pv.cod_voo AND m.num_assento = pv.num_assento
    WHERE v.dt_partida BETWEEN p_data_inicio AND p_data_fim
    GROUP BY v.cod_voo, v.dt_partida, io.cod_aeroporto, id.cod_aeroporto
    ORDER BY v.dt_partida;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION relatorio_ocupacao(DATE, DATE) TO gerente;

-- FUNÇÃO PARA GERENTE: Cancelar reserva
CREATE OR REPLACE FUNCTION cancelar_reserva(p_cod_reserva INTEGER)
RETURNS BOOLEAN AS $$
BEGIN
    -- Remove todos os dados relacionados à reserva
    DELETE FROM parcela WHERE cod_reserva = p_cod_reserva;
    DELETE FROM passagem_voo WHERE cod_passagem IN (
        SELECT cod_passagem FROM passagem WHERE cod_reserva = p_cod_reserva
    );
    DELETE FROM passagem WHERE cod_reserva = p_cod_reserva;
    DELETE FROM reserva WHERE cod_reserva = p_cod_reserva;
    
    RETURN true;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION cancelar_reserva(INTEGER) TO gerente;

-- 4. EXEMPLOS DE USO
-- ==================

/*
-- CONECTAR COMO PASSAGEIRO:
-- psql -U passageiro -d nome_do_banco

-- O que o passageiro pode fazer:
SELECT * FROM consultar_voos_disponiveis();

-- CONECTAR COMO ATENDENTE:
-- psql -U atendente -d nome_do_banco

-- O que o atendente pode fazer:
SELECT vender_passagem(1, 'João Silva', 299.90, 'PIX', 1);
SELECT * FROM listar_passageiros_voo(1);
SELECT * FROM consultar_compra(1);

-- CONECTAR COMO GERENTE:
-- psql -U gerente -d nome_do_banco

-- O que o gerente pode fazer:
SELECT * FROM relatorio_ocupacao('2025-12-01', '2025-12-31');
SELECT cancelar_reserva(1);
SELECT cadastrar_voo('2025-12-20', '2025-12-20', 1, 'GRU', 'SDU');
SELECT cadastrar_aeronave('Boeing 737', 180);
*/

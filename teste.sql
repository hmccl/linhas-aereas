-- @@@@ Teste de insert de aeroportos @@@@
-- Código e/ou cidade não podem ser vazios
-- Código deve ter 3 letras e somente letras
-- Código é inserido em maiúsculo
-- Código não pode ser duplicado
-- Funções auxiliares
--      listar_aeroportos()
--      buscar_aeroporto(cod_aeroporto)
select cadastrar_aeroporto('MIA', 'Miami');
select cadastrar_aeroporto('MIA', 'Dallas');
select listar_aeroportos();

-- @@@@ Teste de insert de aeronaves @@@@
-- Código não pode ser vazio
-- Número de assentos deve ser maior que zero
-- Assento gerado automaticamente 1(A, B , C ou D)
-- Funções auxiliares
--      listar_aeronaves()
select cadastrar_aeronave('B2', 2);
select listar_aeronaves();

-- @@@@ Teste de insert de pagamento @@@@
-- Código e/ou nome não pode ser vazio
-- Código não pode ser duplicado
-- Funções auxiliares
--      listar_tipos_pagamento()
select cadastrar_tipo_pagamento('CC', 'Cartão');
select * from listar_tipos_pagamento();

-- @@@@ Teste de insert de voo @@@@
-- Datas, códigos de aeronave e aeroportos não podem ser vazios
-- Data de partida não pode estar no passado
-- Códigos de aeronave e aeroportos devem existir
-- Verifica disponibilidade da aeronave
-- Funções auxiliares
--      listar_voos()
--      buscar_voo(cod_voo)
--      verificar_disponibilidade_aeronave(cod_aeronave, dt_partida, dt_chegada)
select verificar_disponibilidade_aeronave(1, '2025-07-10', '2024-07-10');
select * from listar_voos();
select * from buscar_voo(1);

-- @@@@ Teste de insert de compra @@@@
-- Verifica variáveis
-- Verifica se voo é do passado
-- Verifica assento
-- Funções auxiliares
--      consultar_compra(cod_reserva)
--      consultar_pacelas(cod_reserva)
--      consultar_assentos_disponiveis(cod_voo)
select * from consultar_compra(1);
select * from consultar_parcelas(2);
select * from consultar_assentos_disponiveis(1);

-- @@@@ Teste de delete de aeronaves @@@@
-- Verifica variáveis
-- Não deleta se existir voos futuros
-- Funções auxiliares
--      listar_aeronaves_deletaveis()
--      verificar_dependencias_aeronave(cod_aeronave)
select cadastrar_aeronave('Cessna 208', 10);
select deletar_aeronave(6);
select * from listar_aeronaves_deletaveis();
select * from verificar_dependencias_aeronave(1);

-- @@@@ Teste de delete de aeroporto @@@@
-- Verifica variáveis
-- Não deleta se existir voos futuros
-- Funções auxiliares
--      listar_aeroportos_deletaveis()
--      verificar_dependencias_aeroporto(cod_aeroporto)
select deletar_aeroporto('MIA');
select deletar_aeroporto('GRU');
select * from listar_aeronaves_deletaveis();
select * from verificar_dependencias_aeroporto('GRU');

-- @@@@ Teste de update de voo @@@@
-- Verifica variáveis
-- Não altera voos passados
-- Funções auxiliares
--      consultar_detalhes_voo_alteracao(cod_voo)
--      listar_passageiros_afetados(cod_voo)
select alterar_horario_voo(1, '2025-08-10', '2025-08-10');
select * from consultar_detalhes_voo_alteracao(1);
select * from listar_passageiros_afetados(1);

-- @@@@ Teste de relatorios e autorizacoes @@@@
-- passageiro 'passageiro';
select * from consultar_voos_disponiveis();
-- atendente 'atendente';
select vender_passagem(1, 'João Silva', 299.90, 'PIX', 1);
select * from listar_passageiros_voo(1);
select * from consultar_compra(1);
-- gerente 'gerente';
select * from relatorio_ocupacao('2025-12-01', '2025-12-31');
select cancelar_reserva(1);
select cadastrar_voo('2025-12-20', '2025-12-20', 1, 'GRU', 'SDU');
select cadastrar_aeronave('Boeing 737', 180);

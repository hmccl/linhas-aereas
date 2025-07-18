-- Insere aeroportos do Brasil
select cadastrar_aeroporto('GRU', 'São Paulo');
select cadastrar_aeroporto('SDU', 'Rio de Janeiro');
select cadastrar_aeroporto('BSB', 'Brasília');
select cadastrar_aeroporto('CGH', 'São Paulo');
select cadastrar_aeroporto('SSA', 'Salvador');
select cadastrar_aeroporto('FOR', 'Fortaleza');
select cadastrar_aeroporto('REC', 'Recife');
select cadastrar_aeroporto('POA', 'Porto Alegre');
select cadastrar_aeroporto('CWB', 'Curitiba');
select cadastrar_aeroporto('BEL', 'Belém');
select cadastrar_aeroporto('MAO', 'Manaus');
select cadastrar_aeroporto('VIX', 'Vitória');
select cadastrar_aeroporto('CNF', 'Belo Horizonte');
select cadastrar_aeroporto('FLN', 'Florianópolis');
select cadastrar_aeroporto('THE', 'Teresina');

-- Insere diversas aeronaves na forta da companhia
select cadastrar_aeronave('Boeing 737', 10);
select cadastrar_aeronave('Boeing 777', 30);
select cadastrar_aeronave('Airbus A320', 15);
select cadastrar_aeronave('Airbus A320', 12);
select cadastrar_aeronave('Cessna 208', 5);

-- Insere diversos voos na agenda da companhia
select cadastrar_voo('2025-07-10', '2025-07-10', 1, 'THE', 'REC');
select cadastrar_voo('2025-07-10', '2025-07-11', 2, 'THE', 'GRU');
select cadastrar_voo('2025-07-12', '2025-07-12', 3, 'FOR', 'POA');
select cadastrar_voo('2025-07-25', '2025-07-25', 4, 'BSB', 'SDU');

-- Insere os tipos de pagamentos aceitos
select cadastrar_tipo_pagamento('PIX', 'PIX');
select cadastrar_tipo_pagamento('CC', 'Cartão de Crédito');
select cadastrar_tipo_pagamento('CD', 'Cartão de Débito');

-- Inserir exemplos de compras
select cadastrar_compra('1', 'João', '700', 'CD', 1);
select cadastrar_compra('2', 'Augusto', '300', 'PIX', 1);
select cadastrar_compra('2', 'Ana', '300', 'PIX', 1);
select cadastrar_compra('2', 'Ena', '300', 'PIX', 1);
select cadastrar_compra('2', 'José', '300', 'PIX', 1);
select cadastrar_compra('3', 'Maria', '2000', 'CC', 5);

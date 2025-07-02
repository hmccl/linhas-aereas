-- @@@@ Criação das tabelas @@@@

-- 1. Tabelas independentes
create table if not exists aeroporto (
    cod_aeroporto text primary key,
    cidade text not null
);

create table if not exists aeronave (
    cod_aeronave integer generated always as identity primary key,
    modelo text not null
);

-- check formato numero assento
create table if not exists assento (
    num_assento text primary key
);

-- check opções de pagamento
create table if not exists pagamento (
    cod_pagamento text not null primary key,
    nome text not null
);

-- 2. Tabelas dependentes
-- check nas datas, partida antes de chegada
create table if not exists voo (
    cod_voo integer generated always as identity primary key,
    dt_partida date not null,
    dt_chegada date not null,
    cod_aeronave integer not null,
    foreign key (cod_aeronave) references aeronave (cod_aeronave)
);

-- check para o tipo voo
create table if not exists itinerario (
    cod_itinerario integer generated always as identity primary key,
    tipo_voo text not null,
    cod_voo integer not null,
    cod_aeroporto text not null,
    foreign key (cod_voo) references voo (cod_voo),
    foreign key (cod_aeroporto) references aeroporto (cod_aeroporto)
);

create table if not exists mapa (
    cod_aeronave integer not null,
    num_assento text not null,
    primary key (cod_aeronave, num_assento),
    foreign key (cod_aeronave) references aeronave (cod_aeronave),
    foreign key (num_assento) references assento (num_assento)
);

-- check para a data reserva
create table if not exists reserva (
    cod_reserva integer generated always as identity primary key,
    dt_reserva date not null,
    valor_total numeric not null,
    cod_pagamento text not null,
    foreign key (cod_pagamento) references pagamento (cod_pagamento)
);

-- check para valor da parcela
create table if not exists parcela (
    cod_parcela integer generated always as identity primary key,
    cod_reserva integer not null,
    valor_parcela numeric not null,
    dt_parcela date not null,
    foreign key (cod_reserva) references reserva (cod_reserva)
);

-- valor da passagem pode ser em voo na verdade
create table if not exists passagem (
    cod_passagem integer generated always as identity primary key,
    cod_passageiro integer generated always as identity unique,
    nome_passageiro text not null,
    valor_passagem numeric not null,
    cod_reserva integer not null,
    foreign key (cod_reserva) references reserva (cod_reserva)
);

-- restrição para o numero assento
create table if not exists passagem_voo (
    cod_passagem integer not null,
    cod_voo integer not null,
    num_assento text not null,
    primary key (cod_passagem, cod_voo),
    foreign key (cod_passagem) references passagem (cod_passagem),
    foreign key (cod_voo) references voo (cod_voo)
);

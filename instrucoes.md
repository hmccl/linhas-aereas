# Enunciado

- Toda a interação do usuário com o banco de dados será por meio de chamadas de funções SQL.
- É obrigatório: inserção de dados; remoção de dados; e alteração de dados.

# Insert

- Funções de cadastro para povoar as tabelas.

1. Cadastro de aeroportos
  - Preenche tabela: Aeroporto.
2. Cadastro de aeronaves
  - Preenche tabelas: Aeronave, Mapa, Assento.
  - Para o número de assentos será informado o número total e os números serão automáticos.
3. Cadastro de voos
  - Preenche tabelas: Voo, Itinerario.
4. Cadastro de reservas
  - Preenche tabelas: Reserva, Pagamento, Parcela, Passagem, Passagem_Voo.
  - Um reserva pode ter mais de um passageiro, e todos eles fazem o mesmo voo.

# Delete

- Funções de remoção para eliminar linhas das tabelas. Pode-se utilizar hard delete ou soft delete. Hard delete pode ser melhor.

1. Deletar aeroportos
  - Remove ou tira referência das linhas da tabela: Aeroporto.
2. Deletar aeronave
  - Remove ou tira referência das linhas da tabela: Aeronave.
3. Deletar voos
  - Remove ou tira referência das linhas da tabela: Voo e Itinerario.

# Update

- Funções de atualização de linhas das tabelas.

1. Atualizar data de partida e data de chegada de determinado voo. Note que, as datas só podem ser adiadas.

# Controle de Acesso

- Crie um controle de acesso. Usuários existentes: Passageiro, Atendente e Gerente.

# Relatórios

- Emissão de relatórios de interesse para cada usuário do sistema.
  - Para o passageiro:
    - Relatório com as informações do seu voo. Emitir relatório a partir do número do voo.
    - Relatório com as informações da reserva. Emitir relatório a partir do código de reserva.
  - Para o atendente:
    - Relatório com o nome dos passageiros do voo. Emitir relatório a partir do código do voo.
  - Para o gerente:
    - Relatório com a ocupação de um determinado voo para um determinado período.
    - Relatório com a quantidade total de clientes distintos num determinado período.

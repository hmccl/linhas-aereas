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
  - O tipo de voo identifica se é a origem ou destino do código do voo em questão.
4. Cadastro de tipo de pagamento
  - Preenche tabela: Pagamento.
  - São três tipos: PIX, Cartão de Crédito (CC), Cartão de Débito (CD).
4. Cadastro de compra
  - Preenche tabelas: Reserva, Passagem, Passagem_Voo, Parcela.
  - Uma grande função para os seguintes passos:
    - Primeiro a tabela Reserva será preenchida.
      - O código da reserva será gerado.
      - A data será do dia atual.
      - O valor_total inicialmente será 0 (zero).
      - O código do pagamento será inserido.
    - Depois a tabela Passagem será preechida.
      - O códido da passagem é gerado.
      - O código da reserva é preenchido.
      - O código do passageiro é gerado.
      - O nome do passageiro é preenchido.
      - O valor da passagem é preenchido.
    - Depois a tabela Passagem_Voo é preenchida.
      - O num_assento é determinado automaticamente, com assento disponível.
    - Depois a tabela Reserva será atualizada.
      - A soma das passagens de determinada reserva preenche o valor_total.
    - Por fim, a tabela Parcela será preenchida.
      - O código da parcela é gerado.
      - O código da reserva é preenchido.
      - O número de parcelas passado para a função determina:
        - O valor das parcelas.
        - As datas das parcelas, ou seja, soma mais trinta dias para a data da próxima parcela.

# Delete

- Funções de remoção para eliminar linhas das tabelas. Pode-se utilizar hard delete ou soft delete. Hard delete pode ser melhor.

1. Deletar aeroportos
  - Remove ou tira referência das linhas da tabela: Aeroporto.
2. Deletar aeronave
  - Remove ou tira referência das linhas da tabela: Aeronave.

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

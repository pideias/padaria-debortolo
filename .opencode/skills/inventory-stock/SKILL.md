---
name: inventory-stock
description: Use when working on product registration, stock entries, exits, barcode search, alerts, or inventory history.
---

# Estoque

1. Entradas aumentam o saldo e saidas reduzem o saldo.
2. Nunca permita saldo negativo.
3. Registre tipo, quantidade, motivo, produto e data; não atribua usuário se o fluxo/schema atual não o armazena.
4. Permita pesquisa por nome e codigo de barras.
5. Mantenha o limite de estoque baixo configuravel ou documentado.
6. Mostre alertas quando a quantidade estiver abaixo do limite.
7. Use parametros SQL e transacoes.
8. Preserve o historico de movimentacoes.
9. Venda deve ser registrada como saida.
10. Atualize web e mobile apos qualquer alteracao de estoque.
11. No atendimento MVC, valide cada inclusão contra `quantidade_estoque` menos a quantidade já presente no pedido; não confie no limite do campo HTML.
12. Revalide todos os itens ao finalizar: a baixa de saldo, a movimentação `Saida`, o pagamento e a finalização do pedido devem ocorrer na mesma transação.
13. Se o estoque mudou enquanto o pedido estava aberto, rejeite a finalização completa, mantenha o pedido para correção e informe o saldo disponível.
14. O cliente mobile pode enfileirar movimentações quando offline, mas a API/SQL Server confirma o saldo oficial ao sincronizar.

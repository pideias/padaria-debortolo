---
name: pdv-sales
description: Use when working on the Padaria Debortolo PDV, cart, sales, payments, orders, or checkout flow.
---

# PDV e Vendas

1. O carrinho deve acumular produtos sem duplicar linhas do mesmo item.
2. Mostre quantidade, preco unitario, subtotal e total.
3. Permita aumentar, diminuir, remover e limpar itens.
4. Exija forma de pagamento antes de finalizar.
5. Revalide estoque no servidor antes de concluir.
6. Grave pedido, itens, pagamento e baixa de estoque na mesma transacao.
7. Nao finalize venda parcialmente.
8. Preserve venda offline em fila para sincronizacao posterior.
9. Exiba mensagens claras de sucesso, erro e conflito.
10. Mantenha os botoes visiveis, alinhados e adequados a toque.
11. No fluxo MVC de atendimento, incluir um item verifica o saldo disponível menos o que já está no pedido; a inclusão não baixa o estoque.
12. A finalização web revalida saldo e quantidade, grava pagamento, pedido finalizado, baixa e movimentação de saída em uma única transação.
13. Se a validação final falhar, não finalize parcialmente: preserve o pedido aberto e devolva uma mensagem para o usuário ajustar os itens.
14. Atualizar ou voltar à tela do atendimento não deve cancelar o pedido automaticamente; somente a ação explícita de cancelar deve removê-lo.
15. No mobile, o total do carrinho é uma estimativa; a API revalida preço e estoque. Pendências offline são confirmações provisórias até o servidor aceitá-las.

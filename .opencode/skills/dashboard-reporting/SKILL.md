---
name: dashboard-reporting
description: Use when creating dashboards, sales indicators, stock summaries, reports, or low-stock visualizations.
---

# Dashboard e Relatorios

1. Use agregações servidas pela API para métricas de vendas; não infira faturamento a partir de dados parciais do cliente.
2. Mostre quantidade total em estoque.
3. Destaque produtos abaixo do estoque minimo.
4. Identifique a data e o periodo dos indicadores.
5. Trate listas vazias sem quebrar a interface.
6. Atualize indicadores apos uma venda ou movimentacao.
7. Para o relatório atual de vendas por produto, consuma `GET /api/relatorios/vendas/produtos`, que retorna unidades e faturamento de pedidos finalizados e pagos.
8. Identifique o período: o endpoint atual resume todo o histórico finalizado e pago; não apresente esses dados como sendo apenas do dia.
9. Trate listas vazias e falhas de rede com estados visuais claros e opção de atualizar.
10. Atualize relatórios após novas vendas e mantenha gráficos/legendas legíveis em Android e desktop.
11. Gráficos interativos podem agregar produtos menos vendidos em “Outros”, mas devem preservar os totais e explicar a métrica selecionada.

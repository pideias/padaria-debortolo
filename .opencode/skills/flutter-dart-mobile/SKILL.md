---
name: flutter-dart-mobile
description: Use when creating or changing the Flutter/Dart application in InfiniteCoffeeMobile.
---

# Flutter e Dart

1. Mantenha o app Flutter separado do projeto ASP.NET MVC.
2. Use camadas para models, services, repositories, screens e utils.
3. Prefira widgets reutilizaveis e layouts responsivos.
4. Considere Android, Windows e Web ao escolher dependencias.
5. No cliente atual, o catálogo e a fila offline são persistidos com `shared_preferences`; não assuma Hive/SQLite nem arquivos `LocalDatabase`/`SyncService` sem confirmação no código.
6. `InventoryApi` chama a API REST; `InventoryRepository` mantém `cached_products` e `pending_stock_exits`. O SQL Server continua sendo a fonte oficial.
7. Relatórios agregados devem usar endpoints do backend. O relatório de vendas por produto consome `/api/relatorios/vendas/produtos`, que retorna unidades e faturamento de pedidos finalizados.
8. Prefira widgets adaptáveis, estados de carregamento/erro/vazio e gráficos legíveis em Android e desktop.
9. Execute `dart format`, `flutter analyze` e `flutter test` após alterações.
10. Gere o build do alvo alterado antes de informar que a funcionalidade está pronta.

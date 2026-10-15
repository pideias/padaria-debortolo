---
name: ai-project-context
description: Use when an AI or new developer needs to understand, modify, test, or document the Padaria Debortolo application and its backend; some repository folder names retain the former Infinite Coffee project name.
---

# Contexto para IAs

1. Leia `AGENTS.md` e `DOCUMENTACAO-IA.md` antes de alterar codigo.
2. Identifique se a tarefa pertence ao MVC/API SQL Server ou ao cliente Flutter.
3. Preserve contratos existentes: nomes de campos em portugues, rotas, procedures e mensagens.
4. Para banco, leia `Banco.cs`, consulte foreign keys e nunca presuma que uma exclusao pode ser fisica.
5. Para Flutter, leia `InventoryApi`, `InventoryRepository`, os modelos e a tela afetada. Não presuma `LocalDatabase`, `SyncService` ou Hive: confirme primeiro os arquivos e dependências existentes.
6. Trate SQL Server como fonte oficial. No cliente atual, `shared_preferences` guarda o catálogo (`cached_products`) e a fila (`pending_stock_exits`).
7. Documente alteracoes de contrato, sincronizacao, rede ou schema no `DOCUMENTACAO-IA.md`.
8. Nao invente credenciais, tabelas ou endpoints; confirme no codigo e no README.
9. O cliente atual consulta `GET /api/estoque` e envia operações pendentes a `POST /api/sync/push`; não presuma que o app execute o endpoint de pull.
10. Relatórios agregados devem ser calculados no servidor e consumidos pelo cliente por endpoint REST.
11. Ao terminar, informe arquivos alterados, validacoes executadas e limitacoes conhecidas.

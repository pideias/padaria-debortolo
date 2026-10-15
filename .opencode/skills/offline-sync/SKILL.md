---
name: offline-sync
description: Use when implementing local persistence, offline operations, queues, synchronization, or conflict handling in the mobile app.
---

# Offline e sincronização (implementação atual)

1. O SQL Server e a fonte oficial quando houver conexao.
2. O cliente persiste o catálogo serializado e a fila em `shared_preferences`, usando as chaves `cached_products` e `pending_stock_exits`; não pressuponha Hive ou SQLite.
3. As operações offline implementadas são entrada, saída e venda. Cada uma recebe `clientUuid` e seu payload.
4. Quando há conectividade, `InventoryRepository` envia as operações a `POST /api/sync/push` e remove da fila somente os identificadores aceitos.
5. O backend registra `clientUuid` em `SyncOperations` para reconhecer reenvios; estoque, preço e venda são validados no servidor.
6. Após uma consulta bem-sucedida, o cliente grava o catálogo e tenta sincronizar operações pendentes. A tela também recarrega ao recuperar conexão e por atualização periódica.
7. Sem conexão, é possível mostrar o último catálogo salvo e enfileirar entrada, saída ou venda. Cadastro/edição de produtos, histórico e relatório de vendas por produto continuam dependentes da API.
8. A fila local não é uma confirmação da venda: o SQL Server só confirma o resultado ao processar a operação.
9. Preserve operações rejeitadas ou não confirmadas para nova tentativa; não descarte histórico ou pendências silenciosamente.
10. Exclusão de produto é inativação no servidor (`ativo = 0`, saldo zerado), preservando pedidos e movimentações.

## Contratos atuais

- Consulta do catálogo: `GET /api/estoque`.
- Envio de pendências: `POST /api/sync/push` com `clientUuid`, `tipo` e `payload`.
- O endpoint de pull existe no backend, mas o cliente Flutter atual carrega o estoque pelo endpoint `/api/estoque`; não documente sync bidirecional no cliente sem implementar esse consumo.

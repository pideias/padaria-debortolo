-- LIMPEZA TOTAL DE DADOS: preserva tabelas, chaves, procedures e demais objetos.
-- Apaga produtos/saldos, clientes, funcionarios, mesas, pedidos, itens,
-- pagamentos, movimentacoes e SyncOperations. Os valores IDENTITY nao sao resemeados.
-- Antes de executar em producao, faça e verifique um backup do banco e limpe as
-- filas/cache offline dos aplicativos para evitar que clientes reenviem pendencias.
-- Para autorizar a execucao, altere @ConfirmarLimpeza para 1 depois de revisar o escopo.

USE [infiniteCoffee];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @ConfirmarLimpeza BIT = 0;
IF DB_NAME() <> N'infiniteCoffee'
    THROW 51000, 'Banco inesperado: a limpeza foi cancelada.', 1;
IF @ConfirmarLimpeza <> 1
    THROW 51001, 'Limpeza bloqueada. Revise o backup e altere @ConfirmarLimpeza para 1 para confirmar.', 1;

DECLARE @Pagamentos INT = 0;
DECLARE @Itens INT = 0;
DECLARE @Pedidos INT = 0;
DECLARE @Movimentacoes INT = 0;
DECLARE @SyncOperations INT = 0;
DECLARE @Produtos INT = 0;
DECLARE @Clientes INT = 0;
DECLARE @Funcionarios INT = 0;
DECLARE @Mesas INT = 0;

BEGIN TRY
    BEGIN TRANSACTION;

    -- Remover primeiro as tabelas filhas para respeitar as foreign keys.
    DELETE FROM dbo.Pagamentos;
    SET @Pagamentos = @@ROWCOUNT;

    DELETE FROM dbo.Itens_Pedidos;
    SET @Itens = @@ROWCOUNT;

    DELETE FROM dbo.Pedidos;
    SET @Pedidos = @@ROWCOUNT;

    DELETE FROM dbo.MovimentacoesEstoque;
    SET @Movimentacoes = @@ROWCOUNT;

    DELETE FROM dbo.SyncOperations;
    SET @SyncOperations = @@ROWCOUNT;

    -- Remover entidades de cadastro somente depois dos registros dependentes.
    DELETE FROM dbo.Produtos;
    SET @Produtos = @@ROWCOUNT;

    DELETE FROM dbo.Clientes;
    SET @Clientes = @@ROWCOUNT;

    DELETE FROM dbo.Funcionarios;
    SET @Funcionarios = @@ROWCOUNT;

    DELETE FROM dbo.Mesas;
    SET @Mesas = @@ROWCOUNT;

    COMMIT TRANSACTION;

    SELECT
        @Produtos AS produtos_removidos,
        @Clientes AS clientes_removidos,
        @Funcionarios AS funcionarios_removidos,
        @Mesas AS mesas_removidas,
        @Pedidos AS pedidos_removidos,
        @Itens AS itens_removidos,
        @Pagamentos AS pagamentos_removidos,
        @Movimentacoes AS movimentacoes_removidas,
        @SyncOperations AS operacoes_sync_removidas;

    SELECT
        (SELECT COUNT(*) FROM dbo.Produtos) AS produtos_restantes,
        (SELECT COUNT(*) FROM dbo.Clientes) AS clientes_restantes,
        (SELECT COUNT(*) FROM dbo.Funcionarios) AS funcionarios_restantes,
        (SELECT COUNT(*) FROM dbo.Mesas) AS mesas_restantes,
        (SELECT COUNT(*) FROM dbo.Pedidos) AS pedidos_restantes,
        (SELECT COUNT(*) FROM dbo.Itens_Pedidos) AS itens_restantes,
        (SELECT COUNT(*) FROM dbo.Pagamentos) AS pagamentos_restantes,
        (SELECT COUNT(*) FROM dbo.MovimentacoesEstoque) AS movimentacoes_restantes,
        (SELECT COUNT(*) FROM dbo.SyncOperations) AS operacoes_sync_restantes;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

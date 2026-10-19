-- Adiciona exclusao logica para clientes, funcionarios e mesas.
-- Seguro para execucao repetida: nao apaga nem reescreve registros existentes.
USE infiniteCoffee;
GO

IF COL_LENGTH('dbo.Clientes', 'ativo') IS NULL
    ALTER TABLE dbo.Clientes ADD ativo BIT NOT NULL
        CONSTRAINT DF_Clientes_ativo DEFAULT 1 WITH VALUES;
GO

IF COL_LENGTH('dbo.Funcionarios', 'ativo') IS NULL
    ALTER TABLE dbo.Funcionarios ADD ativo BIT NOT NULL
        CONSTRAINT DF_Funcionarios_ativo DEFAULT 1 WITH VALUES;
GO

IF COL_LENGTH('dbo.Mesas', 'ativo') IS NULL
    ALTER TABLE dbo.Mesas ADD ativo BIT NOT NULL
        CONSTRAINT DF_Mesas_ativo DEFAULT 1 WITH VALUES;
GO

CREATE OR ALTER PROCEDURE dbo.sp_ListarClientes
AS
    SELECT id_cliente, nome_cliente, email, telefone
    FROM dbo.Clientes
    WHERE ativo = 1;
GO

CREATE OR ALTER PROCEDURE dbo.sp_BuscarCliente @valor VARCHAR(100)
AS
    SELECT id_cliente, nome_cliente, email, telefone
    FROM dbo.Clientes
    WHERE ativo = 1
      AND (nome_cliente LIKE '%' + @valor + '%' OR email LIKE '%' + @valor + '%');
GO

CREATE OR ALTER PROCEDURE dbo.sp_ExcluirCliente @id INT
AS
    UPDATE dbo.Clientes SET ativo = 0 WHERE id_cliente = @id AND ativo = 1;
GO

CREATE OR ALTER PROCEDURE dbo.sp_ListarFuncionarios
AS
    SELECT id_funcionario, nome_funcionario, cargo
    FROM dbo.Funcionarios
    WHERE ativo = 1;
GO

CREATE OR ALTER PROCEDURE dbo.sp_ListarMesas
AS
    SELECT id_mesa, numero, capacidade, status_mesa
    FROM dbo.Mesas
    WHERE ativo = 1;
GO

CREATE OR ALTER PROCEDURE dbo.sp_ListarMesasLivres
AS
    SELECT id_mesa, numero, capacidade, status_mesa
    FROM dbo.Mesas
    WHERE ativo = 1 AND status_mesa IN ('Livre', 'Disponivel', 'Disponível');
GO

CREATE OR ALTER PROCEDURE dbo.sp_AtualizarStatusMesa @id INT, @status VARCHAR(60)
AS
    UPDATE dbo.Mesas SET status_mesa = @status WHERE id_mesa = @id AND ativo = 1;
GO

CREATE OR ALTER PROCEDURE dbo.sp_CriarPedido
    @mesaId INT,
    @funcionarioId INT,
    @clienteId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Serializa criação de pedido e inativação para não deixar pedido aberto
        -- associado a mesa/cliente/funcionário inativo.
        IF NOT EXISTS (SELECT 1 FROM dbo.Mesas WITH (UPDLOCK, HOLDLOCK) WHERE id_mesa = @mesaId AND ativo = 1)
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT CAST(0 AS INT) AS id_pedido;
            RETURN;
        END;
        IF NOT EXISTS (SELECT 1 FROM dbo.Clientes WITH (UPDLOCK, HOLDLOCK) WHERE id_cliente = @clienteId AND ativo = 1)
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT CAST(0 AS INT) AS id_pedido;
            RETURN;
        END;
        IF @funcionarioId IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM dbo.Funcionarios WITH (UPDLOCK, HOLDLOCK) WHERE id_funcionario = @funcionarioId AND ativo = 1)
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT CAST(0 AS INT) AS id_pedido;
            RETURN;
        END;

        INSERT INTO dbo.Pedidos (mesaid, funcionarioid, clienteid, datahora, status_pedido)
        VALUES (@mesaId, @funcionarioId, @clienteId, GETDATE(), 'Aberto');
        DECLARE @idPedido INT = CONVERT(INT, SCOPE_IDENTITY());

        COMMIT TRANSACTION;
        SELECT @idPedido AS id_pedido;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

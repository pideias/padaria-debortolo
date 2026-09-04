-- Complemento seguro para o banco infiniteCoffee local.
-- Nao remove dados nem altera as telas existentes.
USE infiniteCoffee;

IF OBJECT_ID('dbo.SyncOperations', 'U') IS NULL
    CREATE TABLE SyncOperations (client_uuid VARCHAR(100) NOT NULL PRIMARY KEY, tipo VARCHAR(30) NOT NULL, created_at DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME());

IF OBJECT_ID('dbo.Clientes', 'U') IS NULL
    CREATE TABLE Clientes (id_cliente INT IDENTITY(1,1) PRIMARY KEY, nome_cliente VARCHAR(100) NOT NULL, email VARCHAR(100) NULL, telefone VARCHAR(20) NULL);
IF OBJECT_ID('dbo.Funcionarios', 'U') IS NULL
    CREATE TABLE Funcionarios (id_funcionario INT IDENTITY(1,1) PRIMARY KEY, nome_funcionario VARCHAR(100) NOT NULL, cargo VARCHAR(100) NOT NULL);
IF OBJECT_ID('dbo.Mesas', 'U') IS NULL
    CREATE TABLE Mesas (id_mesa INT IDENTITY(1,1) PRIMARY KEY, numero INT NOT NULL, capacidade INT NOT NULL, status_mesa VARCHAR(60) NOT NULL);
IF OBJECT_ID('dbo.Pedidos', 'U') IS NULL
    CREATE TABLE Pedidos (id_pedido INT IDENTITY(1,1) PRIMARY KEY, mesaid INT NULL REFERENCES Mesas(id_mesa), funcionarioid INT NULL REFERENCES Funcionarios(id_funcionario), clienteid INT NULL REFERENCES Clientes(id_cliente), datahora DATETIME NOT NULL, status_pedido VARCHAR(100) NOT NULL);
IF OBJECT_ID('dbo.Itens_Pedidos', 'U') IS NULL
    CREATE TABLE Itens_Pedidos (id_itens_pedidos INT IDENTITY(1,1) PRIMARY KEY, pedidoid INT NOT NULL REFERENCES Pedidos(id_pedido), produtoid INT NOT NULL REFERENCES Produtos(id_produto), quantidade INT NOT NULL, preco_unitario DECIMAL(10,2) NOT NULL);
IF OBJECT_ID('dbo.Pagamentos', 'U') IS NULL
    CREATE TABLE Pagamentos (id_pagamento INT IDENTITY(1,1) PRIMARY KEY, pedidoid INT NOT NULL REFERENCES Pedidos(id_pedido), forma_pagamento VARCHAR(100) NOT NULL, valor_total DECIMAL(10,2) NOT NULL);

IF NOT EXISTS (SELECT 1 FROM Funcionarios)
    INSERT INTO Funcionarios (nome_funcionario, cargo) VALUES ('Sarah Lopes', 'Dona'), ('Jean Reis', 'Caixa'), ('Julia Lopes', 'Garconete');
IF NOT EXISTS (SELECT 1 FROM Clientes)
    INSERT INTO Clientes (nome_cliente, email, telefone) VALUES ('Cliente demonstracao', 'cliente@infinitecoffee.com', '(00) 00000-0000');
IF NOT EXISTS (SELECT 1 FROM Mesas)
    INSERT INTO Mesas (numero, capacidade, status_mesa) VALUES (1, 4, 'Disponivel'), (2, 4, 'Disponivel'), (3, 6, 'Disponivel');

IF OBJECT_ID('dbo.sp_ListarClientes', 'P') IS NULL
    EXEC('CREATE PROCEDURE sp_ListarClientes AS SELECT id_cliente, nome_cliente, email, telefone FROM Clientes');
IF OBJECT_ID('dbo.sp_BuscarCliente', 'P') IS NULL
    EXEC('CREATE PROCEDURE sp_BuscarCliente @valor VARCHAR(100) AS SELECT id_cliente, nome_cliente, email, telefone FROM Clientes WHERE nome_cliente LIKE ''%'' + @valor + ''%'' OR email LIKE ''%'' + @valor + ''%''');
IF OBJECT_ID('dbo.sp_CadastrarCliente', 'P') IS NULL
    EXEC('CREATE PROCEDURE sp_CadastrarCliente @nome VARCHAR(100), @email VARCHAR(100), @telefone VARCHAR(20) AS INSERT INTO Clientes (nome_cliente, email, telefone) VALUES (@nome, @email, @telefone)');
IF OBJECT_ID('dbo.sp_ListarFuncionarios', 'P') IS NULL
    EXEC('CREATE PROCEDURE sp_ListarFuncionarios AS SELECT id_funcionario, nome_funcionario, cargo FROM Funcionarios');
IF OBJECT_ID('dbo.sp_ListarMesas', 'P') IS NULL
    EXEC('CREATE PROCEDURE sp_ListarMesas AS SELECT id_mesa, numero, capacidade, status_mesa FROM Mesas');
IF OBJECT_ID('dbo.sp_ListarMesasLivres', 'P') IS NULL
    EXEC('CREATE PROCEDURE sp_ListarMesasLivres AS SELECT id_mesa, numero, capacidade, status_mesa FROM Mesas WHERE status_mesa IN (''Livre'', ''Disponivel'')');
IF OBJECT_ID('dbo.sp_AtualizarStatusMesa', 'P') IS NULL
    EXEC('CREATE PROCEDURE sp_AtualizarStatusMesa @id INT, @status VARCHAR(60) AS UPDATE Mesas SET status_mesa = @status WHERE id_mesa = @id');
IF OBJECT_ID('dbo.sp_ListarPedidosAbertos', 'P') IS NULL
    EXEC('CREATE PROCEDURE sp_ListarPedidosAbertos AS SELECT id_pedido, mesaid, funcionarioid, clienteid, datahora, status_pedido FROM Pedidos WHERE status_pedido = ''Aberto''');
IF OBJECT_ID('dbo.sp_PedidosDoDia', 'P') IS NULL
    EXEC('CREATE PROCEDURE sp_PedidosDoDia AS SELECT id_pedido, mesaid, funcionarioid, clienteid, datahora, status_pedido FROM Pedidos WHERE CAST(datahora AS DATE) = CAST(GETDATE() AS DATE)');
IF OBJECT_ID('dbo.sp_ProdutosMaisVendidos', 'P') IS NULL
    EXEC('CREATE PROCEDURE sp_ProdutosMaisVendidos AS SELECT p.nome_produto, SUM(i.quantidade) AS total_vendido FROM Itens_Pedidos i JOIN Produtos p ON i.produtoid = p.id_produto GROUP BY p.nome_produto ORDER BY total_vendido DESC');
IF OBJECT_ID('dbo.sp_HistoricoCliente', 'P') IS NULL
    EXEC('CREATE PROCEDURE sp_HistoricoCliente @clienteId INT AS SELECT id_pedido, mesaid, funcionarioid, clienteid, datahora, status_pedido FROM Pedidos WHERE clienteid = @clienteId');
IF OBJECT_ID('dbo.sp_Faturamento', 'P') IS NULL
    EXEC('CREATE PROCEDURE sp_Faturamento AS SELECT ISNULL(SUM(valor_total), 0) AS faturamento_total FROM Pagamentos');

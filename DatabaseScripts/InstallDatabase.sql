-- Instalacao inicial idempotente do banco.
-- Nao remove dados existentes.
IF DB_ID(N'infiniteCoffee') IS NULL
    CREATE DATABASE infiniteCoffee;
GO
USE infiniteCoffee;
GO
IF OBJECT_ID('dbo.Produtos', 'U') IS NULL
    CREATE TABLE Produtos (id_produto INT IDENTITY(1,1) PRIMARY KEY, nome_produto VARCHAR(100) NOT NULL, preco DECIMAL(10,2) NOT NULL, tipo VARCHAR(50) NOT NULL, quantidade_estoque INT NOT NULL DEFAULT 0, codigo_barras VARCHAR(50) NULL, descricao VARCHAR(500) NULL, ativo BIT NOT NULL DEFAULT 1, modified_at DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME());
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
IF OBJECT_ID('dbo.MovimentacoesEstoque', 'U') IS NULL
    CREATE TABLE MovimentacoesEstoque (id_movimentacao INT IDENTITY(1,1) PRIMARY KEY, produtoid INT NOT NULL REFERENCES Produtos(id_produto), tipo_movimentacao VARCHAR(20) NOT NULL, quantidade INT NOT NULL, motivo VARCHAR(200) NOT NULL, data_movimentacao DATETIME NOT NULL, modified_at DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME());
IF OBJECT_ID('dbo.SyncOperations', 'U') IS NULL
    CREATE TABLE SyncOperations (client_uuid VARCHAR(100) NOT NULL PRIMARY KEY, tipo VARCHAR(30) NOT NULL, created_at DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME());

IF NOT EXISTS (SELECT 1 FROM Funcionarios) INSERT INTO Funcionarios (nome_funcionario, cargo) VALUES ('Sarah Lopes', 'Dona'), ('Jean Reis', 'Caixa'), ('Julia Lopes', 'Garconete');
IF NOT EXISTS (SELECT 1 FROM Clientes) INSERT INTO Clientes (nome_cliente, email, telefone) VALUES ('Cliente demonstracao', 'cliente@infinitecoffee.com', '(00) 00000-0000');
IF NOT EXISTS (SELECT 1 FROM Mesas) INSERT INTO Mesas (numero, capacidade, status_mesa) VALUES (1, 4, 'Disponivel'), (2, 4, 'Disponivel'), (3, 6, 'Disponivel');
IF NOT EXISTS (SELECT 1 FROM Produtos) INSERT INTO Produtos (nome_produto, preco, tipo, quantidade_estoque) VALUES ('Cafe Expresso', 6.00, 'Bebida', 20), ('Cafe com Leite', 8.00, 'Bebida', 20), ('Pao de Queijo', 5.00, 'Prato', 30);
GO

CREATE OR ALTER PROCEDURE sp_ListarClientes AS SELECT * FROM Clientes;
GO
CREATE OR ALTER PROCEDURE sp_BuscarCliente @valor VARCHAR(100) AS SELECT * FROM Clientes WHERE nome_cliente LIKE '%' + @valor + '%' OR email LIKE '%' + @valor + '%';
GO
CREATE OR ALTER PROCEDURE sp_CadastrarCliente @nome VARCHAR(100), @email VARCHAR(100), @telefone VARCHAR(20) AS INSERT INTO Clientes (nome_cliente, email, telefone) VALUES (@nome, @email, @telefone);
GO
CREATE OR ALTER PROCEDURE sp_AtualizarCliente @id INT, @nome VARCHAR(100), @email VARCHAR(100), @telefone VARCHAR(20) AS UPDATE Clientes SET nome_cliente=@nome, email=@email, telefone=@telefone WHERE id_cliente=@id;
GO
CREATE OR ALTER PROCEDURE sp_ListarFuncionarios AS SELECT * FROM Funcionarios;
GO
CREATE OR ALTER PROCEDURE sp_ListarMesas AS SELECT * FROM Mesas;
GO
CREATE OR ALTER PROCEDURE sp_ListarMesasLivres AS SELECT * FROM Mesas WHERE status_mesa IN ('Livre', 'Disponivel');
GO
CREATE OR ALTER PROCEDURE sp_AtualizarStatusMesa @id INT, @status VARCHAR(60) AS UPDATE Mesas SET status_mesa=@status WHERE id_mesa=@id;
GO
CREATE OR ALTER PROCEDURE sp_CriarPedido @mesaId INT, @funcionarioId INT, @clienteId INT AS INSERT INTO Pedidos (mesaid, funcionarioid, clienteid, datahora, status_pedido) VALUES (@mesaId,@funcionarioId,@clienteId,GETDATE(),'Aberto'); SELECT SCOPE_IDENTITY() AS id_pedido;
GO
CREATE OR ALTER PROCEDURE sp_AdicionarItemPedido @pedidoId INT, @produtoId INT, @quantidade INT AS INSERT INTO Itens_Pedidos (pedidoid, produtoid, quantidade, preco_unitario) SELECT @pedidoId,@produtoId,@quantidade,preco FROM Produtos WHERE id_produto=@produtoId;
GO
CREATE OR ALTER PROCEDURE sp_CalcularTotalPedido @pedidoId INT AS SELECT SUM(quantidade * preco_unitario) AS total FROM Itens_Pedidos WHERE pedidoid=@pedidoId;
GO
CREATE OR ALTER PROCEDURE sp_RegistrarPagamento @pedidoId INT, @forma VARCHAR(50), @valor DECIMAL(10,2) AS INSERT INTO Pagamentos (pedidoid, forma_pagamento, valor_total) VALUES (@pedidoId,@forma,@valor);
GO
CREATE OR ALTER PROCEDURE sp_FinalizarPedido @pedidoId INT AS UPDATE Pedidos SET status_pedido='Finalizado' WHERE id_pedido=@pedidoId;
GO
CREATE OR ALTER PROCEDURE sp_ListarPedidosAbertos AS SELECT * FROM Pedidos WHERE status_pedido='Aberto';
GO
CREATE OR ALTER PROCEDURE sp_PedidosDoDia AS SELECT * FROM Pedidos WHERE CAST(datahora AS DATE)=CAST(GETDATE() AS DATE);
GO
CREATE OR ALTER PROCEDURE sp_ProdutosMaisVendidos AS SELECT p.nome_produto,SUM(i.quantidade) AS total_vendido FROM Itens_Pedidos i JOIN Produtos p ON i.produtoid=p.id_produto GROUP BY p.nome_produto ORDER BY total_vendido DESC;
GO
CREATE OR ALTER PROCEDURE sp_HistoricoCliente @clienteId INT AS SELECT * FROM Pedidos WHERE clienteid=@clienteId;
GO
CREATE OR ALTER PROCEDURE sp_Faturamento AS SELECT ISNULL(SUM(valor_total),0) AS faturamento_total FROM Pagamentos;
GO
CREATE OR ALTER PROCEDURE sp_AtualizarProduto @id INT, @nome VARCHAR(100), @preco DECIMAL(10,2), @tipo VARCHAR(50) AS UPDATE Produtos SET nome_produto=@nome, preco=@preco, tipo=@tipo, modified_at=SYSUTCDATETIME() WHERE id_produto=@id;
GO

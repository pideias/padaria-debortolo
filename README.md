## Guia rapido

Para entender o projeto completo, os contratos da API, o fluxo Flutter/Hive, o sync e as regras
para outras IAs, leia primeiro [`DOCUMENTACAO-IA.md`](DOCUMENTACAO-IA.md) e [`AGENTS.md`](AGENTS.md).

O backend usa SQL Server; o app Flutter usa Hive como espelho offline. Windows, Android e Web
usam o mesmo codigo Flutter e conversam com o servidor pela API REST.

Para o codigo funcionar precisa criar e conectar o banco de dados primeiro, a seguir estão os comandos do banco de dados;
Os incertes que eu coloquei são apenas para testar, voce pode adicionar os incertes direto pelo programa em C#.

## Requisitos para executar

- .NET 10 SDK instalado.
- SQL Server em execução com o banco `infiniteCoffee` criado.
- SQL Server configurado por `PADARIA_CONNECTION_STRING` ou pela conexão padrão local.

Para restaurar, compilar e iniciar:

```powershell
dotnet restore InfiniteCoffee2.slnx
dotnet build InfiniteCoffee2.slnx --no-restore
dotnet run --project InfiniteCoffee2/InfiniteCoffee2.csproj
```


## Conexao do banco

O projeto usa `localhost` como padrao para a instancia local do SQL Server. Cada colaborador
que usa outro servidor ou instancia deve configurar a propria variavel de ambiente, sem alterar
o arquivo versionado:

```powershell
$env:PADARIA_CONNECTION_STRING="Server=SEU_SERVIDOR;Database=infiniteCoffee;Trusted_Connection=True;TrustServerCertificate=True;"
dotnet run --project InfiniteCoffee2/InfiniteCoffee2.csproj
```

Exemplo para uma instancia nomeada:

```powershell
$env:PADARIA_CONNECTION_STRING="Server=localhost\KAIO;Database=infiniteCoffee;Trusted_Connection=True;TrustServerCertificate=True;"
```

O `Program.cs` prioriza `PADARIA_CONNECTION_STRING` e usa `ConnectionStrings:DefaultConnection`
apenas quando a variavel nao estiver definida.

------ Esse é o banco de dados ------

create database infiniteCoffee

create table Clientes(
id_cliente int identity(1,1) primary key,
nome_cliente varchar (100) not null,
email varchar (100),
telefone varchar (20))

create table Funcionarios(
id_funcionario int identity(1,1) primary key,
nome_funcionario varchar (100) not null,
cargo varchar (100) not null)

create table Produtos(
id_produto int identity(1,1) primary key,
nome_produto varchar (100) not null,
preco decimal not null,
tipo varchar(16) not null)

create table Mesas(
id_mesa int identity(1,1) primary key,
numero int not null,
capacidade int not null,
status_mesa varchar (60) not null)

create table Pedidos(
id_pedido int identity(1,1) primary key,
mesaid int foreign key references Mesas(id_mesa),
funcionarioid int foreign key references Funcionarios(id_funcionario),
clienteid int foreign key references Clientes(id_cliente),
datahora datetime not null,
status_pedido varchar (100) not null)

create table Itens_Pedidos(
id_itens_pedidos int identity(1,1) primary key,
pedidoid int foreign key references Pedidos(id_pedido),
produtoid int foreign key references Produtos(id_produto),
quantidade int not null,
preco_unitario decimal not null)

create table Pagamentos(
id_pagamento int identity(1,1) primary key,
pedidoid int foreign key references Pedidos(id_pedido),
forma_pagamento varchar (100) not null,
valor_total decimal not null)


------ Essas são as Procedure ------

-- Clientes

GO
CREATE PROCEDURE sp_ListarClientes
AS
BEGIN
    SELECT * FROM Clientes
END
GO

CREATE PROCEDURE sp_BuscarCliente
    @valor VARCHAR(100)
AS
BEGIN
    SELECT * FROM Clientes
    WHERE nome_cliente LIKE '%' + @valor + '%'
       OR email LIKE '%' + @valor + '%'
END
GO

CREATE PROCEDURE sp_CadastrarCliente
    @nome VARCHAR(100),
    @email VARCHAR(100),
    @telefone VARCHAR(20)
AS
BEGIN
    INSERT INTO Clientes (nome_cliente, email, telefone)
    VALUES (@nome, @email, @telefone)
END
GO

CREATE PROCEDURE sp_AtualizarCliente
    @id INT,
    @nome VARCHAR(100),
    @email VARCHAR(100),
    @telefone VARCHAR(20)
AS
BEGIN
    UPDATE Clientes
    SET nome_cliente = @nome,
        email = @email,
        telefone = @telefone
    WHERE id_cliente = @id
END
GO

CREATE PROCEDURE sp_ExcluirCliente
    @id INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Remove os dados dependentes antes do cliente para respeitar as foreign keys.
        DELETE FROM Pagamentos
        WHERE pedidoid IN (SELECT id_pedido FROM Pedidos WHERE clienteid = @id);

        DELETE FROM Itens_Pedidos
        WHERE pedidoid IN (SELECT id_pedido FROM Pedidos WHERE clienteid = @id);

        DELETE FROM Pedidos WHERE clienteid = @id;
        DELETE FROM Clientes WHERE id_cliente = @id;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO


-- Produtos

GO
CREATE PROCEDURE sp_ListarProdutos
AS
BEGIN
    SELECT * FROM Produtos
END
GO

CREATE PROCEDURE sp_CadastrarProduto
    @nome VARCHAR(100),
    @preco DECIMAL(10,2),
    @tipo VARCHAR(50)
AS
BEGIN
    INSERT INTO Produtos (nome_produto, preco, tipo)
    VALUES (@nome, @preco, @tipo)
END
GO


-- Mesas

GO
CREATE PROCEDURE sp_ListarMesas
AS
BEGIN
    SELECT * FROM Mesas
END
GO

CREATE PROCEDURE sp_ListarMesasLivres
AS
BEGIN
    SELECT * FROM Mesas WHERE status_mesa = 'Livre'
END
GO

CREATE PROCEDURE sp_AtualizarStatusMesa
    @id INT,
    @status VARCHAR(60)
AS
BEGIN
    UPDATE Mesas
    SET status_mesa = @status
    WHERE id_mesa = @id
END
GO


-- Pedidos

GO
CREATE PROCEDURE sp_CriarPedido
    @mesaId INT,
    @funcionarioId INT,
    @clienteId INT
AS
BEGIN
    INSERT INTO Pedidos (mesaid, funcionarioid, clienteid, datahora, status_pedido)
    VALUES (@mesaId, @funcionarioId, @clienteId, GETDATE(), 'Aberto')
    SELECT SCOPE_IDENTITY() AS id_pedido
END
GO

CREATE PROCEDURE sp_AdicionarItemPedido
    @pedidoId INT,
    @produtoId INT,
    @quantidade INT
AS
BEGIN
    DECLARE @preco DECIMAL(10,2)
    SELECT @preco = preco FROM Produtos WHERE id_produto = @produtoId
    INSERT INTO Itens_Pedidos (pedidoid, produtoid, quantidade, preco_unitario)
    VALUES (@pedidoId, @produtoId, @quantidade, @preco)
END
GO

CREATE PROCEDURE sp_CalcularTotalPedido
    @pedidoId INT
AS
BEGIN
    SELECT SUM(quantidade * preco_unitario) AS total
    FROM Itens_Pedidos
    WHERE pedidoid = @pedidoId
END
GO

CREATE PROCEDURE sp_FinalizarPedido
    @pedidoId INT
AS
BEGIN
    UPDATE Pedidos
    SET status_pedido = 'Finalizado'
    WHERE id_pedido = @pedidoId
END
GO

CREATE PROCEDURE sp_ListarPedidosAbertos
AS
BEGIN
    SELECT * FROM Pedidos WHERE status_pedido = 'Aberto'
END
GO

CREATE PROCEDURE sp_FecharPedido
    @pedidoId INT
AS
BEGIN
    UPDATE Pedidos
    SET status_pedido = 'Finalizado'
    WHERE id_pedido = @pedidoId
END
GO


-- Pagamentos

GO
CREATE PROCEDURE sp_RegistrarPagamento
    @pedidoId INT,
    @forma VARCHAR(50),
    @valor DECIMAL(10,2)
AS
BEGIN
    INSERT INTO Pagamentos (pedidoid, forma_pagamento, valor_total)
    VALUES (@pedidoId, @forma, @valor)
END
GO


-- Relatorios

GO
CREATE PROCEDURE sp_PedidosDoDia
AS
BEGIN
    SELECT * FROM Pedidos
    WHERE CAST(datahora AS DATE) = CAST(GETDATE() AS DATE)
END
GO

CREATE PROCEDURE sp_ProdutosMaisVendidos
AS
BEGIN
    SELECT p.nome_produto, SUM(i.quantidade) AS total_vendido
    FROM Itens_Pedidos i
    JOIN Produtos p ON i.produtoid = p.id_produto
    GROUP BY p.nome_produto
    ORDER BY total_vendido DESC
END
GO

CREATE PROCEDURE sp_HistoricoCliente
    @clienteId INT
AS
BEGIN
    SELECT * FROM Pedidos
    WHERE clienteid = @clienteId
END
GO

CREATE PROCEDURE sp_Faturamento
AS
BEGIN
    SELECT SUM(valor_total) AS faturamento_total
    FROM Pagamentos
END
GO


-- Extra

CREATE PROCEDURE sp_AtualizarProduto
    @id INT,
    @nome VARCHAR(100),
    @preco DECIMAL(10,2),
    @tipo VARCHAR(50)
AS
BEGIN
    UPDATE Produtos
    SET nome_produto = @nome,
        preco = @preco,
        tipo = @tipo
    WHERE id_produto = @id
END
GO

CREATE PROCEDURE sp_ExcluirProduto
    @id INT
AS
BEGIN
    DELETE FROM Produtos WHERE id_produto = @id
END
GO

CREATE PROCEDURE sp_ListarFuncionarios
AS
BEGIN
    SELECT id_funcionario, nome_funcionario, cargo
    FROM Funcionarios;
END


------ Esses são alguns incertes ------

USE infiniteCoffee;


-- FUNCIONARIOS

INSERT INTO Funcionarios (nome_funcionario, cargo) VALUES
('Sarah Lopes',     'Dona'),
('Jean Reis',       'Caixa'),
('Júlia Lopes',     'Garçonete'),
('Luana Carvalho',  'Cozinheira'),
('Yuri Leite',      'Garçom'),
('Pedro Teki',      'Cozinheiro'),
('Lucas Pollar',    'Cozinheiro'),
('Rayssa Yuki',     'Garçonete');


-- CLIENTES

INSERT INTO Clientes (nome_cliente, email, telefone) VALUES
('Ana Clara Mendes',     'anaclara.mendes@gmail.com',       '(11) 98234-5678'),
('Bruno Tavares',        'brunotavares@hotmail.com',         '(21) 97654-3210'),
('Camila Ferreira',      'camilaferreira@outlook.com',       '(11) 91234-8766'),
('Diego Almeida',        'diego.almeida@gmail.com',          '(31) 99876-5432'),
('Fernanda Costa',       'fernandacosta@yahoo.com.br',       '(11) 94567-8902'),
('Gabriel Monteiro',     'gabriel.monteiro@gmail.com',       '(41) 98765-4322'),
('Helena Vieira',        'helenavieira@gmail.com',           '(11) 93456-7890'),
('Igor Santos',          'igor.santos@outlook.com',          '(21) 96543-2108'),
('Juliana Ramos',        'juliana.ramos@gmail.com',          '(11) 95678-1234'),
('Leonardo Carvalho',    'leo.carvalho@hotmail.com',         '(31) 98902-2346'),
('Mariana Pinto',        'mariana.pinto@gmail.com',          '(11) 97890-3456'),
('Nicolas Barbosa',      'nicolas.barbosa@gmail.com',        '(21) 94322-6790'),
('Olivia Nascimento',    'olivia.nascimento@outlook.com',    '(11) 92108-8764'),
('Paulo Ribeiro',        'paulo.ribeiro@gmail.com',          '(41) 96790-0124'),
('Rafaela Lima',         'rafaela.lima@yahoo.com.br',        '(11) 93212-4568'),
('Samuel Oliveira',      'samuel.oliveira@gmail.com',        '(11) 98766-6790'),
('Tatiana Gomes',        'tatiana.gomes@hotmail.com',        '(21) 97656-1236'),
('Vinícius Souza',       'vinicius.souza@gmail.com',         '(11) 96544-8902'),
('Yasmin Azevedo',       'yasmin.azevedo@outlook.com',       '(31) 95434-7892'),
('Rodrigo Figueiredo',   'rodrigo.fig@gmail.com',            '(11) 94322-2346');


-- PRODUTOS

INSERT INTO Produtos (nome_produto, preco, tipo) VALUES
-- Bebidas
('Café Expresso',                6.00,  'Bebida'),
('Café com Leite',               8.00,  'Bebida'),
('Cappuccino',                  12.00,  'Bebida'),
('Chocolate Quente',            10.00,  'Bebida'),
('Chá de Camomila',              8.00,  'Bebida'),
('Suco de Laranja',              9.00,  'Bebida'),
('Limonada Suíça',              12.00,  'Bebida'),
('Água com Gás',                 5.00,  'Bebida'),
-- Doces / Encontro
('Waffle com Nutella',          18.00,  'Prato'),
('Crepe de Morango',            16.00,  'Prato'),
('Torta de Limão (fatia)',      12.00,  'Prato'),
('Cheesecake de Frutas Vermelhas', 14.00, 'Prato'),
('Brownie com Sorvete',         16.00,  'Prato'),
('Croissant de Chocolate',      10.00,  'Prato'),
-- Massas
('Fettuccine ao Molho Funghi',  36.00,  'Prato'),
('Penne à Carbonara',           34.00,  'Prato'),
('Ravioli de Ricota',           38.00,  'Prato'),
-- Salgados
('Coxinha de Frango',            7.00,  'Prato'),
('Pão de Queijo',                5.00,  'Prato'),
('Quiche de Espinafre',         14.00,  'Prato'),
('Mini Sanduíche de Peito de Peru', 16.00, 'Prato'),
('Torta Salgada de Frango (fatia)', 13.00, 'Prato');


-- MESAS (16 mesas, capacidades pares)

INSERT INTO Mesas (numero, capacidade, status_mesa) VALUES
(1,  4, 'Disponível'),
(2,  4, 'Disponível'),
(3,  4, 'Disponível'),
(4,  4, 'Disponível'),
(5,  6, 'Disponível'),
(6,  6, 'Disponível'),
(7,  6, 'Disponível'),
(8,  6, 'Disponível'),
(9,  6, 'Disponível'),
(10, 6, 'Disponível'),
(11, 8, 'Ocupada'),
(12, 8, 'Disponível'),
(13, 8, 'Disponível'),
(14, 8, 'Disponível'),
(15, 4, 'Reservada'),
(16, 4, 'Disponível');


-- PEDIDOS
-- funcionario: 3=Júlia, 5=Yuri, 8=Rayssa

SET DATEFORMAT YMD;

INSERT INTO Pedidos (mesaid, funcionarioid, clienteid, datahora, status_pedido) VALUES
(1, 1, 1, '2020-01-10T08:15:00', 'Finalizado'),
(2, 2, 2, '2020-03-22T14:30:00', 'Finalizado'),
(3, 3, 3, '2020-07-05T19:45:00', 'Finalizado'),

(4, 1, 4, '2021-02-14T12:00:00', 'Finalizado'),
(5, 2, 5, '2021-06-18T18:20:00', 'Finalizado'),
(1, 3, 1, '2021-11-30T09:10:00', 'Finalizado'),

(2, 4, 2, '2022-04-12T15:00:00', 'Finalizado'),
(3, 1, 3, '2022-08-25T20:30:00', 'Finalizado'),
(4, 2, 4, '2022-12-31T23:50:00', 'Finalizado'),

(5, 3, 5, '2023-03-08T13:25:00', 'Finalizado'),
(1, 4, 1, '2023-07-19T17:40:00', 'Finalizado'),
(2, 1, 2, '2023-10-10T10:05:00', 'Finalizado'),

(3, 2, 3, '2024-01-01T00:15:00', 'Finalizado'),
(4, 3, 4, '2024-05-27T16:55:00', 'Finalizado'),
(5, 4, 5, '2024-09-09T21:10:00', 'Finalizado');


-- ITENS_PEDIDOS

INSERT INTO Itens_Pedidos (pedidoid, produtoid, quantidade, preco_unitario) VALUES
(1, 1, 2, 5.50),
(1, 4, 1, 6.00),
(2, 2, 1, 8.00),
(2, 5, 2, 9.00),
(3, 3, 1, 7.50),
(4, 6, 2, 7.00),
(5, 1, 1, 5.50),
(6, 2, 2, 8.00),
(7, 4, 1, 6.00),
(8, 5, 1, 9.00),
(9, 3, 2, 7.50),
(10, 6, 1, 7.00),
(11, 1, 3, 5.50),
(12, 2, 1, 8.00),
(13, 3, 1, 7.50),
(14, 4, 2, 6.00),
(15, 5, 1, 9.00);

INSERT INTO Pagamentos (pedidoid, forma_pagamento, valor_total) VALUES
(1, 'Cartão', 17.00),
(2, 'Pix', 26.00),
(3, 'Dinheiro', 7.50),
(4, 'Cartão', 14.00),
(5, 'Pix', 5.50),
(6, 'Dinheiro', 16.00),
(7, 'Cartão', 6.00),
(8, 'Pix', 9.00),
(9, 'Dinheiro', 15.00),
(10, 'Cartão', 7.00),
(11, 'Pix', 16.50),
(12, 'Dinheiro', 8.00),
(13, 'Cartão', 7.50),
(14, 'Pix', 12.00),
(15, 'Dinheiro', 9.00);


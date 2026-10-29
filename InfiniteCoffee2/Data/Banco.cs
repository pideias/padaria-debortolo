using System.Data;
using Microsoft.Data.SqlClient;
using InfiniteCoffee2.Models;

namespace InfiniteCoffee2.Data
{
    public class Banco
    {
        private static string connectionString = string.Empty;

        public static void Configurar(string? valor)
        {
            if (string.IsNullOrWhiteSpace(valor))
                throw new InvalidOperationException("A connection string do banco não foi configurada.");
            connectionString = valor;
        }

        // =========================
        // CLIENTES
        // =========================

        public static List<Dictionary<string, object>> ListarClientes()
        {
            var lista = new List<Dictionary<string, object>>();
            using (var conn = new SqlConnection(connectionString))
            {
                conn.Open();
                var cmd = new SqlCommand("sp_ListarClientes", conn) { CommandType = CommandType.StoredProcedure };
                var reader = cmd.ExecuteReader();
                while (reader.Read())
                    lista.Add(new Dictionary<string, object>
                    {
                        ["id_cliente"] = reader["id_cliente"],
                        ["nome_cliente"] = reader["nome_cliente"],
                        ["email"] = reader["email"],
                        ["telefone"] = reader["telefone"]
                    });
            }
            return lista;
        }

        public static List<Dictionary<string, object>> BuscarCliente(string valor)
        {
            var lista = new List<Dictionary<string, object>>();
            using (var conn = new SqlConnection(connectionString))
            {
                conn.Open();
                var cmd = new SqlCommand("sp_BuscarCliente", conn) { CommandType = CommandType.StoredProcedure };
                cmd.Parameters.AddWithValue("@valor", valor);
                var reader = cmd.ExecuteReader();
                while (reader.Read())
                    lista.Add(new Dictionary<string, object>
                    {
                        ["id_cliente"] = reader["id_cliente"],
                        ["nome_cliente"] = reader["nome_cliente"],
                        ["email"] = reader["email"],
                        ["telefone"] = reader["telefone"]
                    });
            }
            return lista;
        }

        public static Dictionary<string, object>? BuscarClientePorNomeEmail(string nome, string email)
        {
            using var conn = new SqlConnection(connectionString);
            conn.Open();
            using var cmd = new SqlCommand(@"
                SELECT TOP 1 id_cliente, nome_cliente, email, telefone
                FROM Clientes
                WHERE LOWER(LTRIM(RTRIM(nome_cliente))) = LOWER(@nome)
                  AND LOWER(LTRIM(RTRIM(email))) = LOWER(@email)
                  AND ativo = 1", conn);
            cmd.Parameters.AddWithValue("@nome", nome.Trim());
            cmd.Parameters.AddWithValue("@email", email.Trim());
            using var reader = cmd.ExecuteReader();
            if (!reader.Read()) return null;

            return new Dictionary<string, object>
            {
                ["id_cliente"] = reader["id_cliente"],
                ["nome_cliente"] = reader["nome_cliente"],
                ["email"] = reader["email"],
                ["telefone"] = reader["telefone"]
            };
        }

        public static Dictionary<string, object>? BuscarClientePorId(int id)
        {
            using var conn = new SqlConnection(connectionString);
            conn.Open();
            using var cmd = new SqlCommand("SELECT TOP 1 id_cliente, nome_cliente, email, telefone FROM Clientes WHERE id_cliente = @id AND ativo = 1", conn);
            cmd.Parameters.AddWithValue("@id", id);
            using var reader = cmd.ExecuteReader();
            if (!reader.Read()) return null;

            return new Dictionary<string, object>
            {
                ["id_cliente"] = reader["id_cliente"],
                ["nome_cliente"] = reader["nome_cliente"],
                ["email"] = reader["email"],
                ["telefone"] = reader["telefone"]
            };
        }

        public static void CadastrarCliente(string nome, string email, string telefone)
        {
            using (var conn = new SqlConnection(connectionString))
            {
                conn.Open();
                var cmd = new SqlCommand("sp_CadastrarCliente", conn) { CommandType = CommandType.StoredProcedure };
                cmd.Parameters.AddWithValue("@nome", nome);
                cmd.Parameters.AddWithValue("@email", email);
                cmd.Parameters.AddWithValue("@telefone", telefone);
                cmd.ExecuteNonQuery();
            }
        }

        public static void AtualizarCliente(int id, string nome, string email, string telefone)
        {
            using (var conn = new SqlConnection(connectionString))
            {
                conn.Open();
                var cmd = new SqlCommand("sp_AtualizarCliente", conn) { CommandType = CommandType.StoredProcedure };
                cmd.Parameters.AddWithValue("@id", id);
                cmd.Parameters.AddWithValue("@nome", nome);
                cmd.Parameters.AddWithValue("@email", email);
                cmd.Parameters.AddWithValue("@telefone", telefone);
                cmd.ExecuteNonQuery();
            }
        }

        public static void ExcluirCliente(int id)
        {
            using (var conn = new SqlConnection(connectionString))
            {
                conn.Open();
                var cmd = new SqlCommand("UPDATE Clientes SET ativo = 0 WHERE id_cliente = @id AND ativo = 1", conn);
                cmd.Parameters.AddWithValue("@id", id);
                cmd.ExecuteNonQuery();
            }
        }

        public static List<Dictionary<string, object>> ListarClientesCadastro(bool incluirInativos)
        {
            var lista = new List<Dictionary<string, object>>();
            using var conn = new SqlConnection(connectionString);
            conn.Open();
            using var cmd = new SqlCommand(@"
                SELECT id_cliente, nome_cliente, email, ativo
                FROM Clientes
                WHERE @incluirInativos = 1 OR ativo = 1
                ORDER BY nome_cliente", conn);
            cmd.Parameters.AddWithValue("@incluirInativos", incluirInativos);
            using var reader = cmd.ExecuteReader();
            while (reader.Read())
                lista.Add(new Dictionary<string, object>
                {
                    ["id_cliente"] = reader["id_cliente"],
                    ["nome_cliente"] = reader["nome_cliente"],
                    ["email"] = reader["email"] is DBNull ? string.Empty : reader["email"],
                    ["ativo"] = reader["ativo"]
                });
            return lista;
        }

        public static int CadastrarClienteCadastro(string nome, string email)
        {
            using var conn = new SqlConnection(connectionString);
            conn.Open();
            using var cmd = new SqlCommand(@"
                INSERT INTO Clientes (nome_cliente, email, telefone, ativo)
                OUTPUT INSERTED.id_cliente
                VALUES (@nome, @email, '', 1)", conn);
            cmd.Parameters.AddWithValue("@nome", nome);
            cmd.Parameters.AddWithValue("@email", string.IsNullOrWhiteSpace(email) ? DBNull.Value : email);
            return Convert.ToInt32(cmd.ExecuteScalar());
        }

        public static bool AtualizarClienteCadastro(int id, string nome, string email)
        {
            using var conn = new SqlConnection(connectionString);
            conn.Open();
            using var cmd = new SqlCommand(@"
                UPDATE Clientes SET nome_cliente = @nome, email = @email
                WHERE id_cliente = @id AND ativo = 1", conn);
            cmd.Parameters.AddWithValue("@id", id);
            cmd.Parameters.AddWithValue("@nome", nome);
            cmd.Parameters.AddWithValue("@email", string.IsNullOrWhiteSpace(email) ? DBNull.Value : email);
            return cmd.ExecuteNonQuery() > 0;
        }

        public static bool DefinirClienteAtivo(int id, bool ativo)
        {
            using var conn = new SqlConnection(connectionString);
            conn.Open();
            using var cmd = new SqlCommand("UPDATE Clientes SET ativo = @ativo WHERE id_cliente = @id AND ativo <> @ativo", conn);
            cmd.Parameters.AddWithValue("@id", id);
            cmd.Parameters.AddWithValue("@ativo", ativo);
            return cmd.ExecuteNonQuery() > 0;
        }

        // =========================
        // PRODUTOS
        // =========================

        public static List<Dictionary<string, object>> ListarProdutos()
        {
            GarantirEstruturaEstoque();
            var lista = new List<Dictionary<string, object>>();
            using (var conn = new SqlConnection(connectionString))
            {
                conn.Open();
                // Consulta direta mantém a tela compatível mesmo antes das procedures opcionais.
                var cmd = new SqlCommand("SELECT id_produto, nome_produto, preco, tipo, quantidade_estoque, codigo_barras, descricao FROM Produtos WHERE ativo = 1 ORDER BY nome_produto", conn);
                var reader = cmd.ExecuteReader();
                while (reader.Read())
                    lista.Add(new Dictionary<string, object>
                    {
                        ["id_produto"] = reader["id_produto"],
                        ["nome_produto"] = reader["nome_produto"],
                        ["preco"] = reader["preco"],
                        ["tipo"] = reader["tipo"],
                        ["quantidade_estoque"] = reader["quantidade_estoque"],
                        ["codigo_barras"] = reader["codigo_barras"],
                        ["descricao"] = reader["descricao"]
                    });
            }
            return lista;
        }

        public static void CadastrarProduto(
            string nome,
            decimal preco,
            string tipo,
            int quantidade,
            string codigoBarras,
            string descricao,
            string motivoEstoqueInicial = "Estoque inicial do produto")
        {
            GarantirEstruturaEstoque();
            using var conn = new SqlConnection(connectionString);
            conn.Open();
            using var transaction = conn.BeginTransaction();
            try
            {
                using var cmd = new SqlCommand(@"
                    INSERT INTO Produtos (nome_produto, preco, tipo, quantidade_estoque, codigo_barras, descricao)
                    OUTPUT INSERTED.id_produto
                    VALUES (@nome, @preco, @tipo, @quantidade, @codigoBarras, @descricao)", conn, transaction);
                cmd.Parameters.AddWithValue("@nome", nome);
                cmd.Parameters.AddWithValue("@preco", preco);
                cmd.Parameters.AddWithValue("@tipo", tipo);
                cmd.Parameters.AddWithValue("@quantidade", quantidade);
                cmd.Parameters.AddWithValue("@codigoBarras", string.IsNullOrWhiteSpace(codigoBarras) ? DBNull.Value : codigoBarras.Trim());
                cmd.Parameters.AddWithValue("@descricao", string.IsNullOrWhiteSpace(descricao) ? DBNull.Value : descricao.Trim());
                var produtoId = Convert.ToInt32(cmd.ExecuteScalar());

                if (quantidade > 0)
                {
                    using var movimentacao = new SqlCommand(@"
                        INSERT INTO MovimentacoesEstoque
                            (produtoid, tipo_movimentacao, quantidade, motivo, data_movimentacao)
                        VALUES (@produtoId, 'Entrada', @quantidade, @motivo, GETDATE())", conn, transaction);
                    movimentacao.Parameters.AddWithValue("@produtoId", produtoId);
                    movimentacao.Parameters.AddWithValue("@quantidade", quantidade);
                    movimentacao.Parameters.AddWithValue("@motivo", string.IsNullOrWhiteSpace(motivoEstoqueInicial)
                        ? "Estoque inicial do produto"
                        : motivoEstoqueInicial.Trim());
                    movimentacao.ExecuteNonQuery();
                }

                transaction.Commit();
            }
            catch
            {
                transaction.Rollback();
                throw;
            }
        }

        public static void AtualizarProduto(int id, string nome, decimal preco, string tipo)
        {
            using (var conn = new SqlConnection(connectionString))
            {
                conn.Open();
                var cmd = new SqlCommand("sp_AtualizarProduto", conn) { CommandType = CommandType.StoredProcedure };
                cmd.Parameters.AddWithValue("@id", id);
                cmd.Parameters.AddWithValue("@nome", nome);
                cmd.Parameters.AddWithValue("@preco", preco);
                cmd.Parameters.AddWithValue("@tipo", tipo);
                cmd.ExecuteNonQuery();
            }
        }

        public static bool AtualizarDadosProduto(int id, string nome, decimal preco, string tipo, string codigoBarras, string descricao)
        {
            GarantirEstruturaEstoque();
            using var conn = new SqlConnection(connectionString);
            conn.Open();
            using var cmd = new SqlCommand(@"
                UPDATE Produtos
                SET nome_produto = @nome, preco = @preco, tipo = @tipo,
                    codigo_barras = @codigoBarras, descricao = @descricao
                WHERE id_produto = @id AND ativo = 1", conn);
            cmd.Parameters.AddWithValue("@id", id);
            cmd.Parameters.AddWithValue("@nome", nome.Trim());
            cmd.Parameters.AddWithValue("@preco", preco);
            cmd.Parameters.AddWithValue("@tipo", tipo.Trim());
            cmd.Parameters.AddWithValue("@codigoBarras", string.IsNullOrWhiteSpace(codigoBarras) ? DBNull.Value : codigoBarras.Trim());
            cmd.Parameters.AddWithValue("@descricao", string.IsNullOrWhiteSpace(descricao) ? DBNull.Value : descricao.Trim());
            return cmd.ExecuteNonQuery() == 1;
        }

        public static bool ExcluirProduto(int id)
        {
            // Produtos podem ser referenciados por Itens_Pedidos. Inativar preserva
            // o historico e remove o item apenas das consultas operacionais.
            GarantirEstruturaSync();
            using var conn = new SqlConnection(connectionString);
            conn.Open();
            using var cmd = new SqlCommand("UPDATE Produtos SET ativo = 0, quantidade_estoque = 0 WHERE id_produto = @id AND ativo = 1", conn);
            cmd.Parameters.AddWithValue("@id", id);
            return cmd.ExecuteNonQuery() == 1;
        }

        // =========================
        // ESTOQUE
        // =========================

        public static List<Dictionary<string, object>> ListarEstoque(string busca = "")
        {
            GarantirTabelaMovimentacoes();
            var lista = new List<Dictionary<string, object>>();
            using var conn = new SqlConnection(connectionString);
            conn.Open();
            using var cmd = new SqlCommand("SELECT id_produto, nome_produto, preco, tipo, quantidade_estoque, codigo_barras, descricao FROM Produtos WHERE ativo = 1 AND (@busca = '' OR nome_produto LIKE '%' + @busca + '%' OR codigo_barras LIKE '%' + @busca + '%') ORDER BY nome_produto", conn);
            cmd.Parameters.AddWithValue("@busca", (busca ?? string.Empty).Trim());
            using var reader = cmd.ExecuteReader();
            while (reader.Read())
                lista.Add(new Dictionary<string, object>
                {
                    ["id_produto"] = reader["id_produto"], ["nome_produto"] = reader["nome_produto"], ["preco"] = reader["preco"],
                    ["tipo"] = reader["tipo"], ["quantidade_estoque"] = reader["quantidade_estoque"],
                    ["codigo_barras"] = reader["codigo_barras"], ["descricao"] = reader["descricao"]
                });
            return lista;
        }

        public static List<Dictionary<string, object>> ListarEstoqueBaixo(int limite = 5)
        {
            return ListarEstoque().Where(item => Convert.ToInt32(item["quantidade_estoque"]) <= limite).ToList();
        }

        public static List<Dictionary<string, object>> ListarMovimentacoesEstoque()
        {
            GarantirTabelaMovimentacoes();
            var lista = new List<Dictionary<string, object>>();
            using var conn = new SqlConnection(connectionString);
            conn.Open();
            using var cmd = new SqlCommand("SELECT m.id_movimentacao, p.nome_produto, m.tipo_movimentacao, m.quantidade, m.motivo, m.data_movimentacao FROM MovimentacoesEstoque m INNER JOIN Produtos p ON p.id_produto = m.produtoid ORDER BY m.id_movimentacao DESC", conn);
            using var reader = cmd.ExecuteReader();
            while (reader.Read())
                lista.Add(new Dictionary<string, object>
                {
                    ["id_movimentacao"] = reader["id_movimentacao"], ["nome_produto"] = reader["nome_produto"], ["tipo_movimentacao"] = reader["tipo_movimentacao"],
                    ["quantidade"] = reader["quantidade"], ["motivo"] = reader["motivo"], ["data_movimentacao"] = reader["data_movimentacao"]
                });
            return lista;
        }

        /// <summary>
        /// Retorna uma impressão digital leve dos dados de estoque/produtos.
        /// Muda sempre que um produto é criado, editado, excluído ou seu saldo se altera.
        /// Usado pelo front para só recarregar a página quando o banco realmente muda.
        /// </summary>
        public static string ObterVersaoEstoque()
        {
            using var conn = new SqlConnection(connectionString);
            conn.Open();
            using var cmd = new SqlCommand(
                "SELECT (SELECT COUNT(*) FROM Produtos) AS produtos, " +
                "(SELECT ISNULL(SUM(CAST(quantidade_estoque AS BIGINT)), 0) FROM Produtos) AS saldo, " +
                "(SELECT ISNULL(MAX(id_movimentacao), 0) FROM MovimentacoesEstoque) AS mov, " +
                "(SELECT ISNULL(SUM(preco), 0) FROM Produtos) AS preco", conn);
            using var reader = cmd.ExecuteReader();
            if (reader.Read())
                return $"{reader["produtos"]}|{reader["saldo"]}|{reader["mov"]}|{Convert.ToDecimal(reader["preco"]):F2}";
            return "0|0|0|0.00";
        }

        /// <summary>
        /// Impressão digital dos produtos (captura qualquer edição de nome, preço, tipo, saldo ou código).
        /// </summary>
        public static string ObterVersaoProdutos()
        {
            using var conn = new SqlConnection(connectionString);
            conn.Open();
            using var cmd = new SqlCommand(
                "SELECT ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(id_produto, nome_produto, preco, tipo, quantidade_estoque, ISNULL(codigo_barras, ''), ISNULL(descricao, ''))), 0) FROM Produtos", conn);
            var valor = cmd.ExecuteScalar();
            return valor?.ToString() ?? "0";
        }

        /// <summary>
        /// Garante as colunas de auditoria (modified_at) e triggers que mantem a "versao"
        /// de cada linha, usadas pelo sync bidirecional com o app Flutter. Idempotente.
        /// </summary>
        public static void GarantirEstruturaSync()
        {
            GarantirEstruturaEstoque();
            using var conn = new SqlConnection(connectionString);
            conn.Open();
            // Estrutura de sync criada sob demanda: banco novo e banco existente
            // recebem a mesma evolucao sem DROP, TRUNCATE ou perda de dados.
            using var cmd = new SqlCommand(@"
                IF COL_LENGTH('dbo.Produtos', 'ativo') IS NULL
                    ALTER TABLE dbo.Produtos ADD ativo BIT NOT NULL CONSTRAINT DF_Produtos_ativo DEFAULT 1;
                IF COL_LENGTH('dbo.Produtos', 'modified_at') IS NULL
                    ALTER TABLE dbo.Produtos ADD modified_at DATETIME NOT NULL CONSTRAINT DF_Produtos_modified DEFAULT GETUTCDATE();
                IF COL_LENGTH('dbo.MovimentacoesEstoque', 'modified_at') IS NULL
                    ALTER TABLE dbo.MovimentacoesEstoque ADD modified_at DATETIME NOT NULL CONSTRAINT DF_Mov_modified DEFAULT GETUTCDATE();
                IF OBJECT_ID(N'dbo.SyncOperations', N'U') IS NULL
                    CREATE TABLE dbo.SyncOperations (
                        client_uuid VARCHAR(100) NOT NULL PRIMARY KEY,
                        tipo VARCHAR(30) NOT NULL,
                        created_at DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
                    );
                IF OBJECT_ID(N'dbo.trg_Produtos_sync', N'TR') IS NOT NULL DROP TRIGGER dbo.trg_Produtos_sync;
                EXEC('CREATE TRIGGER dbo.trg_Produtos_sync ON dbo.Produtos AFTER INSERT, UPDATE AS
                    UPDATE p SET modified_at = GETUTCDATE() FROM dbo.Produtos p JOIN inserted i ON i.id_produto = p.id_produto;');
                IF OBJECT_ID(N'dbo.trg_Movimentacoes_sync', N'TR') IS NOT NULL DROP TRIGGER dbo.trg_Movimentacoes_sync;
                EXEC('CREATE TRIGGER dbo.trg_Movimentacoes_sync ON dbo.MovimentacoesEstoque AFTER INSERT, UPDATE AS
                    UPDATE m SET modified_at = GETUTCDATE() FROM dbo.MovimentacoesEstoque m JOIN inserted i ON i.id_movimentacao = m.id_movimentacao;');
            ", conn);
            cmd.ExecuteNonQuery();
        }

        /// <summary>
        /// Retorna os produtos e movimentacoes alterados desde <paramref name="since"/>.
        /// Usado pelo pull do app Flutter (sync bidirecional).
        /// </summary>
        public static SyncSnapshot PullSync(DateTime since)
        {
            GarantirEstruturaSync();
            var snapshot = new SyncSnapshot { ServerTime = DateTime.UtcNow };
            using var conn = new SqlConnection(connectionString);
            conn.Open();

            // Diferencia "nenhuma alteracao" de uma limpeza completa do servidor,
            // permitindo que o app remova um cache local antigo com seguranca.
            using (var count = new SqlCommand("SELECT COUNT(*) FROM Produtos WHERE ativo = 1", conn))
                snapshot.ProdutosTotal = Convert.ToInt32(count.ExecuteScalar());

            using (var cmd = new SqlCommand("SELECT id_produto, nome_produto, preco, tipo, quantidade_estoque, codigo_barras, descricao, ativo, modified_at FROM Produtos WHERE modified_at > @since ORDER BY id_produto", conn))
            {
                cmd.Parameters.AddWithValue("@since", since);
                using var reader = cmd.ExecuteReader();
                while (reader.Read())
                    snapshot.Produtos.Add(new Dictionary<string, object>
                    {
                        ["id_produto"] = reader["id_produto"],
                        ["nome_produto"] = reader["nome_produto"],
                        ["preco"] = reader["preco"],
                        ["tipo"] = reader["tipo"],
                        ["quantidade_estoque"] = reader["quantidade_estoque"],
                        ["codigo_barras"] = Convert.IsDBNull(reader["codigo_barras"]) ? null! : reader["codigo_barras"],
                        ["descricao"] = Convert.IsDBNull(reader["descricao"]) ? null! : reader["descricao"],
                        ["ativo"] = reader["ativo"],
                        ["modified_at"] = DateTime.SpecifyKind(Convert.ToDateTime(reader["modified_at"]), DateTimeKind.Utc).ToString("o")
                    });
            }

            using (var cmd = new SqlCommand("SELECT id_movimentacao, produtoid, tipo_movimentacao, quantidade, motivo, data_movimentacao, modified_at FROM MovimentacoesEstoque WHERE modified_at > @since ORDER BY id_movimentacao", conn))
            {
                cmd.Parameters.AddWithValue("@since", since);
                using var reader = cmd.ExecuteReader();
                while (reader.Read())
                    snapshot.Movimentacoes.Add(new Dictionary<string, object>
                    {
                        ["id_movimentacao"] = reader["id_movimentacao"],
                        ["produtoid"] = reader["produtoid"],
                        ["tipo_movimentacao"] = reader["tipo_movimentacao"],
                        ["quantidade"] = reader["quantidade"],
                        ["motivo"] = reader["motivo"],
                        ["data_movimentacao"] = reader["data_movimentacao"],
                        ["modified_at"] = DateTime.SpecifyKind(Convert.ToDateTime(reader["modified_at"]), DateTimeKind.Utc).ToString("o")
                    });
            }

            return snapshot;
        }

        public static bool ClaimSyncOperation(string clientUuid, string tipo)
        {
            GarantirEstruturaSync();
            using var conn = new SqlConnection(connectionString);
            conn.Open();
            using var cmd = new SqlCommand("INSERT INTO SyncOperations (client_uuid, tipo) VALUES (@uuid, @tipo)", conn);
            cmd.Parameters.AddWithValue("@uuid", clientUuid);
            cmd.Parameters.AddWithValue("@tipo", tipo);
            try
            {
                cmd.ExecuteNonQuery();
                return true;
            }
            catch (SqlException ex) when (ex.Number is 2601 or 2627)
            {
                return false;
            }
        }

        public static void ReleaseSyncOperation(string clientUuid)
        {
            using var conn = new SqlConnection(connectionString);
            conn.Open();
            using var cmd = new SqlCommand("DELETE FROM SyncOperations WHERE client_uuid = @uuid", conn);
            cmd.Parameters.AddWithValue("@uuid", clientUuid);
            cmd.ExecuteNonQuery();
        }

        public sealed class SyncSnapshot
        {
            public DateTime ServerTime { get; set; }
            public int ProdutosTotal { get; set; }
            public List<Dictionary<string, object>> Produtos { get; set; } = new();
            public List<Dictionary<string, object>> Movimentacoes { get; set; } = new();
        }

        public static bool RegistrarSaidaEstoque(int produtoId, int quantidade, string motivo)
        {
            GarantirTabelaMovimentacoes();
            using var conn = new SqlConnection(connectionString);
            conn.Open();
            using var transaction = conn.BeginTransaction();
            using var cmd = new SqlCommand("UPDATE Produtos SET quantidade_estoque = quantidade_estoque - @quantidade WHERE id_produto = @produtoId AND quantidade_estoque >= @quantidade; IF @@ROWCOUNT = 1 INSERT INTO MovimentacoesEstoque (produtoid, tipo_movimentacao, quantidade, motivo, data_movimentacao) VALUES (@produtoId, 'Saida', @quantidade, @motivo, GETDATE());", conn, transaction);
            cmd.Parameters.AddWithValue("@produtoId", produtoId);
            cmd.Parameters.AddWithValue("@quantidade", quantidade);
            cmd.Parameters.AddWithValue("@motivo", motivo.Trim());
            var affected = cmd.ExecuteNonQuery();
            if (affected == 0) return false;
            transaction.Commit();
            return true;
        }

        public static bool RegistrarEntradaEstoque(int produtoId, int quantidade, string motivo)
        {
            GarantirTabelaMovimentacoes();
            using var conn = new SqlConnection(connectionString);
            conn.Open();
            using var transaction = conn.BeginTransaction();
            using var cmd = new SqlCommand("UPDATE Produtos SET quantidade_estoque = quantidade_estoque + @quantidade WHERE id_produto = @produtoId; IF @@ROWCOUNT = 1 INSERT INTO MovimentacoesEstoque (produtoid, tipo_movimentacao, quantidade, motivo, data_movimentacao) VALUES (@produtoId, 'Entrada', @quantidade, @motivo, GETDATE());", conn, transaction);
            cmd.Parameters.AddWithValue("@produtoId", produtoId);
            cmd.Parameters.AddWithValue("@quantidade", quantidade);
            cmd.Parameters.AddWithValue("@motivo", motivo.Trim());
            var affected = cmd.ExecuteNonQuery();
            if (affected == 0) return false;
            transaction.Commit();
            return true;
        }

        public static Dictionary<string, object> ResumoVendas()
        {
            using var conn = new SqlConnection(connectionString);
            conn.Open();
            using var cmd = new SqlCommand("SELECT (SELECT COUNT(*) FROM Pedidos WHERE CAST(datahora AS DATE) = CAST(GETDATE() AS DATE)) AS pedidos_hoje, (SELECT ISNULL(SUM(valor_total), 0) FROM Pagamentos p JOIN Pedidos pe ON pe.id_pedido = p.pedidoid WHERE CAST(pe.datahora AS DATE) = CAST(GETDATE() AS DATE)) AS faturamento_hoje, (SELECT ISNULL(SUM(i.quantidade), 0) FROM Itens_Pedidos i JOIN Pedidos pe ON pe.id_pedido = i.pedidoid WHERE CAST(pe.datahora AS DATE) = CAST(GETDATE() AS DATE)) AS itens_vendidos", conn);
            using var reader = cmd.ExecuteReader();
            reader.Read();
            return new Dictionary<string, object>
            {
                ["pedidos_hoje"] = reader["pedidos_hoje"],
                ["faturamento_hoje"] = reader["faturamento_hoje"],
                ["itens_vendidos"] = reader["itens_vendidos"]
            };
        }

        public static List<Dictionary<string, object>> HistoricoVendas(int limite = 200)
        {
            using var conn = new SqlConnection(connectionString);
            conn.Open();
            using var cmd = new SqlCommand(@"
                SELECT TOP (@limite)
                       ROW_NUMBER() OVER (ORDER BY p.datahora DESC, p.id_pedido DESC) AS numero_relatorio,
                       p.id_pedido, p.datahora, p.status_pedido,
                       ISNULL(MAX(pg.forma_pagamento), '') AS forma_pagamento,
                       ISNULL(MAX(pg.valor_total), 0) AS valor_total,
                       ISNULL(MAX(c.nome_cliente), 'Cliente não informado') AS cliente_nome,
                       COUNT(i.id_itens_pedidos) AS itens,
                       ISNULL((
                           SELECT STRING_AGG(
                               CONVERT(varchar(max), CONCAT(i2.quantidade, 'x ', pr2.nome_produto)),
                               ', '
                           )
                           FROM Itens_Pedidos i2
                           INNER JOIN Produtos pr2 ON pr2.id_produto = i2.produtoid
                           WHERE i2.pedidoid = p.id_pedido
                       ), '') AS itens_detalhes
                FROM Pedidos p
                LEFT JOIN Clientes c ON c.id_cliente = p.clienteid
                LEFT JOIN Pagamentos pg ON pg.pedidoid = p.id_pedido
                LEFT JOIN Itens_Pedidos i ON i.pedidoid = p.id_pedido
                GROUP BY p.id_pedido, p.datahora, p.status_pedido
                ORDER BY p.datahora DESC, p.id_pedido DESC", conn);
            cmd.Parameters.AddWithValue("@limite", Math.Clamp(limite, 1, 500));
            using var reader = cmd.ExecuteReader();
            var lista = new List<Dictionary<string, object>>();
            while (reader.Read())
                 lista.Add(new Dictionary<string, object>
                 {
                     ["numero_relatorio"] = reader["numero_relatorio"],
                     ["id_pedido"] = reader["id_pedido"],
                    ["datahora"] = reader["datahora"],
                    ["status_pedido"] = reader["status_pedido"],
                    ["forma_pagamento"] = reader["forma_pagamento"],
                    ["valor_total"] = reader["valor_total"],
                     ["cliente_nome"] = reader["cliente_nome"],
                     ["itens"] = reader["itens"],
                     ["itens_detalhes"] = reader["itens_detalhes"]
                 });
            return lista;
        }

        public static List<Dictionary<string, object>> VendasPorProduto()
        {
            var lista = new List<Dictionary<string, object>>();
            using var conn = new SqlConnection(connectionString);
            conn.Open();
            using var cmd = new SqlCommand(@"
                SELECT p.id_produto,
                       p.nome_produto,
                       SUM(i.quantidade) AS quantidade_vendida,
                       SUM(i.quantidade * i.preco_unitario) AS faturamento
                FROM Itens_Pedidos i
                INNER JOIN Pedidos pe ON pe.id_pedido = i.pedidoid
                INNER JOIN Produtos p ON p.id_produto = i.produtoid
                WHERE pe.status_pedido = @status
                  AND EXISTS (
                      SELECT 1 FROM Pagamentos pg WHERE pg.pedidoid = pe.id_pedido
                  )
                GROUP BY p.id_produto, p.nome_produto
                HAVING SUM(i.quantidade) > 0
                ORDER BY SUM(i.quantidade) DESC, p.nome_produto ASC", conn);
            cmd.Parameters.Add("@status", SqlDbType.VarChar, 100).Value = "Finalizado";

            using var reader = cmd.ExecuteReader();
            while (reader.Read())
            {
                lista.Add(new Dictionary<string, object>
                {
                    ["id_produto"] = reader["id_produto"],
                    ["nome_produto"] = reader["nome_produto"],
                    ["quantidade_vendida"] = reader["quantidade_vendida"],
                    ["faturamento"] = reader["faturamento"]
                });
            }

            return lista;
        }

        public static int FinalizarVenda(int? clienteId, int? mesaId, int? funcionarioId, string formaPagamento, IEnumerable<SaleItemData> itens, string? clienteNome = null)
        {
            GarantirTabelaMovimentacoes();
            using var conn = new SqlConnection(connectionString);
            conn.Open();
            using var transaction = conn.BeginTransaction();
            try
            {
                var itemList = itens.ToList();
                if (itemList.Count == 0) return 0;

                if (!clienteId.HasValue && !string.IsNullOrWhiteSpace(clienteNome))
                {
                    using var cliente = new SqlCommand(
                        "SELECT TOP 1 id_cliente FROM Clientes WHERE nome_cliente = @nome;",
                        conn, transaction);
                    cliente.Parameters.AddWithValue("@nome", clienteNome.Trim());
                    var existente = cliente.ExecuteScalar();
                    if (existente is not null)
                        clienteId = Convert.ToInt32(existente);
                    else
                    {
                        cliente.CommandText = "INSERT INTO Clientes (nome_cliente) OUTPUT INSERTED.id_cliente VALUES (@nome);";
                        clienteId = Convert.ToInt32(cliente.ExecuteScalar());
                    }
                }

                using var pedido = new SqlCommand("INSERT INTO Pedidos (mesaid, funcionarioid, clienteid, datahora, status_pedido) OUTPUT INSERTED.id_pedido VALUES (@mesa, @funcionario, @cliente, GETDATE(), 'Finalizado')", conn, transaction);
                pedido.Parameters.AddWithValue("@mesa", mesaId.HasValue ? mesaId.Value : DBNull.Value);
                pedido.Parameters.AddWithValue("@funcionario", funcionarioId.HasValue ? funcionarioId.Value : DBNull.Value);
                pedido.Parameters.AddWithValue("@cliente", clienteId.HasValue ? clienteId.Value : DBNull.Value);
                var pedidoId = Convert.ToInt32(pedido.ExecuteScalar());
                decimal total = 0;

                foreach (var item in itemList)
                {
                    if (item.Quantidade < 1) return 0;
                    using var produto = new SqlCommand("SELECT preco FROM Produtos WHERE id_produto = @produto", conn, transaction);
                    produto.Parameters.AddWithValue("@produto", item.ProdutoId);
                    var precoObject = produto.ExecuteScalar();
                    if (precoObject is null) return 0;
                    var preco = Convert.ToDecimal(precoObject);
                    using var baixa = new SqlCommand("UPDATE Produtos SET quantidade_estoque = quantidade_estoque - @quantidade WHERE id_produto = @produto AND quantidade_estoque >= @quantidade", conn, transaction);
                    baixa.Parameters.AddWithValue("@produto", item.ProdutoId);
                    baixa.Parameters.AddWithValue("@quantidade", item.Quantidade);
                    // O trigger de sincronização também atualiza a linha e pode
                    // fazer o SQL Server reportar mais de uma linha afetada.
                    if (baixa.ExecuteNonQuery() < 1) return 0;
                    using var itemCommand = new SqlCommand("INSERT INTO Itens_Pedidos (pedidoid, produtoid, quantidade, preco_unitario) VALUES (@pedido, @produto, @quantidade, @preco)", conn, transaction);
                    itemCommand.Parameters.AddWithValue("@pedido", pedidoId);
                    itemCommand.Parameters.AddWithValue("@produto", item.ProdutoId);
                    itemCommand.Parameters.AddWithValue("@quantidade", item.Quantidade);
                    itemCommand.Parameters.AddWithValue("@preco", preco);
                    itemCommand.ExecuteNonQuery();
                    using var movimento = new SqlCommand("INSERT INTO MovimentacoesEstoque (produtoid, tipo_movimentacao, quantidade, motivo, data_movimentacao) VALUES (@produto, 'Saida', @quantidade, 'Venda PDV', GETDATE())", conn, transaction);
                    movimento.Parameters.AddWithValue("@produto", item.ProdutoId);
                    movimento.Parameters.AddWithValue("@quantidade", item.Quantidade);
                    movimento.ExecuteNonQuery();
                    total += preco * item.Quantidade;
                }

                using var pagamento = new SqlCommand("INSERT INTO Pagamentos (pedidoid, forma_pagamento, valor_total) VALUES (@pedido, @forma, @total)", conn, transaction);
                pagamento.Parameters.AddWithValue("@pedido", pedidoId);
                pagamento.Parameters.AddWithValue("@forma", formaPagamento);
                pagamento.Parameters.AddWithValue("@total", total);
                pagamento.ExecuteNonQuery();
                transaction.Commit();
                return pedidoId;
            }
            catch
            {
                transaction.Rollback();
                return 0;
            }
        }

        private static void GarantirTabelaMovimentacoes()
        {
            GarantirEstruturaEstoque();
        }

        private static void GarantirEstruturaEstoque()
        {
            using var conn = new SqlConnection(connectionString);
            conn.Open();
            using var cmd = new SqlCommand(@"
                IF COL_LENGTH('dbo.Produtos', 'quantidade_estoque') IS NULL
                    ALTER TABLE dbo.Produtos ADD quantidade_estoque INT NOT NULL CONSTRAINT DF_Produtos_quantidade DEFAULT 0;
                IF COL_LENGTH('dbo.Produtos', 'codigo_barras') IS NULL
                    ALTER TABLE dbo.Produtos ADD codigo_barras VARCHAR(50) NULL;
                IF COL_LENGTH('dbo.Produtos', 'descricao') IS NULL
                    ALTER TABLE dbo.Produtos ADD descricao VARCHAR(500) NULL;
                IF COL_LENGTH('dbo.Produtos', 'ativo') IS NULL
                    ALTER TABLE dbo.Produtos ADD ativo BIT NOT NULL CONSTRAINT DF_Produtos_ativo DEFAULT 1;
                IF COL_LENGTH('dbo.Produtos', 'modified_at') IS NULL
                    ALTER TABLE dbo.Produtos ADD modified_at DATETIME NOT NULL CONSTRAINT DF_Produtos_modified DEFAULT GETUTCDATE();
                IF OBJECT_ID(N'dbo.MovimentacoesEstoque', N'U') IS NULL
                    CREATE TABLE MovimentacoesEstoque (id_movimentacao INT IDENTITY(1,1) PRIMARY KEY, produtoid INT NOT NULL, tipo_movimentacao VARCHAR(20) NOT NULL, quantidade INT NOT NULL, motivo VARCHAR(200) NOT NULL, data_movimentacao DATETIME NOT NULL, CONSTRAINT FK_Movimentacoes_Produtos FOREIGN KEY (produtoid) REFERENCES Produtos(id_produto));
                IF COL_LENGTH('dbo.MovimentacoesEstoque', 'modified_at') IS NULL
                    ALTER TABLE dbo.MovimentacoesEstoque ADD modified_at DATETIME NOT NULL CONSTRAINT DF_Mov_modified DEFAULT GETUTCDATE();
            ", conn);
            cmd.ExecuteNonQuery();
        }

        // =========================
        // MESAS
        // =========================

        public static List<Dictionary<string, object>> ListarMesas()
        {
            var lista = new List<Dictionary<string, object>>();
            using (var conn = new SqlConnection(connectionString))
            {
                conn.Open();
                var cmd = new SqlCommand("sp_ListarMesas", conn) { CommandType = CommandType.StoredProcedure };
                var reader = cmd.ExecuteReader();
                while (reader.Read())
                    lista.Add(new Dictionary<string, object>
                    {
                        ["id_mesa"] = reader["id_mesa"],
                        ["numero"] = reader["numero"],
                        ["capacidade"] = reader["capacidade"],
                        ["status_mesa"] = reader["status_mesa"]
                    });
            }
            return lista;
        }

        public static List<Dictionary<string, object>> ListarMesasCadastro(bool incluirInativas)
        {
            var lista = new List<Dictionary<string, object>>();
            using var conn = new SqlConnection(connectionString);
            conn.Open();
            using var cmd = new SqlCommand(@"
                SELECT id_mesa, numero, capacidade, status_mesa, ativo
                FROM Mesas
                WHERE @incluirInativas = 1 OR ativo = 1
                ORDER BY numero, id_mesa", conn);
            cmd.Parameters.AddWithValue("@incluirInativas", incluirInativas);
            using var reader = cmd.ExecuteReader();
            while (reader.Read())
                lista.Add(new Dictionary<string, object>
                {
                    ["id_mesa"] = reader["id_mesa"],
                    ["numero"] = reader["numero"],
                    ["capacidade"] = reader["capacidade"],
                    ["status_mesa"] = reader["status_mesa"],
                    ["ativo"] = reader["ativo"]
                });
            return lista;
        }

        public static int CadastrarMesaCadastro(int numero, int capacidade)
        {
            using var conn = new SqlConnection(connectionString);
            conn.Open();
            using var transaction = conn.BeginTransaction(IsolationLevel.Serializable);
            try
            {
                VerificarNumeroMesaDisponivel(conn, transaction, numero, null);
                using var cmd = new SqlCommand(@"
                    INSERT INTO Mesas (numero, capacidade, status_mesa, ativo)
                    OUTPUT INSERTED.id_mesa
                    VALUES (@numero, @capacidade, 'Disponivel', 1)", conn, transaction);
                cmd.Parameters.AddWithValue("@numero", numero);
                cmd.Parameters.AddWithValue("@capacidade", capacidade);
                var id = Convert.ToInt32(cmd.ExecuteScalar());
                transaction.Commit();
                return id;
            }
            catch
            {
                transaction.Rollback();
                throw;
            }
        }

        public static bool AtualizarMesaCadastro(int id, int numero, int capacidade)
        {
            using var conn = new SqlConnection(connectionString);
            conn.Open();
            using var transaction = conn.BeginTransaction(IsolationLevel.Serializable);
            try
            {
                using (var mesaAtiva = new SqlCommand(
                    "SELECT COUNT(1) FROM Mesas WITH (UPDLOCK, HOLDLOCK) WHERE id_mesa = @id AND ativo = 1",
                    conn, transaction))
                {
                    mesaAtiva.Parameters.AddWithValue("@id", id);
                    if (Convert.ToInt32(mesaAtiva.ExecuteScalar()) == 0)
                    {
                        transaction.Rollback();
                        return false;
                    }
                }

                VerificarNumeroMesaDisponivel(conn, transaction, numero, id);
                using var cmd = new SqlCommand(@"
                    UPDATE Mesas SET numero = @numero, capacidade = @capacidade
                    WHERE id_mesa = @id AND ativo = 1", conn, transaction);
                cmd.Parameters.AddWithValue("@id", id);
                cmd.Parameters.AddWithValue("@numero", numero);
                cmd.Parameters.AddWithValue("@capacidade", capacidade);
                var atualizado = cmd.ExecuteNonQuery() > 0;
                transaction.Commit();
                return atualizado;
            }
            catch
            {
                transaction.Rollback();
                throw;
            }
        }

        private static void VerificarNumeroMesaDisponivel(SqlConnection conn, SqlTransaction transaction, int numero, int? id)
        {
            using var cmd = new SqlCommand(@"
                SELECT COUNT(1) FROM Mesas WITH (UPDLOCK, HOLDLOCK)
                WHERE numero = @numero AND ativo = 1
                  AND (@id = 0 OR id_mesa <> @id)", conn, transaction);
            cmd.Parameters.AddWithValue("@numero", numero);
            cmd.Parameters.AddWithValue("@id", id.GetValueOrDefault());
            if (Convert.ToInt32(cmd.ExecuteScalar()) > 0)
                throw new MesaNumeroDuplicadoException();
        }

        public static bool DefinirMesaAtiva(int id, bool ativo)
        {
            using var conn = new SqlConnection(connectionString);
            conn.Open();
            using var transaction = conn.BeginTransaction(IsolationLevel.Serializable);
            try
            {
                int numeroMesa;
                string statusMesa;
                using (var mesa = new SqlCommand(
                    "SELECT numero, status_mesa FROM Mesas WITH (UPDLOCK, HOLDLOCK) WHERE id_mesa = @id",
                    conn, transaction))
                {
                    mesa.Parameters.AddWithValue("@id", id);
                    using (var reader = mesa.ExecuteReader())
                    {
                        if (!reader.Read())
                        {
                            transaction.Rollback();
                            return false;
                        }

                        numeroMesa = Convert.ToInt32(reader["numero"]);
                        statusMesa = reader["status_mesa"].ToString() ?? string.Empty;
                    }

                    if (ativo)
                        VerificarNumeroMesaDisponivel(conn, transaction, numeroMesa, id);
                }

                if (!ativo &&
                    (string.Equals(statusMesa, "Ocupada", StringComparison.OrdinalIgnoreCase) ||
                     string.Equals(statusMesa, "Reservada", StringComparison.OrdinalIgnoreCase)))
                {
                    transaction.Rollback();
                    return false;
                }

                if (!ativo)
                {
                    using var pedidosAbertos = new SqlCommand(@"
                        SELECT COUNT(1) FROM Pedidos WITH (UPDLOCK, HOLDLOCK)
                        WHERE mesaid = @id AND status_pedido = 'Aberto'", conn, transaction);
                    pedidosAbertos.Parameters.AddWithValue("@id", id);
                    if (Convert.ToInt32(pedidosAbertos.ExecuteScalar()) > 0)
                    {
                        transaction.Rollback();
                        return false;
                    }
                }

                using var cmd = new SqlCommand(@"
                    UPDATE Mesas
                    SET ativo = @ativo,
                        status_mesa = CASE WHEN @ativo = 1 AND ativo = 0 THEN 'Disponivel' ELSE status_mesa END
                    WHERE id_mesa = @id AND ativo <> @ativo", conn, transaction);
                cmd.Parameters.AddWithValue("@id", id);
                cmd.Parameters.AddWithValue("@ativo", ativo);
                var alterado = cmd.ExecuteNonQuery() > 0;
                transaction.Commit();
                return alterado;
            }
            catch
            {
                transaction.Rollback();
                throw;
            }
        }

        public static void AtualizarStatusMesa(int id, string status)
        {
            using (var conn = new SqlConnection(connectionString))
            {
                conn.Open();
                var cmd = new SqlCommand("sp_AtualizarStatusMesa", conn) { CommandType = CommandType.StoredProcedure };
                cmd.Parameters.AddWithValue("@id", id);
                cmd.Parameters.AddWithValue("@status", status);
                cmd.ExecuteNonQuery();
            }
        }

        // =========================
        // PEDIDOS
        // =========================

        public static int CriarPedido(int mesaId, int? funcionarioId, int clienteId)
        {
            using (var conn = new SqlConnection(connectionString))
            {
                conn.Open();
                var cmd = new SqlCommand("sp_CriarPedido", conn) { CommandType = CommandType.StoredProcedure };
                cmd.Parameters.AddWithValue("@mesaId", mesaId);
                cmd.Parameters.AddWithValue("@funcionarioId", funcionarioId.HasValue ? funcionarioId.Value : DBNull.Value);
                cmd.Parameters.AddWithValue("@clienteId", clienteId);
                return Convert.ToInt32(cmd.ExecuteScalar());
            }
        }

        public static bool AdicionarItemPedido(
            int pedidoId,
            int produtoId,
            int quantidade,
            out int quantidadeDisponivel)
        {
            quantidadeDisponivel = -1;
            if (pedidoId <= 0 || produtoId <= 0 || quantidade < 1) return false;

            using var conn = new SqlConnection(connectionString);
            conn.Open();
            using var transaction = conn.BeginTransaction(IsolationLevel.Serializable);
            try
            {
                using (var pedido = new SqlCommand(
                    "SELECT status_pedido FROM Pedidos WITH (UPDLOCK, HOLDLOCK) WHERE id_pedido = @pedidoId",
                    conn,
                    transaction))
                {
                    pedido.Parameters.AddWithValue("@pedidoId", pedidoId);
                    var status = pedido.ExecuteScalar()?.ToString();
                    if (!string.Equals(status, "Aberto", StringComparison.OrdinalIgnoreCase))
                    {
                        transaction.Rollback();
                        return false;
                    }
                }

                using (var estoque = new SqlCommand(@"
                    SELECT p.quantidade_estoque - ISNULL(SUM(i.quantidade), 0)
                    FROM Produtos p WITH (UPDLOCK, HOLDLOCK)
                    LEFT JOIN Itens_Pedidos i
                      ON i.produtoid = p.id_produto AND i.pedidoid = @pedidoId
                    WHERE p.id_produto = @produtoId AND p.ativo = 1
                    GROUP BY p.quantidade_estoque", conn, transaction))
                {
                    estoque.Parameters.AddWithValue("@pedidoId", pedidoId);
                    estoque.Parameters.AddWithValue("@produtoId", produtoId);
                    var saldo = estoque.ExecuteScalar();
                    if (saldo is null or DBNull)
                    {
                        transaction.Rollback();
                        return false;
                    }

                    quantidadeDisponivel = Math.Max(0, Convert.ToInt32(saldo));
                }

                if (quantidade > quantidadeDisponivel)
                {
                    transaction.Rollback();
                    return false;
                }

                using var cmd = new SqlCommand("sp_AdicionarItemPedido", conn, transaction)
                {
                    CommandType = CommandType.StoredProcedure
                };
                cmd.Parameters.AddWithValue("@pedidoId", pedidoId);
                cmd.Parameters.AddWithValue("@produtoId", produtoId);
                cmd.Parameters.AddWithValue("@quantidade", quantidade);
                if (cmd.ExecuteNonQuery() <= 0)
                {
                    transaction.Rollback();
                    return false;
                }

                transaction.Commit();
                return true;
            }
            catch
            {
                if (transaction.Connection is not null) transaction.Rollback();
                throw;
            }
        }

        public static List<Dictionary<string, object>> ListarItensPedido(int pedidoId)
        {
            var lista = new List<Dictionary<string, object>>();
            using var conn = new SqlConnection(connectionString);
            conn.Open();
            using var cmd = new SqlCommand(@"
                SELECT i.produtoid, p.nome_produto, SUM(i.quantidade) AS quantidade,
                       i.preco_unitario, SUM(i.quantidade * i.preco_unitario) AS subtotal
                FROM Itens_Pedidos i
                INNER JOIN Produtos p ON p.id_produto = i.produtoid
                WHERE i.pedidoid = @pedidoId
                GROUP BY i.produtoid, p.nome_produto, i.preco_unitario
                ORDER BY p.nome_produto", conn);
            cmd.Parameters.AddWithValue("@pedidoId", pedidoId);
            using var reader = cmd.ExecuteReader();
            while (reader.Read())
                lista.Add(new Dictionary<string, object>
                {
                    ["produtoid"] = reader["produtoid"],
                    ["nome_produto"] = reader["nome_produto"],
                    ["quantidade"] = reader["quantidade"],
                    ["preco_unitario"] = reader["preco_unitario"],
                    ["subtotal"] = reader["subtotal"]
                });
            return lista;
        }

        public static void RemoverItemPedido(int pedidoId, int produtoId)
        {
            using var conn = new SqlConnection(connectionString);
            conn.Open();
            using var cmd = new SqlCommand("DELETE FROM Itens_Pedidos WHERE pedidoid = @pedidoId AND produtoid = @produtoId", conn);
            cmd.Parameters.AddWithValue("@pedidoId", pedidoId);
            cmd.Parameters.AddWithValue("@produtoId", produtoId);
            cmd.ExecuteNonQuery();
        }

        public static decimal CalcularTotalPedido(int pedidoId)
        {
            using (var conn = new SqlConnection(connectionString))
            {
                conn.Open();
                var cmd = new SqlCommand("sp_CalcularTotalPedido", conn) { CommandType = CommandType.StoredProcedure };
                cmd.Parameters.AddWithValue("@pedidoId", pedidoId);
                var valor = cmd.ExecuteScalar();
                return valor is null or DBNull ? 0m : Convert.ToDecimal(valor);
            }
        }

        public static void RegistrarPagamento(int pedidoId, string forma, decimal valor)
        {
            using (var conn = new SqlConnection(connectionString))
            {
                conn.Open();
                var cmd = new SqlCommand("sp_RegistrarPagamento", conn) { CommandType = CommandType.StoredProcedure };
                cmd.Parameters.AddWithValue("@pedidoId", pedidoId);
                cmd.Parameters.AddWithValue("@forma", forma);
                cmd.Parameters.AddWithValue("@valor", valor);
                cmd.ExecuteNonQuery();
            }
        }

        public static void FinalizarPedido(int pedidoId)
        {
            if (!FecharPedidoComBaixaEstoque(pedidoId, null, out var mensagem))
                throw new InvalidOperationException(mensagem);
        }

        public static bool FinalizarAtendimento(
            int pedidoId,
            string formaPagamento,
            out string mensagem)
        {
            var forma = formaPagamento?.Trim() ?? string.Empty;
            if (forma is not ("Dinheiro" or "Cartão" or "Cartão de crédito" or "Cartão de débito" or "Pix"))
            {
                mensagem = "Selecione uma forma de pagamento válida.";
                return false;
            }

            return FecharPedidoTransacional(pedidoId, null, forma, out mensagem);
        }

        public static bool FecharPedidoComBaixaEstoque(
            int pedidoId,
            int? mesaId,
            out string mensagem)
        {
            return FecharPedidoTransacional(pedidoId, mesaId, null, out mensagem);
        }

        private static bool FecharPedidoTransacional(
            int pedidoId,
            int? mesaIdEsperada,
            string? formaPagamento,
            out string mensagem)
        {
            mensagem = "Não foi possível finalizar o pedido.";
            if (pedidoId <= 0)
            {
                mensagem = "Pedido inválido.";
                return false;
            }

            GarantirTabelaMovimentacoes();
            using var conn = new SqlConnection(connectionString);
            conn.Open();
            using var transaction = conn.BeginTransaction(IsolationLevel.Serializable);
            try
            {
                int? mesaId = null;
                var pedidoEncontrado = false;
                var pedidoAberto = false;
                using (var pedido = new SqlCommand(
                    "SELECT status_pedido, mesaid FROM Pedidos WITH (UPDLOCK, HOLDLOCK) WHERE id_pedido = @pedidoId",
                    conn,
                    transaction))
                {
                    pedido.Parameters.AddWithValue("@pedidoId", pedidoId);
                    using var reader = pedido.ExecuteReader();
                    if (reader.Read())
                    {
                        pedidoEncontrado = true;
                        pedidoAberto = string.Equals(
                            reader["status_pedido"].ToString(),
                            "Aberto",
                            StringComparison.OrdinalIgnoreCase);
                        mesaId = Convert.IsDBNull(reader["mesaid"])
                            ? null
                            : Convert.ToInt32(reader["mesaid"]);
                    }
                }

                if (!pedidoEncontrado)
                {
                    transaction.Rollback();
                    mensagem = "O pedido não foi encontrado.";
                    return false;
                }
                if (!pedidoAberto)
                {
                    transaction.Rollback();
                    mensagem = "Este pedido já foi finalizado ou cancelado.";
                    return false;
                }

                if (mesaIdEsperada.HasValue && mesaId != mesaIdEsperada)
                {
                    transaction.Rollback();
                    mensagem = "A mesa informada não corresponde ao pedido.";
                    return false;
                }

                if (!BaixarEstoqueDosItensPedido(pedidoId, conn, transaction, out mensagem))
                {
                    transaction.Rollback();
                    return false;
                }

                var total = CalcularTotalPedidoNaTransacao(pedidoId, conn, transaction);
                if (formaPagamento is not null)
                {
                    using var pagamento = new SqlCommand(
                        "INSERT INTO Pagamentos (pedidoid, forma_pagamento, valor_total) VALUES (@pedidoId, @forma, @valor)",
                        conn,
                        transaction);
                    pagamento.Parameters.AddWithValue("@pedidoId", pedidoId);
                    pagamento.Parameters.AddWithValue("@forma", formaPagamento);
                    pagamento.Parameters.AddWithValue("@valor", total);
                    pagamento.ExecuteNonQuery();
                }

                using (var finalizar = new SqlCommand(
                    "UPDATE Pedidos SET status_pedido = 'Finalizado' WHERE id_pedido = @pedidoId AND status_pedido = 'Aberto'",
                    conn,
                    transaction))
                {
                    finalizar.Parameters.AddWithValue("@pedidoId", pedidoId);
                    if (finalizar.ExecuteNonQuery() < 1)
                    {
                        transaction.Rollback();
                        mensagem = "O pedido mudou de estado e não pôde ser finalizado.";
                        return false;
                    }
                }

                if (mesaId.HasValue)
                {
                    using var mesa = new SqlCommand(
                        "UPDATE Mesas SET status_mesa = 'Disponível' WHERE id_mesa = @mesaId AND status_mesa = 'Ocupada'",
                        conn,
                        transaction);
                    mesa.Parameters.AddWithValue("@mesaId", mesaId.Value);
                    mesa.ExecuteNonQuery();
                }

                transaction.Commit();
                mensagem = formaPagamento is null
                    ? "Pedido fechado e estoque atualizado."
                    : "Venda finalizada e estoque atualizado.";
                return true;
            }
            catch
            {
                if (transaction.Connection is not null) transaction.Rollback();
                throw;
            }
        }

        private static bool BaixarEstoqueDosItensPedido(
            int pedidoId,
            SqlConnection conn,
            SqlTransaction transaction,
            out string mensagem)
        {
            mensagem = string.Empty;
            var itens = new List<(int ProdutoId, int Quantidade)>();
            using (var command = new SqlCommand(@"
                SELECT produtoid, SUM(quantidade) AS quantidade
                FROM Itens_Pedidos
                WHERE pedidoid = @pedidoId
                GROUP BY produtoid", conn, transaction))
            {
                command.Parameters.AddWithValue("@pedidoId", pedidoId);
                using var reader = command.ExecuteReader();
                while (reader.Read())
                    itens.Add((Convert.ToInt32(reader["produtoid"]), Convert.ToInt32(reader["quantidade"])));
            }

            if (itens.Count == 0)
            {
                mensagem = "Adicione ao menos um item antes de finalizar o pedido.";
                return false;
            }

            foreach (var item in itens)
            {
                if (item.Quantidade < 1)
                {
                    mensagem = "O pedido contém uma quantidade inválida.";
                    return false;
                }

                string nomeProduto;
                int saldo;
                using (var produto = new SqlCommand(
                    "SELECT nome_produto, quantidade_estoque FROM Produtos WITH (UPDLOCK, HOLDLOCK) WHERE id_produto = @produtoId AND ativo = 1",
                    conn,
                    transaction))
                {
                    produto.Parameters.AddWithValue("@produtoId", item.ProdutoId);
                    using var reader = produto.ExecuteReader();
                    if (!reader.Read())
                    {
                        mensagem = "Um produto do pedido não está mais disponível.";
                        return false;
                    }

                    nomeProduto = reader["nome_produto"].ToString() ?? "Produto";
                    saldo = Convert.ToInt32(reader["quantidade_estoque"]);
                }

                if (saldo < item.Quantidade)
                {
                    mensagem = $"Estoque insuficiente para {nomeProduto}. Disponível: {saldo} unidade(s).";
                    return false;
                }

                using (var baixa = new SqlCommand(@"
                    UPDATE Produtos
                    SET quantidade_estoque = quantidade_estoque - @quantidade
                    WHERE id_produto = @produtoId AND ativo = 1 AND quantidade_estoque >= @quantidade",
                    conn,
                    transaction))
                {
                    baixa.Parameters.AddWithValue("@produtoId", item.ProdutoId);
                    baixa.Parameters.AddWithValue("@quantidade", item.Quantidade);
                    if (baixa.ExecuteNonQuery() < 1)
                    {
                        mensagem = $"O estoque de {nomeProduto} mudou. Atualize o pedido e tente novamente.";
                        return false;
                    }
                }

                using var movimento = new SqlCommand(@"
                    INSERT INTO MovimentacoesEstoque
                        (produtoid, tipo_movimentacao, quantidade, motivo, data_movimentacao)
                    VALUES
                        (@produtoId, 'Saida', @quantidade, @motivo, GETDATE())",
                    conn,
                    transaction);
                movimento.Parameters.AddWithValue("@produtoId", item.ProdutoId);
                movimento.Parameters.AddWithValue("@quantidade", item.Quantidade);
                movimento.Parameters.AddWithValue("@motivo", $"Venda no site - Pedido {pedidoId}");
                movimento.ExecuteNonQuery();
            }

            return true;
        }

        private static decimal CalcularTotalPedidoNaTransacao(
            int pedidoId,
            SqlConnection conn,
            SqlTransaction transaction)
        {
            using var command = new SqlCommand(
                "SELECT ISNULL(SUM(quantidade * preco_unitario), 0) FROM Itens_Pedidos WHERE pedidoid = @pedidoId",
                conn,
                transaction);
            command.Parameters.AddWithValue("@pedidoId", pedidoId);
            return Convert.ToDecimal(command.ExecuteScalar());
        }

        public static void CancelarAtendimento(int pedidoId, int mesaId)
        {
            using var conn = new SqlConnection(connectionString);
            conn.Open();
            using var transaction = conn.BeginTransaction();
            try
            {
                var pedidoPodeCancelar = false;
                using (var validar = new SqlCommand(
                    "SELECT mesaid, status_pedido FROM Pedidos WITH (UPDLOCK, HOLDLOCK) WHERE id_pedido = @pedidoId",
                    conn,
                    transaction))
                {
                    validar.Parameters.AddWithValue("@pedidoId", pedidoId);
                    using var reader = validar.ExecuteReader();
                    if (reader.Read())
                    {
                        pedidoPodeCancelar =
                            string.Equals(reader["status_pedido"].ToString(), "Aberto", StringComparison.OrdinalIgnoreCase) &&
                            !Convert.IsDBNull(reader["mesaid"]) &&
                            Convert.ToInt32(reader["mesaid"]) == mesaId;
                    }
                }

                if (!pedidoPodeCancelar)
                {
                    transaction.Rollback();
                    return;
                }

                using var itens = new SqlCommand("DELETE FROM Itens_Pedidos WHERE pedidoid = @pedidoId", conn, transaction);
                itens.Parameters.AddWithValue("@pedidoId", pedidoId);
                itens.ExecuteNonQuery();

                using var pedido = new SqlCommand("DELETE FROM Pedidos WHERE id_pedido = @pedidoId AND status_pedido = 'Aberto'", conn, transaction);
                pedido.Parameters.AddWithValue("@pedidoId", pedidoId);
                pedido.ExecuteNonQuery();

                using var mesa = new SqlCommand("UPDATE Mesas SET status_mesa = 'Disponível' WHERE id_mesa = @mesaId AND status_mesa = 'Ocupada'", conn, transaction);
                mesa.Parameters.AddWithValue("@mesaId", mesaId);
                mesa.ExecuteNonQuery();

                transaction.Commit();
            }
            catch
            {
                transaction.Rollback();
                throw;
            }
        }

        public static List<Dictionary<string, object>> ListarPedidosAbertos()
        {
            var lista = new List<Dictionary<string, object>>();
            using (var conn = new SqlConnection(connectionString))
            {
                conn.Open();
                var cmd = new SqlCommand("sp_ListarPedidosAbertos", conn) { CommandType = CommandType.StoredProcedure };
                var reader = cmd.ExecuteReader();
                while (reader.Read())
                    lista.Add(new Dictionary<string, object>
                    {
                        ["id_pedido"] = reader["id_pedido"],
                        ["mesaid"] = reader["mesaid"],
                        ["status_pedido"] = reader["status_pedido"]
                    });
            }
            return lista;
        }

        // =========================
        // FUNCIONÁRIOS
        // =========================

        public static List<Dictionary<string, object>> ListarFuncionarios()
        {
            var lista = new List<Dictionary<string, object>>();
            using (var conn = new SqlConnection(connectionString))
            {
                conn.Open();
                var cmd = new SqlCommand("sp_ListarFuncionarios", conn) { CommandType = CommandType.StoredProcedure };
                var reader = cmd.ExecuteReader();
                while (reader.Read())
                    lista.Add(new Dictionary<string, object>
                    {
                        ["id_funcionario"] = reader["id_funcionario"],
                        ["nome_funcionario"] = reader["nome_funcionario"],
                        ["cargo"] = reader["cargo"]
                    });
            }
            return lista;
        }

        public static List<Dictionary<string, object>> ListarFuncionariosCadastro(bool incluirInativos)
        {
            var lista = new List<Dictionary<string, object>>();
            using var conn = new SqlConnection(connectionString);
            conn.Open();
            using var cmd = new SqlCommand(@"
                SELECT id_funcionario, nome_funcionario, cargo, ativo
                FROM Funcionarios
                WHERE @incluirInativos = 1 OR ativo = 1
                ORDER BY nome_funcionario", conn);
            cmd.Parameters.AddWithValue("@incluirInativos", incluirInativos);
            using var reader = cmd.ExecuteReader();
            while (reader.Read())
                lista.Add(new Dictionary<string, object>
                {
                    ["id_funcionario"] = reader["id_funcionario"],
                    ["nome_funcionario"] = reader["nome_funcionario"],
                    ["cargo"] = reader["cargo"],
                    ["ativo"] = reader["ativo"]
                });
            return lista;
        }

        public static int CadastrarFuncionarioCadastro(string nome, string cargo)
        {
            using var conn = new SqlConnection(connectionString);
            conn.Open();
            using var cmd = new SqlCommand(@"
                INSERT INTO Funcionarios (nome_funcionario, cargo, ativo)
                OUTPUT INSERTED.id_funcionario
                VALUES (@nome, @cargo, 1)", conn);
            cmd.Parameters.AddWithValue("@nome", nome);
            cmd.Parameters.AddWithValue("@cargo", cargo);
            return Convert.ToInt32(cmd.ExecuteScalar());
        }

        public static bool AtualizarFuncionarioCadastro(int id, string nome, string cargo)
        {
            using var conn = new SqlConnection(connectionString);
            conn.Open();
            using var cmd = new SqlCommand(@"
                UPDATE Funcionarios SET nome_funcionario = @nome, cargo = @cargo
                WHERE id_funcionario = @id AND ativo = 1", conn);
            cmd.Parameters.AddWithValue("@id", id);
            cmd.Parameters.AddWithValue("@nome", nome);
            cmd.Parameters.AddWithValue("@cargo", cargo);
            return cmd.ExecuteNonQuery() > 0;
        }

        public static bool DefinirFuncionarioAtivo(int id, bool ativo)
        {
            using var conn = new SqlConnection(connectionString);
            conn.Open();
            using var cmd = new SqlCommand("UPDATE Funcionarios SET ativo = @ativo WHERE id_funcionario = @id AND ativo <> @ativo", conn);
            cmd.Parameters.AddWithValue("@id", id);
            cmd.Parameters.AddWithValue("@ativo", ativo);
            return cmd.ExecuteNonQuery() > 0;
        }

        // =========================
        // RELATÓRIOS
        // =========================

        public static List<Dictionary<string, object>> PedidosDoDia()
        {
            var lista = new List<Dictionary<string, object>>();
            using (var conn = new SqlConnection(connectionString))
            {
                conn.Open();
                var cmd = new SqlCommand("sp_PedidosDoDia", conn) { CommandType = CommandType.StoredProcedure };
                var reader = cmd.ExecuteReader();
                while (reader.Read())
                    lista.Add(new Dictionary<string, object>
                    {
                        ["id_pedido"] = reader["id_pedido"],
                        ["datahora"] = reader["datahora"]
                    });
            }
            return lista;
        }

        public static List<Dictionary<string, object>> ProdutosMaisVendidos()
        {
            var lista = new List<Dictionary<string, object>>();
            using (var conn = new SqlConnection(connectionString))
            {
                conn.Open();
                var cmd = new SqlCommand("sp_ProdutosMaisVendidos", conn) { CommandType = CommandType.StoredProcedure };
                var reader = cmd.ExecuteReader();
                while (reader.Read())
                    lista.Add(new Dictionary<string, object>
                    {
                        ["nome_produto"] = reader["nome_produto"],
                        ["total_vendido"] = reader["total_vendido"]
                    });
            }
            return lista;
        }

        public static List<Dictionary<string, object>> HistoricoCliente(int clienteId)
        {
            var lista = new List<Dictionary<string, object>>();
            using (var conn = new SqlConnection(connectionString))
            {
                conn.Open();
                var cmd = new SqlCommand("sp_HistoricoCliente", conn) { CommandType = CommandType.StoredProcedure };
                cmd.Parameters.AddWithValue("@clienteId", clienteId);
                var reader = cmd.ExecuteReader();
                while (reader.Read())
                    lista.Add(new Dictionary<string, object>
                    {
                        ["id_pedido"] = reader["id_pedido"],
                        ["status_pedido"] = reader["status_pedido"],
                        ["datahora"] = reader["datahora"]
                    });
            }
            return lista;
        }

        public static decimal Faturamento()
        {
            using (var conn = new SqlConnection(connectionString))
            {
                conn.Open();
                var cmd = new SqlCommand("sp_Faturamento", conn) { CommandType = CommandType.StoredProcedure };
                return Convert.ToDecimal(cmd.ExecuteScalar());
            }
        }
    }

    public sealed class MesaNumeroDuplicadoException : Exception
    {
        public MesaNumeroDuplicadoException()
            : base("Já existe uma mesa ativa com esse número.")
        {
        }
    }
}

using System.Text.Json;
using InfiniteCoffee2.Data;
using InfiniteCoffee2.Models;
using Microsoft.AspNetCore.Mvc;

namespace InfiniteCoffee2.Controllers.Api;

[ApiController]
[Route("api/sync")]
public sealed class SyncApiController : ControllerBase
{
    /// <summary>
    /// Pull: retorna produtos e movimentacoes alterados desde <paramref name="since"/>.
    /// O app envia o serverTime da resposta anterior; se omitido, faz o seed completo.
    /// </summary>
    [HttpGet("pull")]
    public IActionResult Pull([FromQuery] string? since = null)
    {
        var sinceUtc = new DateTime(1900, 1, 1, 0, 0, 0, DateTimeKind.Utc);
        if (!string.IsNullOrWhiteSpace(since) && DateTime.TryParse(since, out var parsed))
            sinceUtc = parsed.ToUniversalTime();

        var snapshot = Banco.PullSync(sinceUtc.ToUniversalTime());
        return Ok(new
        {
            serverTime = snapshot.ServerTime.ToString("o"),
            produtosTotal = snapshot.ProdutosTotal,
            produtos = snapshot.Produtos,
            movimentacoes = snapshot.Movimentacoes
        });
    }

    /// <summary>
    /// Push: aplica operacoes feitas offline (saida, entrada, venda) em lote.
    /// O clientUuid identifica a operacao e e persistido para impedir reenvio duplicado.
    /// </summary>
    [HttpPost("push")]
    public IActionResult Push([FromBody] PushSyncRequest request)
    {
        if (request?.Operacoes is null || request.Operacoes.Count == 0 || request.Operacoes.Count > 100)
            return BadRequest(new { mensagem = "Envie entre 1 e 100 operações." });
        var aceitos = new List<string>();
        var rejeitados = new List<string>();

        // Cada operacao e processada isoladamente para que uma falha nao esconda
        // quais itens do lote foram aceitos ou precisam permanecer na fila local.
        foreach (var op in request.Operacoes)
        {
            if (string.IsNullOrWhiteSpace(op.ClientUuid) || op.ClientUuid.Length > 100 || string.IsNullOrWhiteSpace(op.Tipo))
            {
                rejeitados.Add(op.ClientUuid);
                continue;
            }
            if (!Banco.ClaimSyncOperation(op.ClientUuid, op.Tipo))
            {
                aceitos.Add(op.ClientUuid);
                continue;
            }
            try
            {
                var ok = op.Tipo switch
                {
                    "saida" => Banco.RegistrarSaidaEstoque(op.GetInt("produtoId"), op.GetInt("quantidade"), op.GetString("motivo") ?? "Ajuste"),
                    "entrada" => Banco.RegistrarEntradaEstoque(op.GetInt("produtoId"), op.GetInt("quantidade"), op.GetString("motivo") ?? "Reposição"),
                        "venda" => Banco.FinalizarVenda(
                        op.GetNullableInt("clienteId"),
                        op.GetNullableInt("mesaId"),
                        op.GetNullableInt("funcionarioId"),
                        op.GetString("formaPagamento") ?? "Pix",
                        op.GetItens("itens"),
                        op.GetString("clienteNome")) > 0,
                    _ => false
                };

                if (ok) aceitos.Add(op.ClientUuid);
                else
                {
                    Banco.ReleaseSyncOperation(op.ClientUuid);
                    rejeitados.Add(op.ClientUuid);
                }
            }
            catch
            {
                Banco.ReleaseSyncOperation(op.ClientUuid);
                rejeitados.Add(op.ClientUuid);
            }
        }

        return Ok(new { aceitos, rejeitados });
    }

    /// <summary>Versao combinada para checagem leve de mudancas.</summary>
    [HttpGet("versao")]
    public IActionResult Versao() =>
        Ok(new { estoque = Banco.ObterVersaoEstoque(), produtos = Banco.ObterVersaoProdutos() });
}

public sealed class PushSyncRequest
{
    public List<OperacaoSync> Operacoes { get; set; } = new();
}

public sealed class OperacaoSync
{
    public string Tipo { get; set; } = string.Empty;
    public string ClientUuid { get; set; } = string.Empty;
    public Dictionary<string, object> Payload { get; set; } = new();

    private JsonElement? Element(string key) =>
        Payload.TryGetValue(key, out var value) && value is JsonElement je ? je : null;

    public int GetInt(string key) => Element(key)?.GetInt32() ?? 0;

    public int? GetNullableInt(string key)
    {
        var element = Element(key);
        return element.HasValue && element.Value.ValueKind != JsonValueKind.Null
            ? element.Value.GetInt32()
            : null;
    }

    public string? GetString(string key)
    {
        var element = Element(key);
        return element.HasValue && element.Value.ValueKind != JsonValueKind.Null
            ? element.Value.GetString()
            : null;
    }

    public List<SaleItemData> GetItens(string key)
    {
        var element = Element(key);
        var lista = new List<SaleItemData>();
        if (element.HasValue && element.Value.ValueKind == JsonValueKind.Array)
        {
            foreach (var item in element.Value.EnumerateArray())
            {
                lista.Add(new SaleItemData
                {
                    ProdutoId = item.GetProperty("produtoId").GetInt32(),
                    Quantidade = item.GetProperty("quantidade").GetInt32()
                });
            }
        }
        return lista;
    }
}

using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace InfiniteCoffee2.Controllers.Api;

[ApiController]
[Route("api/addam")]
public sealed class AddamApiController : ControllerBase
{
    private const int TamanhoMaximoMensagem = 500;
    private const int MaximoMensagensHistorico = 6;
    private const int MaximoCaracteresHistorico = 2000;
    private const int MaximoProdutosContexto = 20;
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly IConfiguration _configuration;

    public AddamApiController(IHttpClientFactory httpClientFactory, IConfiguration configuration)
    {
        _httpClientFactory = httpClientFactory;
        _configuration = configuration;
    }

    /// <summary>
    /// Encaminha uma pergunta e um catálogo mínimo ao serviço Qwen local. Pode devolver uma proposta
    /// estruturada; o app pede confirmação e executa a ação pelas APIs normais, nunca por SQL livre.
    /// </summary>
    [HttpPost("chat")]
    [EnableRateLimiting("AddamChat")]
    [RequestSizeLimit(32768)]
    public async Task<IActionResult> Chat(
        [FromBody] AddamChatRequest request,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.Mensagem) || request.Mensagem.Trim().Length > TamanhoMaximoMensagem)
            return BadRequest(new { mensagem = "Escreva uma mensagem de até 500 caracteres." });

        var historico = request.Historico ?? [];
        if (historico.Count > MaximoMensagensHistorico)
            return BadRequest(new { mensagem = "O histórico da conversa é muito longo." });

        var totalCaracteresHistorico = 0;
        foreach (var item in historico)
        {
            if (item is null ||
                (item.Role != "user" && item.Role != "assistant") ||
                string.IsNullOrWhiteSpace(item.Content) ||
                item.Content.Trim().Length > TamanhoMaximoMensagem)
            {
                return BadRequest(new { mensagem = "O histórico da conversa é inválido." });
            }

            totalCaracteresHistorico += item.Content.Trim().Length;
            if (totalCaracteresHistorico > MaximoCaracteresHistorico)
                return BadRequest(new { mensagem = "O histórico da conversa é muito longo." });
        }

        var produtos = request.Catalogo ?? [];
        if (produtos.Count > MaximoProdutosContexto || produtos.Any(produto =>
                produto is null || produto.Id <= 0 || string.IsNullOrWhiteSpace(produto.Nome) ||
                produto.Nome.Trim().Length > 100 || (produto.Tipo?.Length ?? 0) > 50 ||
                (produto.Descricao?.Length ?? 0) > 500 || (produto.CodigoBarras?.Length ?? 0) > 50 ||
                produto.Quantidade < 0 || produto.Preco < 0))
            return BadRequest(new { mensagem = "O contexto de estoque enviado pelo app é inválido." });

        var baseUrl = Environment.GetEnvironmentVariable("ADDAM_SERVICE_URL")
                      ?? _configuration["Addam:ServiceUrl"]
                      ?? "http://127.0.0.1:8091";
        if (!Uri.TryCreate(baseUrl, UriKind.Absolute, out var serviceBase) || !serviceBase.IsLoopback)
            return StatusCode(StatusCodes.Status503ServiceUnavailable, new
            {
                mensagem = "O serviço local do Addam não está configurado."
            });

        var client = _httpClientFactory.CreateClient("AddamPython");
        var endpoint = new Uri(serviceBase, "/chat");
        try
        {
            var requestJson = JsonSerializer.Serialize(new
            {
                message = request.Mensagem.Trim(),
                history = historico.Select(item => new
                {
                    role = item.Role,
                    content = item.Content.Trim()
                }),
                catalog = produtos.Select(produto => new
                {
                    id = produto.Id,
                    nome = produto.Nome.Trim(),
                    tipo = produto.Tipo ?? string.Empty,
                    quantidade = produto.Quantidade,
                    preco = produto.Preco,
                    descricao = produto.Descricao ?? string.Empty,
                    codigoBarras = produto.CodigoBarras ?? string.Empty
                })
            });
            using var content = new StringContent(requestJson, Encoding.UTF8, "application/json");
            using var response = await client.PostAsync(endpoint, content, cancellationToken);

            if (!response.IsSuccessStatusCode)
                return StatusCode(StatusCodes.Status503ServiceUnavailable, new
                {
                    mensagem = "O Addam não conseguiu responder agora. Tente novamente."
                });

            var pythonResponse = await response.Content.ReadFromJsonAsync<AddamPythonResponse>(
                cancellationToken: cancellationToken);
            if (pythonResponse is null || string.IsNullOrWhiteSpace(pythonResponse.Reply))
                return StatusCode(StatusCodes.Status503ServiceUnavailable, new
                {
                    mensagem = "O serviço do Addam retornou uma resposta inválida."
                });

            var reply = pythonResponse.Reply.Trim();
            var suggestions = (pythonResponse.Suggestions ?? [])
                .Where(item => !string.IsNullOrWhiteSpace(item))
                .Select(item => item.Trim())
                .Where(item => item.Length <= 80)
                .Take(4)
                .ToArray();

            var action = ValidarAcao(pythonResponse.Action);
            return Ok(new AddamChatResponse(
                "Addam",
                reply[..Math.Min(reply.Length, 2000)],
                suggestions,
                action));
        }
        catch (HttpRequestException)
        {
            return StatusCode(StatusCodes.Status503ServiceUnavailable, new
            {
                mensagem = "O serviço local do Addam está indisponível."
            });
        }
        catch (TaskCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            return StatusCode(StatusCodes.Status503ServiceUnavailable, new
            {
                mensagem = "O Addam demorou para responder. Tente novamente."
            });
        }
        catch (JsonException)
        {
            return StatusCode(StatusCodes.Status503ServiceUnavailable, new
            {
                mensagem = "O serviço local do Addam retornou dados inválidos."
            });
        }
    }

    public sealed class AddamChatRequest
    {
        public string Mensagem { get; set; } = string.Empty;
        public List<AddamChatHistoryMessage> Historico { get; set; } = [];
        public List<AddamStockProductContext> Catalogo { get; set; } = [];
    }

    public sealed class AddamChatHistoryMessage
    {
        public string Role { get; set; } = string.Empty;
        public string Content { get; set; } = string.Empty;
    }

    public sealed class AddamStockProductContext
    {
        public int Id { get; set; }
        public string Nome { get; set; } = string.Empty;
        public string? Tipo { get; set; }
        public int Quantidade { get; set; }
        public decimal Preco { get; set; }
        public string? Descricao { get; set; }
        public string? CodigoBarras { get; set; }
    }

    private static AddamActionDraftResponse? ValidarAcao(JsonElement? action)
    {
        if (!action.HasValue || action.Value.ValueKind != JsonValueKind.Object)
            return null;

        var value = action.Value;
        if (
            !value.TryGetProperty("type", out var tipoElemento) ||
            tipoElemento.ValueKind != JsonValueKind.String ||
            !value.TryGetProperty("fields", out var campos) ||
            campos.ValueKind != JsonValueKind.Object ||
            value.GetRawText().Length > 4096)
            return null;

        var tipo = tipoElemento.GetString();
        var camposPermitidos = tipo switch
        {
            "create_customer" => new HashSet<string>(["nome", "email"]),
            "update_customer" => new HashSet<string>(["id_cliente", "nome", "email"]),
            "create_product" => new HashSet<string>(["nome", "tipo", "preco", "quantidade", "descricao", "codigoBarras"]),
            "stock_entry" or "stock_exit" => new HashSet<string>(["produtoId", "produtoNome", "quantidade", "motivo"]),
            "update_product" => new HashSet<string>(["id_produto", "nome", "tipo", "preco", "descricao", "codigoBarras"]),
            "create_employee" => new HashSet<string>(["nome", "cargo"]),
            "update_employee" => new HashSet<string>(["id_funcionario", "nome", "cargo"]),
            "create_table" => new HashSet<string>(["numero", "capacidade"]),
            "update_table" => new HashSet<string>(["id_mesa", "numero", "capacidade"]),
            "create_sale" => new HashSet<string>(["clienteNome", "formaPagamento", "itens"]),
            _ => null
        };
        if (camposPermitidos is null) return null;

        var validos = new Dictionary<string, JsonElement>();
        foreach (var campo in campos.EnumerateObject())
            if (camposPermitidos.Contains(campo.Name))
                validos[campo.Name] = campo.Value.Clone();
        if (validos.Count == 0) return null;

        return new AddamActionDraftResponse(tipo!, validos);
    }

    public sealed record AddamChatResponse(
        string Assistant,
        string Reply,
        string[] Suggestions,
        AddamActionDraftResponse? Action);

    public sealed record AddamActionDraftResponse(
        string Type,
        Dictionary<string, JsonElement> Fields);
}

public sealed class AddamPythonResponse
{
    public string Assistant { get; set; } = "Addam";
    public string Reply { get; set; } = string.Empty;
    public List<string>? Suggestions { get; set; } = [];
    public JsonElement? Action { get; set; }
}

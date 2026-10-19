using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace InfiniteCoffee2.Controllers.Api;

[ApiController]
[Route("api/addam")]
public sealed class AddamApiController : ControllerBase
{
    private const int TamanhoMaximoMensagem = 500;
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly IConfiguration _configuration;

    public AddamApiController(IHttpClientFactory httpClientFactory, IConfiguration configuration)
    {
        _httpClientFactory = httpClientFactory;
        _configuration = configuration;
    }

    /// <summary>
    /// Encaminha uma pergunta para o serviço Python local. Esta versão é somente informativa:
    /// não consulta o banco, não executa ações e não envia dados para um LLM externo.
    /// </summary>
    [HttpPost("chat")]
    [EnableRateLimiting("AddamChat")]
    [RequestSizeLimit(4096)]
    public async Task<IActionResult> Chat(
        [FromBody] AddamChatRequest request,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.Mensagem) || request.Mensagem.Trim().Length > TamanhoMaximoMensagem)
            return BadRequest(new { mensagem = "Escreva uma mensagem de até 500 caracteres." });

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
            using var response = await client.PostAsJsonAsync(
                endpoint,
                new { message = request.Mensagem.Trim() },
                cancellationToken);

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

            return Ok(new AddamChatResponse(
                "Addam",
                reply[..Math.Min(reply.Length, 2000)],
                suggestions));
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
    }

    private sealed class AddamPythonResponse
    {
        public string Assistant { get; set; } = "Addam";
        public string Reply { get; set; } = string.Empty;
        public List<string>? Suggestions { get; set; } = [];
    }

    public sealed record AddamChatResponse(string Assistant, string Reply, string[] Suggestions);
}

using System.Security.Cryptography;
using System.Text;

namespace InfiniteCoffee2.Middleware;

public sealed class ApiKeyMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<ApiKeyMiddleware> _logger;

    public ApiKeyMiddleware(RequestDelegate next, ILogger<ApiKeyMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        if (!context.Request.Path.StartsWithSegments("/api") ||
            context.Request.Path.StartsWithSegments("/api/health"))
        {
            await _next(context);
            return;
        }

        var configuredToken = Environment.GetEnvironmentVariable("PADARIA_API_TOKEN");
        var readOnlyToken = Environment.GetEnvironmentVariable("PADARIA_READONLY_TOKEN");
        var mobileWriteToken = Environment.GetEnvironmentVariable("PADARIA_MOBILE_WRITE_TOKEN");
        var publicApi = string.Equals(
            Environment.GetEnvironmentVariable("PADARIA_PUBLIC_API"),
            "true",
            StringComparison.OrdinalIgnoreCase);
        var suppliedToken = context.Request.Headers["X-Api-Key"].FirstOrDefault();
        if (string.IsNullOrWhiteSpace(suppliedToken))
            suppliedToken = context.Request.Headers.Authorization.FirstOrDefault()?.Replace("Bearer ", "", StringComparison.OrdinalIgnoreCase);

        // Sem token configurado, a API só fica disponível para o próprio PC.
        // Isso mantém o desenvolvimento local funcional sem deixar o túnel público aberto.
        var loopback = context.Connection.RemoteIpAddress is { } remoteIp &&
                       System.Net.IPAddress.IsLoopback(remoteIp);
        var writeRequest = !HttpMethods.IsGet(context.Request.Method) &&
                           !HttpMethods.IsHead(context.Request.Method) &&
                           !HttpMethods.IsOptions(context.Request.Method);
        var noTokensConfigured = string.IsNullOrWhiteSpace(configuredToken) &&
                                 string.IsNullOrWhiteSpace(readOnlyToken) &&
                                 string.IsNullOrWhiteSpace(mobileWriteToken);
        var authorized = publicApi || noTokensConfigured
            ? true
            : string.IsNullOrWhiteSpace(configuredToken)
              ? string.IsNullOrWhiteSpace(readOnlyToken) && loopback
            : Matches(suppliedToken, configuredToken) ||
              (!writeRequest && Matches(suppliedToken, readOnlyToken)) ||
              Matches(suppliedToken, mobileWriteToken);

        if (!authorized)
        {
            _logger.LogWarning("Acesso não autorizado à API em {Path}.", context.Request.Path);
            context.Response.StatusCode = StatusCodes.Status401Unauthorized;
            await context.Response.WriteAsJsonAsync(new { mensagem = "API não autorizada." });
            return;
        }

        await _next(context);
    }

    private static bool Matches(string? supplied, string? expected)
    {
        if (string.IsNullOrWhiteSpace(supplied) || string.IsNullOrWhiteSpace(expected))
            return false;
        var suppliedBytes = Encoding.UTF8.GetBytes(supplied);
        var expectedBytes = Encoding.UTF8.GetBytes(expected);
        return suppliedBytes.Length == expectedBytes.Length &&
               CryptographicOperations.FixedTimeEquals(suppliedBytes, expectedBytes);
    }
}

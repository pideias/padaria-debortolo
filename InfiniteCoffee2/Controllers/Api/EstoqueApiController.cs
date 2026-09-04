using InfiniteCoffee2.Data;
using InfiniteCoffee2.Services;
using Microsoft.AspNetCore.Mvc;

namespace InfiniteCoffee2.Controllers.Api;

[ApiController]
[Route("api/estoque")]
public sealed class EstoqueApiController : ControllerBase
{
    private readonly GoogleDriveSnapshotStore _snapshotStore;
    private readonly GoogleDriveSnapshotHostedService _snapshotPublisher;

    public EstoqueApiController(GoogleDriveSnapshotStore snapshotStore, GoogleDriveSnapshotHostedService snapshotPublisher)
    {
        _snapshotStore = snapshotStore;
        _snapshotPublisher = snapshotPublisher;
    }

    /// <summary>Lista o estoque e permite pesquisar por nome ou código de barras.</summary>
    [HttpGet]
    public async Task<IActionResult> Listar([FromQuery] string? busca = null)
    {
        if (IsSnapshotOnly())
            return Ok(await ProdutosDoSnapshotAsync(busca));
        return Ok(Banco.ListarEstoque(busca ?? string.Empty));
    }

    /// <summary>Lista os produtos que estão abaixo do limite de estoque.</summary>
    [HttpGet("baixo")]
    public IActionResult EstoqueBaixo([FromQuery] int limite = 5)
    {
        if (limite < 0) return BadRequest(new { mensagem = "O limite não pode ser negativo." });
        return Ok(Banco.ListarEstoqueBaixo(limite));
    }

    /// <summary>Impressão digital do estoque. Use no front para recarregar só quando houver mudança.</summary>
    [HttpGet("versao")]
    public IActionResult Versao() => Ok(new { versao = Banco.ObterVersaoEstoque() });

    [HttpPost("backup")]
    public async Task<IActionResult> Backup()
    {
        if (IsSnapshotOnly())
            return StatusCode(StatusCodes.Status503ServiceUnavailable, new { mensagem = "O backup deve ser executado pela API central que acessa o SQL Server." });
        return await _snapshotPublisher.PublicarAgoraAsync()
            ? Ok(new { mensagem = "Backup enviado para o Google Drive." })
            : StatusCode(StatusCodes.Status503ServiceUnavailable, new { mensagem = "Configure GOOGLE_DRIVE_SERVICE_ACCOUNT_JSON e GOOGLE_DRIVE_FOLDER_ID no servidor." });
    }

    /// <summary>Retorna uma fotografia versionada do estoque para clientes de consulta.</summary>
    [HttpGet("snapshot")]
    public async Task<IActionResult> Snapshot()
    {
        if (IsSnapshotOnly())
            return Ok(await _snapshotStore.GetAsync());
        return Ok(new
        {
            versao = Banco.ObterVersaoEstoque(),
            atualizadoEm = DateTime.UtcNow,
            produtos = Banco.ListarEstoque()
        });
    }

    private static bool IsSnapshotOnly() =>
        string.Equals(Environment.GetEnvironmentVariable("PADARIA_SNAPSHOT_ONLY"), "true", StringComparison.OrdinalIgnoreCase);

    private async Task<object> ProdutosDoSnapshotAsync(string? busca)
    {
        var snapshot = await _snapshotStore.GetAsync();
        if (!snapshot.TryGetProperty("produtos", out var produtos))
            return Array.Empty<object>();

        var termo = (busca ?? string.Empty).Trim();
        if (termo.Length == 0)
            return produtos;

        return produtos.EnumerateArray()
            .Where(item => item.TryGetProperty("nome_produto", out var nome) &&
                          nome.GetString()?.Contains(termo, StringComparison.OrdinalIgnoreCase) == true)
            .ToArray();
    }

    /// <summary>Registra uma saída e reduz o saldo de forma transacional.</summary>
    [HttpPost("saida")]
    public IActionResult Saida([FromBody] SaidaEstoqueRequest request)
    {
        if (request.Quantidade < 1 || string.IsNullOrWhiteSpace(request.Motivo) || request.Motivo.Length > 200)
            return BadRequest(new { mensagem = "Informe uma quantidade válida e um motivo de até 200 caracteres." });
        if (IsSnapshotOnly())
            return StatusCode(StatusCodes.Status503ServiceUnavailable, new { mensagem = "Esta API está em modo consulta. A alteração deve ser enviada à API que acessa o SQL Server." });

        if (!Banco.RegistrarSaidaEstoque(request.ProdutoId, request.Quantidade, request.Motivo))
            return BadRequest(new { mensagem = "Produto inexistente ou estoque insuficiente." });

        return Ok(new { mensagem = "Saída registrada com sucesso." });
    }

    /// <summary>Registra uma entrada e aumenta o saldo de forma transacional.</summary>
    [HttpPost("entrada")]
    public IActionResult Entrada([FromBody] EntradaEstoqueRequest request)
    {
        if (request.Quantidade < 1 || string.IsNullOrWhiteSpace(request.Motivo) || request.Motivo.Length > 200)
            return BadRequest(new { mensagem = "Informe uma quantidade válida e um motivo de até 200 caracteres." });
        if (IsSnapshotOnly())
            return StatusCode(StatusCodes.Status503ServiceUnavailable, new { mensagem = "Esta API está em modo consulta. A alteração deve ser enviada à API que acessa o SQL Server." });
        if (!Banco.RegistrarEntradaEstoque(request.ProdutoId, request.Quantidade, request.Motivo))
            return BadRequest(new { mensagem = "Produto inexistente." });
        return Ok(new { mensagem = "Entrada registrada com sucesso." });
    }
}

public sealed class SaidaEstoqueRequest
{
    public int ProdutoId { get; set; }
    public int Quantidade { get; set; }
    public string Motivo { get; set; } = string.Empty;
}

public sealed class EntradaEstoqueRequest
{
    public int ProdutoId { get; set; }
    public int Quantidade { get; set; }
    public string Motivo { get; set; } = string.Empty;
}

using InfiniteCoffee2.Data;
using Microsoft.AspNetCore.Mvc;

namespace InfiniteCoffee2.Controllers.Api;

[ApiController]
[Route("api/estoque")]
public sealed class EstoqueApiController : ControllerBase
{
    /// <summary>Lista o estoque e permite pesquisar por nome ou código de barras.</summary>
    [HttpGet]
    public IActionResult Listar([FromQuery] string? busca = null)
    {
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

    /// <summary>Registra uma saída e reduz o saldo de forma transacional.</summary>
    [HttpPost("saida")]
    public IActionResult Saida([FromBody] SaidaEstoqueRequest request)
    {
        if (request.Quantidade < 1 || string.IsNullOrWhiteSpace(request.Motivo) || request.Motivo.Length > 200)
            return BadRequest(new { mensagem = "Informe uma quantidade válida e um motivo de até 200 caracteres." });
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

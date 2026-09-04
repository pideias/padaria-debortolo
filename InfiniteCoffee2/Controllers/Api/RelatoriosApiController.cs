using InfiniteCoffee2.Data;
using Microsoft.AspNetCore.Mvc;

namespace InfiniteCoffee2.Controllers.Api;

[ApiController]
[Route("api/relatorios")]
public sealed class RelatoriosApiController : ControllerBase
{
    /// <summary>Retorna indicadores de vendas do dia atual.</summary>
    [HttpGet("vendas")]
    public IActionResult Vendas() => Ok(Banco.ResumoVendas());

    [HttpGet("vendas/historico")]
    public IActionResult HistoricoVendas([FromQuery] int limite = 200) => Ok(Banco.HistoricoVendas(limite));

    /// <summary>Retorna os produtos e alertas do estoque atual.</summary>
    [HttpGet("estoque")]
    public IActionResult Estoque() => Ok(new { produtos = Banco.ListarEstoque(), alertas = Banco.ListarEstoqueBaixo() });
}

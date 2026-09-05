using InfiniteCoffee2.Data;
using InfiniteCoffee2.Models;
using Microsoft.AspNetCore.Mvc;

namespace InfiniteCoffee2.Controllers.Api;

[ApiController]
[Route("api/vendas")]
public sealed class VendasApiController : ControllerBase
{
    /// <summary>Cria pedido, itens, pagamento e baixa estoque em uma única transação.</summary>
    [HttpPost]
    public IActionResult Criar([FromBody] CriarVendaRequest request)
    {
        if (request.Itens.Count == 0 || string.IsNullOrWhiteSpace(request.FormaPagamento))
            return BadRequest(new { mensagem = "A venda precisa ter itens e forma de pagamento." });
        if (request.Itens.Any(item => item.Quantidade < 1))
            return BadRequest(new { mensagem = "As quantidades devem ser maiores que zero." });

        var pedidoId = Banco.FinalizarVenda(request.ClienteId, request.MesaId, request.FuncionarioId, request.FormaPagamento, request.Itens, request.ClienteNome);
        return pedidoId == 0
            ? BadRequest(new { mensagem = "Não foi possível finalizar. Verifique os produtos e o estoque." })
            : StatusCode(StatusCodes.Status201Created, new { pedidoId, mensagem = "Venda finalizada com sucesso." });
    }
}

public sealed class CriarVendaRequest
{
    public int? ClienteId { get; set; }
    public string? ClienteNome { get; set; }
    public int? MesaId { get; set; }
    public int? FuncionarioId { get; set; }
    public string FormaPagamento { get; set; } = string.Empty;
    public List<SaleItemData> Itens { get; set; } = [];
}

using InfiniteCoffee2.Data;
using Microsoft.AspNetCore.Mvc;

namespace InfiniteCoffee2.Controllers.Api;

[ApiController]
[Route("api/produtos")]
public sealed class ProdutosApiController : ControllerBase
{
    /// <summary>Lista os produtos cadastrados.</summary>
    [HttpGet]
    public IActionResult Listar() => Ok(Banco.ListarProdutos());

    /// <summary>Impressão digital dos produtos. Use no front para recarregar só quando houver mudança.</summary>
    [HttpGet("versao")]
    public IActionResult Versao() => Ok(new { versao = Banco.ObterVersaoProdutos() });

    /// <summary>Exclui um produto e suas movimentações de estoque. Falha se houver vendas vinculadas.</summary>
    [HttpDelete("{id:int}")]
    public IActionResult Excluir(int id)
    {
        if (!Banco.ExcluirProduto(id))
            return BadRequest(new { mensagem = "Nao foi possivel excluir. O produto pode estar vinculado a vendas." });
        return Ok(new { mensagem = "Produto excluido com sucesso." });
    }

    /// <summary>Cadastra um produto com seu estoque inicial.</summary>
    [HttpPost]
    public IActionResult Cadastrar([FromBody] CriarProdutoRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Nome) || request.Nome.Length > 100 || request.Preco <= 0 || request.Quantidade < 0 || request.Tipo.Length > 50 || request.Descricao?.Length > 500 || request.CodigoBarras?.Length > 50)
            return BadRequest(new { mensagem = "Informe dados válidos para o produto." });

        Banco.CadastrarProduto(request.Nome.Trim(), request.Preco, request.Tipo.Trim(), request.Quantidade, request.CodigoBarras ?? string.Empty, request.Descricao ?? string.Empty);
        return StatusCode(StatusCodes.Status201Created, new { mensagem = "Produto cadastrado com sucesso." });
    }

    [HttpPut("{id:int}")]
    public IActionResult Editar(int id, [FromBody] EditarProdutoRequest request)
    {
        if (id <= 0 || string.IsNullOrWhiteSpace(request.Nome) || request.Nome.Length > 100 ||
            request.Preco <= 0 || string.IsNullOrWhiteSpace(request.Tipo) || request.Tipo.Length > 50 ||
            request.Descricao?.Length > 500 || request.CodigoBarras?.Length > 50)
            return BadRequest(new { mensagem = "Informe dados válidos para o produto." });

        if (!Banco.AtualizarDadosProduto(id, request.Nome, request.Preco, request.Tipo,
                request.CodigoBarras ?? string.Empty, request.Descricao ?? string.Empty))
            return NotFound(new { mensagem = "Produto não encontrado ou inativo." });

        return Ok(new { mensagem = "Produto atualizado com sucesso." });
    }
}

public sealed class CriarProdutoRequest
{
    public string Nome { get; set; } = string.Empty;
    public string? Descricao { get; set; }
    public string? CodigoBarras { get; set; }
    public string Tipo { get; set; } = "Produto";
    public decimal Preco { get; set; }
    public int Quantidade { get; set; }
}

public sealed class EditarProdutoRequest
{
    public string Nome { get; set; } = string.Empty;
    public string? Descricao { get; set; }
    public string? CodigoBarras { get; set; }
    public string Tipo { get; set; } = "Produto";
    public decimal Preco { get; set; }
}

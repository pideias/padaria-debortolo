namespace InfiniteCoffee2.Models;

public sealed class ConfirmacaoAtendimentoViewModel
{
    public int PedidoId { get; set; }
    public string ClienteNome { get; set; } = string.Empty;
    public string ClienteEmail { get; set; } = string.Empty;
    public string Mesa { get; set; } = string.Empty;
    public string FormaPagamento { get; set; } = string.Empty;
    public decimal Total { get; set; }
    public List<ItemConfirmacaoViewModel> Itens { get; set; } = new();
}

public sealed class ItemConfirmacaoViewModel
{
    public string Nome { get; set; } = string.Empty;
    public int Quantidade { get; set; }
    public decimal Subtotal { get; set; }
}

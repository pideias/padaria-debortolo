using InfiniteCoffee2.Data;
using InfiniteCoffee2.Models;
using Microsoft.AspNetCore.Mvc;
using System.Text.Json;

namespace InfiniteCoffee2.Controllers
{
    // Esse controller controla o fluxo completo de um novo atendimento.
    // Usamos Session para guardar os dados entre as etapas (clienteId, mesaId, pedidoId).
    public class AtendimentoController : Controller
    {
        // ── ETAPA 1: Escolher ou cadastrar cliente ──────────────────────────
        public IActionResult Index()
        {
            if ((HttpContext.Session.GetInt32("pedidoId") ?? 0) > 0)
                return RedirectToAction(nameof(AdicionarItens));

            ViewBag.Clientes = Banco.ListarClientes();
            return View();
        }

        [HttpPost]
        public IActionResult SelecionarCliente(int clienteId)
        {
            HttpContext.Session.SetInt32("clienteId", clienteId);
            return RedirectToAction("EscolherMesa");
        }

        [HttpPost]
        public IActionResult CadastrarCliente(string nome, string email)
        {
            if (string.IsNullOrWhiteSpace(nome) || string.IsNullOrWhiteSpace(email))
            {
                TempData["Mensagem"] = "Informe nome e email para continuar.";
                return RedirectToAction("Index");
            }

            var cliente = Banco.BuscarClientePorNomeEmail(nome, email);
            if (cliente == null)
            {
                Banco.CadastrarCliente(nome.Trim(), email.Trim(), string.Empty);
                cliente = Banco.BuscarClientePorNomeEmail(nome, email);
            }

            var clienteId = Convert.ToInt32(cliente?["id_cliente"] ?? 0);
            if (clienteId == 0)
            {
                TempData["Mensagem"] = "Não foi possível identificar o cliente.";
                return RedirectToAction("Index");
            }

            HttpContext.Session.SetInt32("clienteId", clienteId);
            return RedirectToAction("EscolherMesa");
        }

        // ── ETAPA 2: Escolher mesa ──────────────────────────────────────────
        public IActionResult EscolherMesa()
        {
            if ((HttpContext.Session.GetInt32("pedidoId") ?? 0) > 0)
                return RedirectToAction(nameof(AdicionarItens));
            if ((HttpContext.Session.GetInt32("clienteId") ?? 0) <= 0)
                return RedirectToAction(nameof(Index));

            ViewBag.Mesas = Banco.ListarMesas();
            return View();
        }

        [HttpPost]
        public IActionResult SelecionarMesa(int mesaId)
        {
            if ((HttpContext.Session.GetInt32("pedidoId") ?? 0) > 0)
                return RedirectToAction(nameof(AdicionarItens));

            var clienteId    = HttpContext.Session.GetInt32("clienteId") ?? 0;
            if (clienteId <= 0 || mesaId <= 0)
            {
                TempData["Mensagem"] = "Selecione um cliente e uma mesa válidos para continuar.";
                return RedirectToAction(nameof(Index));
            }

            HttpContext.Session.SetInt32("mesaId", mesaId);
            Banco.AtualizarStatusMesa(mesaId, "Ocupada");
            var pedidoId     = Banco.CriarPedido(mesaId, null, clienteId);
            if (pedidoId <= 0)
            {
                Banco.AtualizarStatusMesa(mesaId, "Disponível");
                HttpContext.Session.Remove("mesaId");
                TempData["Mensagem"] = "Não foi possível iniciar o pedido. Tente novamente.";
                return RedirectToAction(nameof(EscolherMesa));
            }

            HttpContext.Session.SetInt32("pedidoId", pedidoId);
            return RedirectToAction("AdicionarItens");
        }

        // ── ETAPA 4: Adicionar itens ────────────────────────────────────────
        public IActionResult AdicionarItens()
        {
            var pedidoId = HttpContext.Session.GetInt32("pedidoId") ?? 0;
            if (pedidoId <= 0)
            {
                TempData["Mensagem"] = "Nenhum atendimento ativo. Inicie um novo pedido.";
                return RedirectToAction(nameof(Index));
            }

            ViewBag.Produtos = Banco.ListarProdutos();
            ViewBag.PedidoId = pedidoId;
            ViewBag.ItensPedido = Banco.ListarItensPedido(pedidoId);
            ViewBag.Total = Banco.CalcularTotalPedido(pedidoId);
            return View();
        }

        [HttpPost]
        public IActionResult AdicionarItem(int produtoId, int quantidade)
        {
            var pedidoId = HttpContext.Session.GetInt32("pedidoId") ?? 0;
            if (pedidoId <= 0)
            {
                TempData["Mensagem"] = "Nenhum atendimento ativo. Inicie um novo pedido.";
                return RedirectToAction(nameof(Index));
            }

            if (produtoId <= 0 || quantidade < 1)
            {
                TempData["Mensagem"] = "Informe um produto e uma quantidade válida.";
                return RedirectToAction(nameof(AdicionarItens));
            }

            if (!Banco.AdicionarItemPedido(pedidoId, produtoId, quantidade, out var disponivel))
            {
                TempData["Mensagem"] = disponivel >= 0
                    ? $"Quantidade acima do estoque disponível para este pedido. Disponível: {disponivel} unidade(s)."
                    : "O pedido não está aberto ou o produto não está disponível.";
                return RedirectToAction(nameof(AdicionarItens));
            }

            TempData["Mensagem"] = "Item adicionado!";
            return RedirectToAction(nameof(AdicionarItens));
        }

        [HttpPost]
        public IActionResult RemoverItem(int produtoId)
        {
            var pedidoId = HttpContext.Session.GetInt32("pedidoId") ?? 0;
            if (pedidoId > 0 && produtoId > 0)
                Banco.RemoverItemPedido(pedidoId, produtoId);
            return RedirectToAction("AdicionarItens");
        }

        // ── ETAPA 5: Pagamento e finalização ────────────────────────────────
        public IActionResult Pagamento()
        {
            var pedidoId = HttpContext.Session.GetInt32("pedidoId") ?? 0;
            if (pedidoId <= 0)
            {
                TempData["Mensagem"] = "Nenhum atendimento ativo. Inicie um novo pedido.";
                return RedirectToAction(nameof(Index));
            }

            var total    = Banco.CalcularTotalPedido(pedidoId);
            var itens    = Banco.ListarItensPedido(pedidoId);
            if (itens.Count == 0)
            {
                TempData["Mensagem"] = "Adicione pelo menos um item antes de ir para o pagamento.";
                return RedirectToAction("AdicionarItens");
            }

            ViewBag.Total    = total;
            ViewBag.PedidoId = pedidoId;
            ViewBag.ItensPedido = itens;
            return View();
        }

        [HttpPost]
        public IActionResult Cancelar()
        {
            // Requisições sem formulário, como beacons antigos de pagehide, não cancelam pedidos.
            // Só o formulário explícito de cancelamento pode apagar o pedido em aberto.
            if (!Request.HasFormContentType)
                return NoContent();

            var pedidoId = HttpContext.Session.GetInt32("pedidoId") ?? 0;
            var mesaId = HttpContext.Session.GetInt32("mesaId") ?? 0;
            if (pedidoId > 0 && mesaId > 0)
                Banco.CancelarAtendimento(pedidoId, mesaId);
            HttpContext.Session.Clear();
            return NoContent();
        }

        [HttpPost]
        public IActionResult Finalizar(string forma)
        {
            var pedidoId = HttpContext.Session.GetInt32("pedidoId") ?? 0;
            var mesaId   = HttpContext.Session.GetInt32("mesaId") ?? 0;
            var clienteId = HttpContext.Session.GetInt32("clienteId") ?? 0;

            if (pedidoId <= 0 || mesaId <= 0)
            {
                TempData["Mensagem"] = "O atendimento expirou. Confira o pedido e tente novamente.";
                return RedirectToAction(nameof(Index));
            }

            var cliente = Banco.BuscarClientePorId(clienteId);
            if (!Banco.FinalizarAtendimento(pedidoId, forma, out var mensagem))
            {
                TempData["Mensagem"] = mensagem;
                return RedirectToAction(nameof(AdicionarItens));
            }

            var total = Banco.CalcularTotalPedido(pedidoId);
            var itens = Banco.ListarItensPedido(pedidoId)
                .Select(item => new ItemConfirmacaoViewModel
                {
                    Nome = item["nome_produto"].ToString() ?? string.Empty,
                    Quantidade = Convert.ToInt32(item["quantidade"]),
                    Subtotal = Convert.ToDecimal(item["subtotal"])
                }).ToList();

            var confirmacao = new ConfirmacaoAtendimentoViewModel
            {
                PedidoId = pedidoId,
                ClienteNome = cliente?["nome_cliente"].ToString() ?? "Cliente",
                ClienteEmail = cliente?["email"].ToString() ?? string.Empty,
                Mesa = $"Mesa {mesaId}",
                FormaPagamento = forma,
                Total = total,
                Itens = itens
            };
            HttpContext.Session.Clear();
            TempData["Confirmacao"] = JsonSerializer.Serialize(confirmacao);
            return RedirectToAction("Sucesso");
        }

        public IActionResult Sucesso()
        {
            var json = TempData["Confirmacao"] as string;
            var confirmacao = string.IsNullOrWhiteSpace(json)
                ? new ConfirmacaoAtendimentoViewModel()
                : JsonSerializer.Deserialize<ConfirmacaoAtendimentoViewModel>(json) ?? new ConfirmacaoAtendimentoViewModel();
            return View(confirmacao);
        }
    }
}

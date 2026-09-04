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
            HttpContext.Session.Clear(); // limpa qualquer atendimento anterior
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
            ViewBag.Mesas = Banco.ListarMesas();
            return View();
        }

        [HttpPost]
        public IActionResult SelecionarMesa(int mesaId)
        {
            HttpContext.Session.SetInt32("mesaId", mesaId);
            Banco.AtualizarStatusMesa(mesaId, "Ocupada");
            var clienteId    = HttpContext.Session.GetInt32("clienteId") ?? 0;
            var pedidoId     = Banco.CriarPedido(mesaId, null, clienteId);
            HttpContext.Session.SetInt32("pedidoId", pedidoId);
            return RedirectToAction("AdicionarItens");
        }

        // ── ETAPA 4: Adicionar itens ────────────────────────────────────────
        public IActionResult AdicionarItens()
        {
            ViewBag.Produtos = Banco.ListarProdutos();
            var pedidoId = HttpContext.Session.GetInt32("pedidoId") ?? 0;
            ViewBag.PedidoId = pedidoId;
            ViewBag.ItensPedido = Banco.ListarItensPedido(pedidoId);
            ViewBag.Total = Banco.CalcularTotalPedido(pedidoId);
            return View();
        }

        [HttpPost]
        public IActionResult AdicionarItem(int produtoId, int quantidade)
        {
            var pedidoId = HttpContext.Session.GetInt32("pedidoId") ?? 0;
            if (pedidoId == 0 || produtoId == 0 || quantidade < 1)
            {
                TempData["Mensagem"] = "Informe um produto e uma quantidade válida.";
                return RedirectToAction("AdicionarItens");
            }

            Banco.AdicionarItemPedido(pedidoId, produtoId, quantidade);
            TempData["Mensagem"] = "Item adicionado!";
            return RedirectToAction("AdicionarItens");
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
            var total    = Banco.CalcularTotalPedido(pedidoId);
            var cliente = Banco.BuscarClientePorId(clienteId);
            var itens = Banco.ListarItensPedido(pedidoId)
                .Select(item => new ItemConfirmacaoViewModel
                {
                    Nome = item["nome_produto"].ToString() ?? string.Empty,
                    Quantidade = Convert.ToInt32(item["quantidade"]),
                    Subtotal = Convert.ToDecimal(item["subtotal"])
                }).ToList();

            Banco.RegistrarPagamento(pedidoId, forma, total);
            Banco.FinalizarPedido(pedidoId);
            Banco.AtualizarStatusMesa(mesaId, "Disponível");

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

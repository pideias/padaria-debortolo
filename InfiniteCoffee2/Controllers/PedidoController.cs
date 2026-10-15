using InfiniteCoffee2.Data;
using Microsoft.AspNetCore.Mvc;

namespace InfiniteCoffee2.Controllers
{
    public class PedidoController : Controller
    {
        public IActionResult Index()
        {
            var pedidos = Banco.ListarPedidosAbertos();
            return View(pedidos);
        }

        [HttpPost]
        public IActionResult Fechar(int pedidoId, int mesaId)
        {
            if (!Banco.FecharPedidoComBaixaEstoque(pedidoId, mesaId, out var mensagem))
            {
                TempData["Mensagem"] = mensagem;
                return RedirectToAction("Index");
            }

            TempData["Mensagem"] = mensagem;
            return RedirectToAction("Index");
        }
    }
}

using InfiniteCoffee2.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace InfiniteCoffee2.Controllers
{
    public class ClienteController : Controller
    {
        public IActionResult Index()
        {
            var clientes = Banco.ListarClientes();
            return View(clientes);
        }

        public IActionResult Buscar(string valor)
        {
            if (string.IsNullOrEmpty(valor))
                return RedirectToAction("Index");

            var resultado = Banco.BuscarCliente(valor);
            ViewBag.Busca = valor;
            return View("Index", resultado);
        }

        public IActionResult Cadastrar() => View();

        [HttpPost]
        public IActionResult Cadastrar(string nome, string email, string telefone)
        {
            Banco.CadastrarCliente(nome, email, telefone);
            TempData["Mensagem"] = "Cliente cadastrado com sucesso!";
            return RedirectToAction("Index");
        }

        public IActionResult Editar(int id)
        {
            var cliente = Banco.BuscarClientePorId(id);
            if (cliente == null) return NotFound();
            return View(cliente);
        }

        [HttpPost]
        public IActionResult Editar(int id, string nome, string email, string telefone)
        {
            Banco.AtualizarCliente(id, nome, email, telefone);
            TempData["Mensagem"] = "Cliente atualizado com sucesso!";
            return RedirectToAction("Index");
        }

        [HttpPost]
        public IActionResult Excluir(int id)
        {
            try
            {
                Banco.ExcluirCliente(id);
                TempData["Mensagem"] = "Cliente excluído.";
            }
            catch (SqlException ex) when (ex.Number == 547)
            {
                TempData["MensagemErro"] = "Este cliente possui pedidos vinculados e não pode ser excluído para preservar o histórico.";
            }

            return RedirectToAction("Index");
        }
    }
}

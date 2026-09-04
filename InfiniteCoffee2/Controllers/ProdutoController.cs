using InfiniteCoffee2.Data;
using Microsoft.AspNetCore.Mvc;

namespace InfiniteCoffee2.Controllers
{
    public class ProdutoController : Controller
    {
        public IActionResult Index()
        {
            var produtos = Banco.ListarProdutos();
            return View(produtos);
        }

        public IActionResult Cadastrar() => View();

        [HttpPost]
        public IActionResult Cadastrar(string nome, decimal preco, string tipo, int quantidade, string codigoBarras, string descricao)
        {
            if (string.IsNullOrWhiteSpace(nome) || preco <= 0 || quantidade < 0 || codigoBarras?.Length > 50 || descricao?.Length > 500)
            {
                TempData["Mensagem"] = "Informe nome, preço, quantidade e dados válidos para o produto.";
                return RedirectToAction("Index");
            }

            Banco.CadastrarProduto(nome.Trim(), preco, tipo.Trim(), quantidade, codigoBarras ?? string.Empty, descricao ?? string.Empty);
            TempData["Mensagem"] = "Produto cadastrado com sucesso!";
            return RedirectToAction("Index");
        }

        public IActionResult Editar(int id)
        {
            var produto = Banco.BuscarProdutoPorId(id);
            if (produto == null) return NotFound();
            return View(produto);
        }

        [HttpPost]
        public IActionResult Editar(int id, string nome, decimal preco, string tipo)
        {
            Banco.AtualizarProduto(id, nome, preco, tipo);
            TempData["Mensagem"] = "Produto atualizado com sucesso!";
            return RedirectToAction("Index");
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public IActionResult Excluir(int id)
        {
            Banco.ExcluirProduto(id);
            TempData["Mensagem"] = "Produto excluído.";
            return RedirectToAction("Index");
        }
    }
}

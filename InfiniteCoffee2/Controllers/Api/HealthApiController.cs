using InfiniteCoffee2.Data;
using Microsoft.AspNetCore.Mvc;

namespace InfiniteCoffee2.Controllers.Api;

[ApiController]
[Route("api/health")]
public sealed class HealthApiController : ControllerBase
{
    [HttpGet]
    public IActionResult Check()
    {
        try
        {
            var serverVersion = Banco.ObterVersaoEstoque();
            return Ok(new { status = "ok", banco = "ok", versao = serverVersion, horario = DateTime.UtcNow });
        }
        catch (Exception)
        {
            return StatusCode(StatusCodes.Status503ServiceUnavailable, new
            {
                status = "degradado",
                banco = "indisponivel",
                mensagem = "Não foi possível consultar o banco local."
            });
        }
    }
}

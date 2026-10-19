using System.ComponentModel.DataAnnotations;
using InfiniteCoffee2.Data;
using Microsoft.AspNetCore.Mvc;

namespace InfiniteCoffee2.Controllers.Api;

[ApiController]
[Route("api/cadastros")]
public sealed class CadastrosApiController : ControllerBase
{
    [HttpGet("clientes")]
    public IActionResult Clientes([FromQuery] bool incluirInativos = false) =>
        Ok(Banco.ListarClientesCadastro(incluirInativos));

    [HttpPost("clientes")]
    public IActionResult CadastrarCliente([FromBody] ClienteCadastroRequest request)
    {
        if (!DadosValidos(request.Nome, 100) || !EmailValido(request.Email))
            return BadRequest(new { mensagem = "Informe um nome válido e um e-mail válido (opcional)." });

        var id = Banco.CadastrarClienteCadastro(request.Nome.Trim(), request.Email?.Trim() ?? string.Empty);
        return StatusCode(StatusCodes.Status201Created, new { id_cliente = id, mensagem = "Cliente cadastrado com sucesso." });
    }

    [HttpPut("clientes/{id:int}")]
    public IActionResult EditarCliente(int id, [FromBody] ClienteCadastroRequest request)
    {
        if (id <= 0 || !DadosValidos(request.Nome, 100) || !EmailValido(request.Email))
            return BadRequest(new { mensagem = "Informe um nome válido e um e-mail válido (opcional)." });
        if (!Banco.AtualizarClienteCadastro(id, request.Nome.Trim(), request.Email?.Trim() ?? string.Empty))
            return NotFound(new { mensagem = "Cliente não encontrado ou inativo." });
        return Ok(new { mensagem = "Cliente atualizado com sucesso." });
    }

    [HttpDelete("clientes/{id:int}")]
    public IActionResult InativarCliente(int id)
    {
        if (id <= 0 || !Banco.DefinirClienteAtivo(id, false))
            return NotFound(new { mensagem = "Cliente não encontrado ou já inativo." });
        return Ok(new { mensagem = "Cliente inativado. O histórico foi preservado." });
    }

    [HttpPatch("clientes/{id:int}/ativo")]
    public IActionResult AtivarCliente(int id, [FromBody] AtivoRequest request)
    {
        if (id <= 0 || !request.Ativo)
            return BadRequest(new { mensagem = "Informe ativo=true para reativar o cliente." });
        if (!Banco.DefinirClienteAtivo(id, true))
            return NotFound(new { mensagem = "Cliente não encontrado ou já ativo." });
        return Ok(new { mensagem = "Cliente reativado com sucesso." });
    }

    [HttpGet("funcionarios")]
    public IActionResult Funcionarios([FromQuery] bool incluirInativos = false) =>
        Ok(Banco.ListarFuncionariosCadastro(incluirInativos));

    [HttpPost("funcionarios")]
    public IActionResult CadastrarFuncionario([FromBody] FuncionarioCadastroRequest request)
    {
        if (!DadosValidos(request.Nome, 100) || !DadosValidos(request.Cargo, 100))
            return BadRequest(new { mensagem = "Informe nome e cargo, com até 100 caracteres." });
        var id = Banco.CadastrarFuncionarioCadastro(request.Nome.Trim(), request.Cargo.Trim());
        return StatusCode(StatusCodes.Status201Created, new { id_funcionario = id, mensagem = "Funcionário cadastrado com sucesso." });
    }

    [HttpPut("funcionarios/{id:int}")]
    public IActionResult EditarFuncionario(int id, [FromBody] FuncionarioCadastroRequest request)
    {
        if (id <= 0 || !DadosValidos(request.Nome, 100) || !DadosValidos(request.Cargo, 100))
            return BadRequest(new { mensagem = "Informe nome e cargo, com até 100 caracteres." });
        if (!Banco.AtualizarFuncionarioCadastro(id, request.Nome.Trim(), request.Cargo.Trim()))
            return NotFound(new { mensagem = "Funcionário não encontrado ou inativo." });
        return Ok(new { mensagem = "Funcionário atualizado com sucesso." });
    }

    [HttpDelete("funcionarios/{id:int}")]
    public IActionResult InativarFuncionario(int id)
    {
        if (id <= 0 || !Banco.DefinirFuncionarioAtivo(id, false))
            return NotFound(new { mensagem = "Funcionário não encontrado ou já inativo." });
        return Ok(new { mensagem = "Funcionário inativado. O histórico foi preservado." });
    }

    [HttpPatch("funcionarios/{id:int}/ativo")]
    public IActionResult AtivarFuncionario(int id, [FromBody] AtivoRequest request)
    {
        if (id <= 0 || !request.Ativo)
            return BadRequest(new { mensagem = "Informe ativo=true para reativar o funcionário." });
        if (!Banco.DefinirFuncionarioAtivo(id, true))
            return NotFound(new { mensagem = "Funcionário não encontrado ou já ativo." });
        return Ok(new { mensagem = "Funcionário reativado com sucesso." });
    }

    [HttpGet("mesas")]
    public IActionResult Mesas([FromQuery] bool incluirInativos = false) =>
        Ok(Banco.ListarMesasCadastro(incluirInativos));

    [HttpPost("mesas")]
    public IActionResult CadastrarMesa([FromBody] MesaCadastroRequest request)
    {
        if (!MesaValida(request))
            return BadRequest(new { mensagem = "Informe número e capacidade de mesa maiores que zero." });
        try
        {
            var id = Banco.CadastrarMesaCadastro(request.Numero, request.Capacidade);
            return StatusCode(StatusCodes.Status201Created, new { id_mesa = id, mensagem = "Mesa cadastrada com sucesso." });
        }
        catch (MesaNumeroDuplicadoException)
        {
            return Conflict(new { mensagem = "Já existe uma mesa ativa com esse número." });
        }
    }

    [HttpPut("mesas/{id:int}")]
    public IActionResult EditarMesa(int id, [FromBody] MesaCadastroRequest request)
    {
        if (id <= 0 || !MesaValida(request))
            return BadRequest(new { mensagem = "Informe número e capacidade de mesa maiores que zero." });
        try
        {
            if (!Banco.AtualizarMesaCadastro(id, request.Numero, request.Capacidade))
                return NotFound(new { mensagem = "Mesa não encontrada ou inativa." });
            return Ok(new { mensagem = "Mesa atualizada com sucesso." });
        }
        catch (MesaNumeroDuplicadoException)
        {
            return Conflict(new { mensagem = "Já existe uma mesa ativa com esse número." });
        }
    }

    [HttpDelete("mesas/{id:int}")]
    public IActionResult InativarMesa(int id)
    {
        if (id <= 0) return BadRequest(new { mensagem = "Identificador de mesa inválido." });
        if (!Banco.DefinirMesaAtiva(id, false))
            return Conflict(new { mensagem = "Mesa não encontrada, já inativa, ocupada, reservada ou com pedido aberto. Libere a mesa antes de inativar." });
        return Ok(new { mensagem = "Mesa inativada. O histórico foi preservado." });
    }

    [HttpPatch("mesas/{id:int}/ativo")]
    public IActionResult AtivarMesa(int id, [FromBody] AtivoRequest request)
    {
        if (id <= 0 || !request.Ativo)
            return BadRequest(new { mensagem = "Informe ativo=true para reativar a mesa." });
        try
        {
            if (!Banco.DefinirMesaAtiva(id, true))
                return NotFound(new { mensagem = "Mesa não encontrada ou já ativa." });
            return Ok(new { mensagem = "Mesa reativada com sucesso." });
        }
        catch (MesaNumeroDuplicadoException)
        {
            return Conflict(new { mensagem = "Já existe uma mesa ativa com esse número." });
        }
    }

    private static bool DadosValidos(string? value, int maxLength) =>
        !string.IsNullOrWhiteSpace(value) && value.Trim().Length <= maxLength;

    private static bool EmailValido(string? email) =>
        string.IsNullOrWhiteSpace(email) ||
        (email.Trim().Length <= 100 && new EmailAddressAttribute().IsValid(email.Trim()));

    private static bool MesaValida(MesaCadastroRequest request) =>
        request.Numero > 0 && request.Capacidade > 0;
}

public sealed class ClienteCadastroRequest
{
    public string Nome { get; set; } = string.Empty;
    public string? Email { get; set; }
}

public sealed class FuncionarioCadastroRequest
{
    public string Nome { get; set; } = string.Empty;
    public string Cargo { get; set; } = string.Empty;
}

public sealed class MesaCadastroRequest
{
    public int Numero { get; set; }
    public int Capacidade { get; set; }
}

public sealed class AtivoRequest
{
    public bool Ativo { get; set; }
}

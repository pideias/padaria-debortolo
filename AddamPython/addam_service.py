"""Local, rule-based first version of Addam; no external model or database access."""

from __future__ import annotations

import json
import os
import unicodedata
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit


MAX_MESSAGE_LENGTH = 500
MAX_BODY_LENGTH = 4096
DEFAULT_SUGGESTIONS = [
    "O que você consegue fazer?",
    "Como consulto o estoque?",
    "Onde vejo as vendas?",
    "Você gera PDF?",
]


def _normalizar(texto: str) -> str:
    decomposed = unicodedata.normalize("NFKD", texto.casefold())
    return "".join(char for char in decomposed if not unicodedata.combining(char))


def responder(mensagem: str) -> dict[str, object]:
    """Classifica perguntas previstas e devolve respostas seguras, sem executar ações."""
    texto = _normalizar(mensagem.strip())

    if not texto:
        return {
            "assistant": "Addam",
            "reply": "Escreva uma pergunta para começarmos.",
            "suggestions": DEFAULT_SUGGESTIONS,
        }

    saudacoes = ("oi", "ola", "bom dia", "boa tarde", "boa noite", "e ai")
    if any(
        texto == saudacao
        or any(texto.startswith(saudacao + separador) for separador in (" ", ",", "!", "."))
        for saudacao in saudacoes
    ):
        return {
            "assistant": "Addam",
            "reply": (
                "Olá! Eu sou o Addam, assistente de teste da Padaria Debortolo. "
                "Posso orientar você pelo aplicativo. Ainda não consulto nem altero dados."
            ),
            "suggestions": DEFAULT_SUGGESTIONS,
        }

    if any(termo in texto for termo in (
        "o que voce", "o que tu", "quem e voce", "o que voce faz", "ajuda", "comandos", "capacidades"
    )):
        return {
            "assistant": "Addam",
            "reply": (
                "Nesta primeira versão posso orientar o uso do estoque, PDV, vendas, relatórios e "
                "cadastros. Ainda não leio o banco, não registro pedidos ou movimentações, não edito "
                "cadastros e não gero PDFs. Essas ações precisam de autenticação do dono e confirmação."
            ),
            "suggestions": DEFAULT_SUGGESTIONS,
        }

    if any(termo in texto for termo in ("pdf", "arquivo pdf", "exportar")):
        return {
            "assistant": "Addam",
            "reply": (
                "A geração de PDF ainda não está disponível nesta versão. Posso orientar você a abrir "
                "a área de Relatórios; depois podemos adicionar relatórios PDF baseados nos dados reais do banco."
            ),
            "suggestions": ["Onde vejo as vendas?", "Quais relatórios existem?"],
        }

    if any(termo in texto for termo in (
        "quantos itens", "quantos produtos", "sairam", "saida", "saidas", "movimentacao", "movimentacoes"
    )):
        return {
            "assistant": "Addam",
            "reply": (
                "Ainda não consulto quantidades por semana ou mês. Para conferir o saldo atual, abra "
                "Estoque. Um relatório de entradas e saídas por período será uma melhoria futura."
            ),
            "suggestions": ["Como consulto o estoque?", "Você gera PDF?"],
        }

    if any(termo in texto for termo in ("estoque", "saldo", "inventario", "produto")):
        return {
            "assistant": "Addam",
            "reply": (
                "Para ver os saldos atuais, abra Estoque no aplicativo. Nesta versão eu só explico o caminho; "
                "não consulto o banco nem registro entradas ou saídas por você."
            ),
            "suggestions": ["Onde registro uma entrada?", "Como vejo as vendas?"],
        }

    if any(termo in texto for termo in ("cadastro", "cliente", "funcionario", "mesa")):
        return {
            "assistant": "Addam",
            "reply": (
                "Os cadastros de clientes, funcionários e mesas ficam na área Cadastros. "
                "Ainda não posso criar ou editar esses registros por conversa."
            ),
            "suggestions": ["Como cadastro um cliente?", "O que você consegue fazer?"],
        }

    termos_vendas = ("venda", "vendas", "faturamento", "pedido")
    termos_consulta = (
        "onde", "ver", "vejo", "consultar", "mostrar", "historico",
        "relatorio", "quanto", "semana", "mes",
    )
    if any(termo in texto for termo in termos_vendas) and any(
        termo in texto for termo in termos_consulta
    ):
        return {
            "assistant": "Addam",
            "reply": (
                "Abra Relatórios para ver o resumo e as vendas por produto, ou Vendas para consultar o histórico. "
                "Ainda não consigo filtrar por período por conversa."
            ),
            "suggestions": ["Você gera PDF?", "Como faço uma venda?"],
        }

    if any(termo in texto for termo in ("pedido", "pdv", "vender", "venda", "comprar")):
        if any(termo in texto for termo in ("relatorio", "relatorios", "faturamento", "historico", "semana", "mes")):
            return {
                "assistant": "Addam",
                "reply": (
                    "Abra Relatórios para ver o resumo e as vendas por produto, ou Vendas para consultar o histórico. "
                    "Ainda não consigo filtrar por período por conversa."
                ),
                "suggestions": ["Você gera PDF?", "Como faço uma venda?"],
            }
        return {
            "assistant": "Addam",
            "reply": (
                "Para registrar uma venda no balcão, abra PDV, escolha os itens e confirme. "
                "Eu ainda não crio pedidos por conversa; quando isso for habilitado, pedirei confirmação antes de gravar."
            ),
            "suggestions": ["Onde vejo as vendas?", "O que você consegue fazer?"],
        }

    return {
        "assistant": "Addam",
        "reply": (
            "Ainda não entendi essa pergunta. Posso orientar sobre estoque, PDV, vendas, relatórios e cadastros. "
            "Tente uma das sugestões abaixo."
        ),
        "suggestions": DEFAULT_SUGGESTIONS,
    }


class AddamHandler(BaseHTTPRequestHandler):
    server_version = "Addam"

    def _responder_json(self, status: int, corpo: dict[str, object]) -> None:
        corpo_bytes = json.dumps(corpo, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(corpo_bytes)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(corpo_bytes)

    def do_GET(self) -> None:  # noqa: N802 - required by BaseHTTPRequestHandler
        if urlsplit(self.path).path == "/health":
            self._responder_json(200, {"status": "ok", "assistant": "Addam", "mode": "rules"})
            return
        self._responder_json(404, {"message": "Rota não encontrada."})

    def do_POST(self) -> None:  # noqa: N802 - required by BaseHTTPRequestHandler
        if urlsplit(self.path).path != "/chat":
            self._responder_json(404, {"message": "Rota não encontrada."})
            return

        try:
            tamanho = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            tamanho = 0
        if tamanho < 1 or tamanho > MAX_BODY_LENGTH:
            self._responder_json(413 if tamanho > MAX_BODY_LENGTH else 400, {"message": "Mensagem inválida."})
            return

        try:
            payload = json.loads(self.rfile.read(tamanho).decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            self._responder_json(400, {"message": "Envie uma mensagem JSON válida."})
            return

        mensagem = payload.get("message") if isinstance(payload, dict) else None
        if not isinstance(mensagem, str) or not mensagem.strip() or len(mensagem.strip()) > MAX_MESSAGE_LENGTH:
            self._responder_json(400, {"message": "A mensagem deve ter entre 1 e 500 caracteres."})
            return

        self._responder_json(200, responder(mensagem))

    def log_message(self, _format: str, *_args: object) -> None:
        # Não registrar mensagens do chat nem dados digitados pelos usuários.
        return


def main() -> None:
    porta = int(os.environ.get("ADDAM_PORT", "8091"))
    servidor = ThreadingHTTPServer(("127.0.0.1", porta), AddamHandler)
    servidor.daemon_threads = True
    servidor.serve_forever()


if __name__ == "__main__":
    main()

"""Small loopback-only Ollama substitute for CI smoke tests."""

from __future__ import annotations

import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


MODEL = os.environ.get("ADDAM_MODEL", "qwen2.5:0.5b")
CHAT_REPLY = {
    "reply": "Abra Estoque para consultar os saldos.",
    "suggestions": ["Como vejo as vendas?"],
    "action": None,
}


class OllamaStubHandler(BaseHTTPRequestHandler):
    def _send_json(self, status: int, body: dict[str, object]) -> None:
        content = json.dumps(body, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(content)))
        self.end_headers()
        self.wfile.write(content)

    def do_GET(self) -> None:  # noqa: N802 - required by BaseHTTPRequestHandler
        if self.path != "/api/tags":
            self._send_json(404, {"error": "not found"})
            return
        self._send_json(200, {"models": [{"name": MODEL}]})

    def do_POST(self) -> None:  # noqa: N802 - required by BaseHTTPRequestHandler
        if self.path != "/api/chat":
            self._send_json(404, {"error": "not found"})
            return
        length = int(self.headers.get("Content-Length", "0"))
        if length:
            self.rfile.read(length)
        content = json.dumps(CHAT_REPLY, ensure_ascii=False)
        self._send_json(200, {"message": {"content": content}})

    def log_message(self, _format: str, *_args: object) -> None:
        return


def main() -> None:
    ThreadingHTTPServer(("127.0.0.1", 11434), OllamaStubHandler).serve_forever()


if __name__ == "__main__":
    main()

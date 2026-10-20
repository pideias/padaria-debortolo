# Addam local

Assistente local da Padaria Debortolo, usando `qwen2.5:0.5b` pelo Ollama. O modelo GGUF Q4_K_M do catálogo Ollama tem cerca de 398 MB e licença Apache 2.0. O modelo roda no VPS; não há API de LLM externa nem cobrança por token.

O modelo interpreta pedidos e pode propor ações permitidas. A tela mostra os campos e pede confirmação; o aplicativo executa a operação pelas APIs REST existentes. O Addam/Python nunca acessa SQL Server nem executa SQL.

## Desenvolvimento local

Requer Python 3.10+ e Ollama com o modelo baixado. O serviço Python usa somente a biblioteca padrão:

```bash
ollama pull qwen2.5:0.5b
python3 -m unittest discover -s AddamPython -p 'test_*.py'
python3 AddamPython/addam_service.py
```

O serviço escuta somente em `127.0.0.1:8091` por padrão. Verifique localmente:

```bash
curl -fsS http://127.0.0.1:8091/health
curl -fsS http://127.0.0.1:8091/chat \
  -H 'Content-Type: application/json' \
  -d '{"message":"O que você consegue fazer?","history":[],"catalog":[]}'
```

O ASP.NET encaminha o app para o serviço pelo endpoint `POST /api/addam/chat`. A URL interna pode ser alterada com `ADDAM_SERVICE_URL`, mas precisa continuar apontando para loopback.

## VM Hostinger

Instale Ollama e baixe o modelo local uma vez:

```bash
curl -fsSL https://ollama.com/install.sh | sh
systemctl enable --now ollama
ollama pull qwen2.5:0.5b
```

Depois copie `addam_service.py` para `/opt/padaria-addam/` e `padaria-addam.service` para `/etc/systemd/system/`. Crie uma conta sem login interativo e suba o serviço:

```bash
sudo useradd --system --user-group --home-dir /nonexistent --shell /usr/sbin/nologin padaria-addam
sudo install -d -o padaria-addam -g padaria-addam -m 750 /opt/padaria-addam
sudo chown padaria-addam:padaria-addam /opt/padaria-addam/addam_service.py
sudo chmod 640 /opt/padaria-addam/addam_service.py
sudo systemctl daemon-reload
sudo systemctl enable --now padaria-addam
sudo systemctl status padaria-addam --no-pager
curl -fsS http://127.0.0.1:8091/health
```

Não abra as portas 8091 (Addam) nem 11434 (Ollama) para a internet. O serviço Python e Ollama devem ser acessados apenas em loopback.

## Limites e segurança

- Qwen2.5 0.5B é compacto e pode interpretar errado pedidos ambíguos; o backend valida e a tela pede confirmação antes de qualquer gravação.
- O catálogo enviado ao modelo é apenas um contexto para identificar produtos. Dados de clientes não são enviados ao modelo.
- O modelo é local e não envia prompts a provedores externos. O histórico de conversa fica apenas na memória do app.
- A API demonstrativa continua pública e usa HTTP; neste ambiente, qualquer pessoa que alcance a API pode chamar as rotas existentes de escrita. Use somente dados de teste até autenticação do dono e HTTPS estarem configurados.
- O modelo não recebe SQL, não executa exclusões, e não pode gerar PDFs nesta versão.

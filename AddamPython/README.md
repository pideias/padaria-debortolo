# Addam local

Primeira versão experimental do assistente Padaria Debortolo. É um roteador determinístico de perguntas em Python: não usa LLM, API externa, SQL Server, nem executa pedidos ou alterações.

## Desenvolvimento local

Requer Python 3.10+ e não usa dependências de terceiros:

```bash
python3 -m unittest discover -s AddamPython -p 'test_*.py'
python3 AddamPython/addam_service.py
```

O serviço escuta somente em `127.0.0.1:8091` por padrão. Verifique localmente:

```bash
curl -fsS http://127.0.0.1:8091/health
curl -fsS http://127.0.0.1:8091/chat \
  -H 'Content-Type: application/json' \
  -d '{"message":"O que você consegue fazer?"}'
```

O ASP.NET encaminha o app para o serviço pelo endpoint `POST /api/addam/chat`. A URL interna pode ser alterada com `ADDAM_SERVICE_URL`, mas precisa continuar apontando para loopback.

## VM Hostinger

Copie `addam_service.py` para `/opt/padaria-addam/` e `padaria-addam.service` para `/etc/systemd/system/`. Crie uma conta sem login interativo e suba o serviço:

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

Não abra a porta 8091 para a internet. O serviço deve ser acessado apenas pelo backend ASP.NET em loopback.

## Limites e segurança

- As respostas vêm de regras em `responder()`; não é uma IA generativa e pode não entender perguntas fora das intenções previstas.
- Não consulta dados da padaria, não cria pedidos, não movimenta estoque, não edita cadastros e não gera PDFs nesta versão.
- Não encaminha mensagens a provedores externos e não grava histórico de conversa.
- Ações de dono exigirão autenticação server-side, confirmação, validação pelas APIs existentes e transporte HTTPS antes de serem adicionadas.

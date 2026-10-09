# Documentacao de Sessao - 2026-09-07

## Contexto: indisponibilidade do APK

Na sexta (04/09) o sistema funcionava. No fim de semana o APK parou de
conectar. Diagnostico realizado:

- O APK nao conecta direto no SQL Server; ele consome a API REST.
- O APK estava correto (URL padrao e sem token conferidos dentro do
  `libapp.so` do build).
- A API do Render (`padaria-debortolo-api`) parou de responder
  (TCP ok na borda, mas HTTP sem resposta mesmo apos 170s). Cold start do
  plano gratuito leva ~1 min, entao nao era sleep normal.
- O `/api/health` do codigo nao pendura quando o banco cai (retorna 503
  degradado), o que indicava container morto/suspenso no Render.

Paralelamente, o banco `infiniteCoffee` foi limpo (registros removidos,
estrutura e procedures preservadas).

## Decisao: migrar API + banco para a VM Hostinger (KVM1)

Fim da dependencia do Render Free (sleep/falha de acordar). Um unico
banco fonte de verdade:

- VM: Hostinger KVM1, Ubuntu 22.04, hostname `srv1956950`.
- SQL Server 2022 (Developer) ja instalado na VM, porta 1433.
- API ASP.NET Core .NET 10 publicada em `/opt/padaria-api`.
- Servico systemd `padaria-api` (sobe no boot, restart automatico).
- URL publica da API: `http://179.199.144.253:8080`.
- Health: `GET /api/health` retorna `{"status":"ok","banco":"ok",...}`.

### Arquivos na VM

| Caminho | Funcao |
|---|---|
| `/opt/padaria-api/` | Publicacao self-contained da API (win-x64 nao; eh Linux, `dotnet publish` padrao) |
| `/opt/padaria-api/app.env` | Variaveis: `ASPNETCORE_ENVIRONMENT`, `PADARIA_PUBLIC_API=true`, `PADARIA_CONNECTION_STRING` (Server=localhost,1433). Permissao 600. Nunca versionar. |
| `/etc/systemd/system/padaria-api.service` | Servico: `dotnet InfiniteCoffee2.dll --urls http://0.0.0.0:8080` |
| Firewall | `ufw allow 8080/tcp` (API) e 1433 (SQL, hoje aberto) |

### Comandos operacionais (na VM)

```bash
sudo systemctl status padaria-api
sudo systemctl restart padaria-api
sudo journalctl -u padaria-api -n 50 --no-pager
```

Para atualizar a API: `dotnet publish InfiniteCoffee2/InfiniteCoffee2.csproj -c Release`,
enviar a pasta para `/opt/padaria-api` (scp) e `sudo systemctl restart padaria-api`.

## Banco de dados

- Banco `infiniteCoffee` existe na VM; a limpeza removeu os registros,
  nao a estrutura.
- `DatabaseScripts/InstallDatabase.sql` reaplicado (idempotente): repovoou
  3 produtos demo, 3 funcionarios, 3 mesas. Catalogo real cadastrado pelo
  app.

## Builds gerados

Ambos apontando para `API_BASE_URL=http://179.199.144.253:8080`
(e `API_WRITE_BASE_URL` igual). Sem `X-Api-Key` (API publica,
`PADARIA_PUBLIC_API=true`).

```powershell
flutter build apk --release `
  --dart-define=API_BASE_URL=http://179.199.144.253:8080 `
  --dart-define=API_WRITE_BASE_URL=http://179.199.144.253:8080

flutter build windows --release `
  --dart-define=API_BASE_URL=http://179.199.144.253:8080 `
  --dart-define=API_WRITE_BASE_URL=http://179.199.144.253:8080
```

Artefatos (pasta `artifacts/` ignorada pelo git):

- `artifacts/installer/Instalar-App-Celular.apk`
- `artifacts/installer/PadariaDebortolo-Desktop-Setup.exe`
- `artifacts/installer/Pacote-Completo-Padaria.zip` (pacote para a padaria)

## Instalador desktop - variante cloud

Novo arquivo `Installer/PadariaDebortolo-Cloud.iss` (Inno Setup 7), ao
lado do instalador original (`PadariaDebortolo.iss`, mantido sem
alteracao):

- Instala somente o app Flutter Windows; nao exige SQL Server nem
  backend local na maquina da padaria.
- Inclui `Installer/LEIA-ME-DESKTOP.txt` com instrucoes de offline.
- O pipeline original (`Installer/publish.ps1`) continua funcionando para
  o cenario tudo-local.

## Comportamento offline (APK e desktop, mesmo codigo)

Ver `InfiniteCoffeeMobile/lib/repositories/inventory_repository.dart`.

| Operacao | Offline | Mecanismo |
|---|---|---|
| Vender | Sim | Fila local (`pending_stock_exits`) + `POST /api/sync/push` quando a net volta |
| Entrada de estoque | Sim | Mesma fila |
| Saida de estoque | Sim | Mesma fila |
| Consultar estoque | Sim | Cache local (`cached_products`) |
| Cadastrar produto | Nao | Exige internet (produto precisa do `id_produto` do SQL) |
| Editar/excluir produto | Nao | Exige internet |
| Historico de vendas | Nao | Exige internet |

Requisito: abrir o app uma vez com internet para povoar o cache.

## Pendencias

1. **Trocar a senha do `sa`** (foi exposta em conversa) e atualizar em
   `/opt/padaria-api/app.env`:
   ```bash
   sudo systemctl stop mssql-server
   sudo MSSQL_SA_PASSWORD='NOVA_SENHA' /opt/mssql/bin/mssql-conf set-sa-password
   sudo systemctl start mssql-server
   ```
2. **Aposentar o servico no Render** (dashboard) - o pacote nao depende mais dele.
3. **Restringir 1433** no ufw quando nada mais acessar o SQL de fora
   (a API fala com o SQL via localhost).
4. Atualizar o `AGENTS.md` quando a topologia (localhost:5049) mudar de vez.

# Teste local no PC

## Iniciar a API

No instalador, abra o atalho **Padaria Debortolo**. Ele inicia automaticamente a API local,
o desktop e o backup do Google Drive quando encontrar uma credencial OAuth no computador.

Na raiz do projeto:

```powershell
dotnet run --project InfiniteCoffee2/InfiniteCoffee2.csproj --launch-profile http
```

A API ficará em `http://localhost:5049`.

## Consultar o snapshot

```powershell
Invoke-WebRequest http://localhost:5049/api/estoque/snapshot
```

O endpoint retorna a versão, a data da leitura e os produtos ativos com saldo.

## Enviar o snapshot ao Google Drive

Inicie a API com o arquivo OAuth local e o ID da pasta compartilhada:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Installer\Start-LocalWithGoogleDrive.ps1 `
  -CredentialsPath 'D:\client_secret_1010042086839-p0kcnsihn9pqt0hausih30vcspib1jld.apps.googleusercontent.com.json' `
  -FolderId '1yP55ALmQDCwhhhaLQ5SJkGrWF0mewGPa'
```

A API abrirá o navegador na primeira execução para autorizar sua conta Google.
Depois envia `estoque.json` ao iniciar e substitui o mesmo arquivo a cada hora.
Não coloque o arquivo JSON de credenciais no repositório.

Para acessar a API fora do PC, configure um token e use o mesmo token no app:

```powershell
$env:PADARIA_API_TOKEN = 'gere-um-token-longo-e-aleatorio'
flutter build apk --release --dart-define=API_BASE_URL=https://sua-api.example `
  --dart-define=API_ACCESS_TOKEN=gere-um-token-longo-e-aleatorio `
  --dart-define=API_WRITE_BASE_URL=http://IP_DO_PC:5049 `
  --dart-define=API_LOCAL_URL=http://IP_DO_PC:5049
```

Use o token de leitura (`ReadOnlyToken`) no mobile. Ele pode consultar o estoque,
mas não pode executar entradas, saídas ou cadastros. Guarde o token administrativo
(`ApiToken`) somente no PC.

## Testar pelo celular na mesma rede

1. Descubra o IPv4 do computador com `ipconfig`.
2. Inicie o backend aceitando a rede local:

```powershell
dotnet run --project InfiniteCoffee2/InfiniteCoffee2.csproj --urls http://0.0.0.0:5049
```

3. No celular, use `http://IP_DO_PC:5049` como endereço da API.
4. Libere a porta 5049 no Firewall do Windows somente na rede privada.

## Testar pela internet

Com o backend local rodando, use um túnel Cloudflare:

```powershell
cloudflared tunnel --url http://localhost:5049
```

Use a URL HTTPS fornecida pelo comando apenas para testes. Não exponha o sistema
permanentemente antes de adicionar autenticação à API.

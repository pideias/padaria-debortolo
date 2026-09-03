# Guia para IAs: executar a Padaria Debortolo em outra maquina

## Objetivo

Este documento orienta outra IA ou desenvolvedor a preparar e executar o projeto em uma maquina nova sem assumir caminhos, IPs, tokens ou credenciais da maquina original.

Arquitetura esperada:

```text
Flutter Desktop/Mobile -> API local -> SQL Server
                                  -> Google Drive
```

O SQL Server local e a fonte oficial. O Google Drive guarda os snapshots `estoque.json` e `vendas.json`. A API hospedada no Render e somente para consulta e nao deve receber operacoes de escrita.

## Regras para a IA

- Inspecionar o repositorio antes de alterar qualquer arquivo.
- Nunca copiar tokens, client secrets ou arquivos OAuth para o repositorio.
- Nunca gravar um IP fixo de outra rede no codigo.
- Usar variaveis de ambiente ou `--dart-define` para configuracoes por maquina.
- Nao usar a API do Render para entradas, saidas, vendas ou backup.
- Confirmar a branch correta antes de fazer commit ou push.
- Nao sobrescrever alteracoes existentes de outro desenvolvedor.
- Testar primeiro `/api/health`, depois uma operacao controlada de estoque.

## Pre-requisitos

Instalar na maquina:

- .NET SDK 10.
- SQL Server ou SQL Server Express.
- Flutter SDK com suporte ao Windows e/ou Android.
- PowerShell 5.1 ou superior.
- Google Chrome ou outro navegador para a primeira autorizacao OAuth.
- Inno Setup somente se for gerar o instalador.

Conferir as ferramentas:

```powershell
dotnet --version
flutter --version
git --version
```

## Banco de dados

O projeto espera um banco chamado `infiniteCoffee`.

O instalador executa `Installer/Setup-Database.ps1`, que procura nesta ordem:

```text
localhost\KAIO
localhost\SQLEXPRESS
localhost
(localdb)\MSSQLLocalDB
```

Se a maquina usar outro servidor, ajustar o script ou fornecer a connection string correta no arquivo de configuracao da API. O arquivo gerado pelo instalador fica em:

```text
server/appsettings.Production.json
```

Para desenvolvimento, a configuracao padrao fica em:

```text
InfiniteCoffee2/appsettings.json
```

Executar o script de banco:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Installer\Setup-Database.ps1 -InstallDir (Get-Location)
```

O script cria o banco, tabelas, procedures e atualiza a configuracao de producao. Nao executar scripts destrutivos em um banco que ja tenha dados.

## API local sem instalador

Para somente testar a API com SQL Server:

```powershell
dotnet run --project .\InfiniteCoffee2\InfiniteCoffee2.csproj --launch-profile http
```

Endereco esperado:

```text
http://127.0.0.1:5049
```

Para permitir acesso de um celular na mesma rede:

```powershell
dotnet run --project .\InfiniteCoffee2\InfiniteCoffee2.csproj --urls http://0.0.0.0:5049
```

Liberar a porta 5049 somente na rede privada do Windows:

```powershell
netsh advfirewall firewall add rule name="Padaria Debortolo API" dir=in action=allow protocol=TCP localport=5049 profile=private
```

## API local com Google Drive

O backup manual e automatico exige duas configuracoes:

- caminho do arquivo OAuth `client_secret*.json`;
- ID da pasta compartilhada do Google Drive.

Iniciar usando o script oficial:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Installer\Start-LocalWithGoogleDrive.ps1 `
  -CredentialsPath "C:\CAMINHO\client_secret.json" `
  -FolderId "ID_DA_PASTA_NO_DRIVE"
```

O script configura estas variaveis somente no processo da API:

```text
GOOGLE_DRIVE_OAUTH_CLIENT_PATH
GOOGLE_DRIVE_FOLDER_ID
GOOGLE_DRIVE_SNAPSHOT_NAME=estoque.json
```

Na primeira execucao, autorizar a conta Google no navegador. O token OAuth sera salvo no perfil local do usuario em:

```text
%LOCALAPPDATA%\PadariaDebortolo\GoogleDriveToken
```

Nao colocar o arquivo `client_secret*.json` nem a pasta de token no Git.

O servico publica:

- `estoque.json`, com produtos ativos e saldo;
- `vendas.json`, com historico de vendas.

O upload automatico ocorre na inicializacao e depois a cada 30 minutos.

## Inicializacao pelo instalador

O atalho instalado executa:

```text
Start-PadariaDesktop.cmd
  -> Start-PadariaDesktop.ps1
  -> InfiniteCoffee2.exe
  -> infinite_coffee_app.exe
```

`Start-PadariaDesktop.ps1`:

- inicia a API em `http://0.0.0.0:5049`;
- procura `client_secret*.json` em `Downloads`, na raiz do drive `D:` e no perfil do usuario;
- configura o Google Drive quando encontra a credencial;
- inicia o aplicativo desktop depois de tres segundos.

Em uma maquina diferente, a IA deve verificar os caminhos de procura e adaptar o script para a estrutura da maquina, sem inserir credenciais no codigo.

Arquivos necessarios no instalador:

```text
Installer/PadariaDebortolo.iss
Installer/Start-PadariaDesktop.cmd
Installer/Start-PadariaDesktop.ps1
Installer/publish.ps1
```

Gerar os artefatos:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Installer\publish.ps1
```

O instalador depende dos artefatos gerados em `artifacts/server` e `artifacts/desktop`.

## Configuracao do Flutter

### Windows

O desktop usa automaticamente:

```text
http://127.0.0.1:5049
```

Abrir:

```text
InfiniteCoffeeMobile/build/windows/x64/runner/Release/infinite_coffee_app.exe
```

No instalador, usar o atalho instalado, pois ele inicia a API antes do desktop.

### Android em celular fisico

Descobrir o IPv4 da maquina:

```powershell
ipconfig
```

Gerar o APK usando o mesmo IP para consulta e escrita:

```powershell
flutter build apk --release `
  --dart-define=API_BASE_URL=http://IP_DO_PC:5049 `
  --dart-define=API_WRITE_BASE_URL=http://IP_DO_PC:5049 `
  --dart-define=API_LOCAL_URL=http://IP_DO_PC:5049
```

O APK fica em:

```text
InfiniteCoffeeMobile/build/app/outputs/flutter-apk/app-release.apk
```

Se a consulta vier de uma API remota somente leitura, manter `API_BASE_URL` remoto e usar `API_WRITE_BASE_URL` apontando para o IP local do PC. Assim entradas, saidas, vendas, sincronizacao e backup chegam ao servidor que acessa o SQL Server.

### Android Emulator

No emulador Android, o host do computador normalmente e `10.0.2.2`:

```powershell
flutter build apk --release `
  --dart-define=API_BASE_URL=http://10.0.2.2:5049 `
  --dart-define=API_WRITE_BASE_URL=http://10.0.2.2:5049 `
  --dart-define=API_LOCAL_URL=http://10.0.2.2:5049
```

## Fluxo funcional

### Operacao online

1. O mobile consulta `GET /api/estoque`.
2. Uma entrada ou saida e enviada para a API local.
3. A API atualiza o SQL Server em uma transacao.
4. A API grava a movimentacao de estoque.
5. O mobile recarrega o estoque.
6. O servico publica o snapshot no Google Drive.

### Operacao offline

1. O mobile grava a operacao na fila local.
2. O cache local e atualizado para refletir a operacao.
3. Quando a conectividade retorna, o mobile envia a fila para `POST /api/sync/push`.
4. A API aplica cada operacao isoladamente.
5. Operacoes aceitas saem da fila local.
6. O mobile atualiza os dados usando o banco local como origem.

## Endpoints principais

```text
GET  /api/health
GET  /api/estoque
POST /api/estoque/entrada
POST /api/estoque/saida
POST /api/estoque/backup
POST /api/vendas
GET  /api/sync/pull
POST /api/sync/push
GET  /api/relatorios/vendas/historico
```

Exemplo de saida:

```powershell
$body = '{"produtoId":1,"quantidade":1,"motivo":"Conferencia"}'
Invoke-WebRequest http://127.0.0.1:5049/api/estoque/saida `
  -Method Post -ContentType 'application/json' -Body $body
```

Exemplo de backup:

```powershell
Invoke-WebRequest http://127.0.0.1:5049/api/estoque/backup -Method Post
```

## Validacao obrigatoria

Executar nesta ordem:

```powershell
Invoke-WebRequest http://127.0.0.1:5049/api/health
Invoke-WebRequest http://127.0.0.1:5049/swagger/index.html
Invoke-WebRequest http://127.0.0.1:5049/api/estoque
```

Depois validar uma saida com um produto de teste, conferir a quantidade no estoque e, se necessario, restaurar a quantidade usando uma entrada equivalente. Por fim:

```powershell
Invoke-WebRequest http://127.0.0.1:5049/api/estoque/backup -Method Post
```

Resultado esperado:

- `health`: HTTP 200 e `banco: ok`;
- estoque: HTTP 200;
- saida: mensagem `Saida registrada com sucesso.`;
- backup: mensagem `Backup enviado para o Google Drive.`.

No Flutter:

```powershell
flutter pub get
flutter analyze
flutter test
```

## Diagnostico rapido

### Mensagem sobre API em modo consulta

O aplicativo esta enviando escrita ou backup para uma API com `PADARIA_SNAPSHOT_ONLY=true`. Corrigir `API_WRITE_BASE_URL` para a API local.

### Mensagem sobre configurar OAuth

A API local foi iniciada sem `GOOGLE_DRIVE_OAUTH_CLIENT_PATH` ou `GOOGLE_DRIVE_FOLDER_ID`. Iniciar pelo script `Start-LocalWithGoogleDrive.ps1` ou pelo atalho do instalador.

### API nao conecta no celular

Conferir:

- celular e PC na mesma rede;
- API iniciada com `--urls http://0.0.0.0:5049`;
- IP usado no APK e o IPv4 atual do PC;
- regra do Firewall para a porta 5049;
- nenhum VPN ou rede publica bloqueando a conexao.

### API local responde, mas o app mostra offline

No Windows, usar `127.0.0.1` em vez de `localhost`. No Android fisico, nunca usar `localhost`; usar o IP LAN do PC.

### Build falha informando arquivo em uso

Fechar `InfiniteCoffee2.exe` e `infinite_coffee_app.exe` antes de recompilar. Nao matar processos de outro projeto sem confirmar o caminho do executavel.

### Backup falha na primeira execucao

Verificar a autorizacao OAuth no navegador, o acesso da conta a pasta do Drive, o ID da pasta e a existencia do arquivo de credencial. O arquivo de credencial precisa ser do tipo OAuth para aplicativo desktop.

## Seguranca

- Nao commitar `client_secret*.json`.
- Nao commitar tokens de API.
- Nao expor o SQL Server diretamente na internet.
- Usar o Render apenas como consulta quando `PADARIA_SNAPSHOT_ONLY=true`.
- Para acesso remoto, configurar tokens e limitar permissoes de leitura e escrita.
- Liberar a porta 5049 apenas na rede privada quando o uso for local.

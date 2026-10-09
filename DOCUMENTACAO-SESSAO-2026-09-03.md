# Documentacao da Sessao

## Objetivo

Deixar a API da Padaria Debortolo funcionando localmente, com o SQL Server como fonte oficial, sincronizacao das operacoes do mobile e backup dos dados operacionais no Google Drive.

## Diagnostico realizado

- O backend e uma API ASP.NET Core no projeto `InfiniteCoffee2`.
- A API local usa a porta `5049`.
- O endpoint de saude confirmou o SQL Server conectado.
- O endpoint Swagger respondeu normalmente.
- A saida de estoque funcionou quando chamada diretamente:
  - `POST /api/estoque/saida`
  - reduz a quantidade do produto;
  - grava a movimentacao no SQL Server.
- O aplicativo estava exibindo a mensagem de operacao offline porque algumas chamadas usavam um endereco diferente da API local.
- O aviso de backup ocorria porque a chamada estava chegando a uma API em modo somente consulta (`PADARIA_SNAPSHOT_ONLY=true`).
- O backup tambem nao funcionava quando a API local era iniciada sem as variaveis de configuracao do Google Drive.

## Correcoes no mobile

Arquivo principal alterado:

`InfiniteCoffeeMobile/lib/services/inventory_api.dart`

Alteracoes:

- Desktop e Web passaram a usar `http://127.0.0.1:5049`, evitando problemas de `localhost` resolvendo para IPv6.
- Foi criada a configuracao `API_WRITE_BASE_URL`.
- Foi criada a configuracao `API_LOCAL_URL`.
- No Windows, operacoes de escrita sao enviadas automaticamente para a API local:
  - entrada de estoque;
  - saida de estoque;
  - vendas;
  - sincronizacao;
  - cadastro de produtos;
  - backup.
- A URL de consulta pode continuar sendo diferente da URL de escrita.
- Nenhum token foi gravado no codigo ou na documentacao.

## Correcoes e funcionamento da API

O backend possui os seguintes fluxos:

- `GET /api/estoque`: consulta o estoque no SQL Server.
- `POST /api/estoque/entrada`: registra entrada e aumenta o saldo.
- `POST /api/estoque/saida`: registra saida e reduz o saldo de forma transacional.
- `POST /api/vendas`: finaliza uma venda e baixa os produtos.
- `GET /api/sync/pull`: retorna alteracoes desde uma data.
- `POST /api/sync/push`: aplica operacoes offline do mobile.
- `POST /api/estoque/backup`: publica `estoque.json` e `vendas.json` no Google Drive.
- `GET /api/health`: verifica a saude da API e do banco.

O endpoint de saida valida quantidade, motivo, produto existente e estoque suficiente. A movimentacao e gravada junto com a alteracao do saldo dentro de uma transacao SQL.

## Inicializacao correta da API local

Nao iniciar somente com `dotnet run` quando o backup no Google Drive for necessario. Use o script:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Installer\Start-LocalWithGoogleDrive.ps1 `
  -CredentialsPath 'CAMINHO_DO_CLIENT_SECRET.json' `
  -FolderId 'ID_DA_PASTA_NO_GOOGLE_DRIVE'
```

O script configura:

- `GOOGLE_DRIVE_OAUTH_CLIENT_PATH`;
- `GOOGLE_DRIVE_FOLDER_ID`;
- `GOOGLE_DRIVE_SNAPSHOT_NAME=estoque.json`;
- inicializacao da API na porta `5049`.

Na primeira execucao, o Google pode abrir o navegador para autorizar a conta. O token OAuth fica no armazenamento local do usuario, fora do repositorio.

## Configuracao do mobile

Para consulta remota e escrita na API local, use os parametros abaixo ao gerar o aplicativo:

```powershell
flutter build apk --release `
  --dart-define=API_BASE_URL=https://SUA-API-DE-CONSULTA `
  --dart-define=API_ACCESS_TOKEN=TOKEN_DE_LEITURA `
  --dart-define=API_WRITE_BASE_URL=http://IP_DO_PC:5049 `
  --dart-define=API_LOCAL_URL=http://IP_DO_PC:5049
```

Para Windows, a API local padrao e:

`http://127.0.0.1:5049`

Para celular fisico, substitua `IP_DO_PC` pelo IPv4 do computador na rede local. A API precisa estar iniciada aceitando conexoes da rede:

```powershell
dotnet run --project InfiniteCoffee2/InfiniteCoffee2.csproj --urls http://0.0.0.0:5049
```

## Validacoes executadas

- `GET http://127.0.0.1:5049/api/health`: `200 OK`.
- `GET http://localhost:5049/swagger/index.html`: `200 OK`.
- `GET /api/estoque`: `200 OK`.
- `POST /api/estoque/saida`: registrou a saida e reduziu o estoque.
- `POST /api/estoque/entrada`: restaurou a quantidade usada no teste.
- `POST /api/estoque/backup`: `200 OK`, backup enviado ao Google Drive.
- `flutter analyze`: sem problemas.
- `flutter test`: todos os testes passaram.
- O executavel Windows foi recompilado durante a sessao antes da ultima solicitacao para nao recompilar.
- O ultimo ajuste do mobile foi feito somente no codigo-fonte, sem nova compilacao, conforme solicitado.

## Automatizacao do instalador

O atalho do instalador agora executa `Start-PadariaDesktop.ps1`. Esse script:

- inicia a API local em `http://0.0.0.0:5049`;
- procura automaticamente arquivos `client_secret*.json` em `Downloads`, na raiz do drive `D:` e no perfil do usuario;
- configura o acesso OAuth e a pasta padrao do Google Drive quando encontra a credencial;
- inicia o aplicativo desktop depois da API;
- nao inclui credenciais ou tokens no instalador.

Se a credencial nao estiver em um desses locais, o sistema inicia normalmente, mas o backup precisa ser configurado manualmente pelo `Start-LocalWithGoogleDrive.ps1`.

## Arquivos desta sessao

- `InfiniteCoffeeMobile/lib/services/inventory_api.dart`
- `Installer/README-Teste-Local.md`
- `DOCUMENTACAO-SESSAO-2026-09-03.md`

## Observacoes importantes

- O Google Drive armazena uma copia/snapshot; o SQL Server local continua sendo a fonte oficial.
- A API hospedada no Render e somente leitura e nao deve receber saidas, entradas ou backups.
- Tokens e credenciais devem ser fornecidos por variaveis de ambiente ou `--dart-define`, nunca commitados.
- Se o backup apresentar novamente a mensagem sobre API local, a API provavelmente foi iniciada sem o script do Google Drive ou o aplicativo esta usando uma URL remota para escrita.

# Documentacao para IAs e Desenvolvedores

Este arquivo e a fonte de contexto rapido do Infinite Coffee. Antes de alterar o projeto,
leia este arquivo, `AGENTS.md`, `README.md` e a skill relacionada ao fluxo.

## Identidade do projeto

- Nome: Infinite Coffee.
- Backend: ASP.NET Core MVC em .NET 10.
- Banco oficial: SQL Server `localhost\KAIO`, database `infiniteCoffee`.
- Acesso ao banco: `InfiniteCoffee2/Data/Banco.cs`.
- API REST e Swagger: `InfiniteCoffee2/Controllers/Api`.
- App Flutter atual: `C:\Users\kaiof\Desktop\infinite_coffee_app`.
- Pasta Flutter versionada no repositorio: `InfiniteCoffeeMobile`.
- Branch oficial para publicacao: `kaio`.

## Ordem de leitura por tarefa

1. `AGENTS.md` para regras obrigatorias.
2. Este documento para arquitetura e contratos.
3. Controller, View/modelo e `Banco.cs` do fluxo alterado.
4. Skill especifica em `.opencode/skills/`.
5. Testes e README antes de editar.

## Arquitetura atual

```text
Windows .exe / Android .apk / Flutter Web
             |
             | HTTP REST
             v
ASP.NET Core publicado no Render
             |
             v
SQL Server infiniteCoffee (fonte da verdade)
```

- Windows e Android usam o mesmo codigo Flutter.
- No app, o Hive e o espelho offline local; ele nao substitui o SQL Server.
- O app nao conversa diretamente com outro dispositivo. Windows e celular conversam
  entre si por meio da API e do SQL Server.
- Windows e Android usam `https://padaria-debortolo-api-8v6w.onrender.com` por padrao.
- Para desenvolvimento local, compile informando `API_BASE_URL` com a URL local desejada.

## Fluxo de inicializacao do Flutter

1. `main.dart` cria `InventoryApi`, `LocalDatabase`, `SyncService` e `InventoryRepository`.
2. `InventoryRepository.init()` abre as boxes Hive.
3. Se nao houver produtos locais, executa o seed por `GET /api/sync/pull`.
4. O `SyncService` agenda sincronizacao a cada 30 segundos e ao recuperar conectividade.
5. `HomeScreen` mostra o Hive imediatamente e atualiza em segundo plano, sem trocar a tela
   por spinner durante cada consulta.

## Boxes Hive

- `produtos`: catalogo local, chave `id_produto`.
- `movimentacoes`: historico recebido do servidor, chave `id_movimentacao`.
- `sync_queue`: operacoes offline com `tipo`, `clientUuid`, `payload`, `created_at`.
- `sync_state`: token `last_pull` usado no proximo pull.

Arquivos principais:

- `lib/database/local_database.dart`: persistencia Hive e fila local.
- `lib/services/sync_service.dart`: push/pull e agenda.
- `lib/services/inventory_api.dart`: chamadas HTTP.
- `lib/repositories/inventory_repository.dart`: regras de negocio offline-first.
- `lib/screens/home_screen.dart`: dashboard, produtos, estoque e PDV.

## Contratos REST

### Produtos

- `GET /api/produtos`: lista produtos ativos.
- `GET /api/produtos/versao`: retorna uma versao leve do catalogo.
- `POST /api/produtos`: cadastra produto.
- `DELETE /api/produtos/{id}`: inativa o produto e zera o estoque; nao apaga historico.

### Estoque

- `GET /api/estoque?busca=...`: lista estoque ativo.
- `GET /api/estoque/baixo?limite=5`: lista estoque baixo.
- `GET /api/estoque/versao`: retorna versao leve do estoque.
- `POST /api/estoque/entrada`: registra entrada.
- `POST /api/estoque/saida`: registra saida.

### Vendas e relatorios

- `POST /api/vendas`: cria pedido, itens, pagamento e baixa estoque em uma transacao.
- `GET /api/relatorios/vendas`: resumo de vendas do dia.
- `GET /api/relatorios/estoque`: estoque e alertas.

### Sincronizacao

- `GET /api/sync/pull?since={token}` retorna `serverTime`, `produtosTotal`, `produtos` e
  `movimentacoes`. Sem token, o app faz carga inicial.
- `POST /api/sync/push` recebe `{ operacoes: [...] }`. Tipos atuais: `entrada`, `saida` e
  `venda`. Cada operacao possui `clientUuid` e `payload`.
- `GET /api/sync/versao` retorna as versoes de estoque e produtos.

## Banco e integridade

- `Banco.GarantirEstruturaSync()` cria, de forma idempotente, `ativo` e `modified_at` em
  `Produtos`, alem dos triggers de auditoria.
- `modified_at` usa UTC (`GETUTCDATE()`).
- Entradas, saidas e vendas usam transacoes quando alteram estoque.
- Foreign keys relacionam pedidos, itens, pagamentos, produtos, clientes, funcionarios e mesas.
- Produto com historico nao deve sofrer `DELETE` fisico. A exclusao da interface e inativacao:
  `ativo = 0` e `quantidade_estoque = 0`.
- A limpeza completa executada no ambiente de testes removeu os registros, nao as tabelas.
  Nunca repetir limpeza em outro ambiente sem confirmacao explicita.

## Fluxo offline

1. A tela le produtos do Hive.
2. Entrada, saida e venda atualizam o saldo local de forma otimista.
3. A operacao entra em `sync_queue`.
4. Quando houver rede, o app envia a fila para `/api/sync/push`.
5. O servidor valida estoque e grava dados oficiais.
6. O app executa pull e substitui o saldo local pelo valor oficial.

O servidor e quem decide conflitos de estoque. O total exibido no PDV e apenas previsao;
o servidor valida o estoque e calcula o total final.

## Comandos de desenvolvimento

Backend:

```powershell
dotnet restore InfiniteCoffee2.slnx
dotnet build InfiniteCoffee2.slnx --no-restore
dotnet run --project InfiniteCoffee2/InfiniteCoffee2.csproj -- --urls=http://localhost:5049
```

Flutter:

```powershell
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter build windows
flutter build apk
flutter run -d chrome --web-port 5050
```

Android Emulator:

```powershell
flutter emulators
flutter devices
flutter run -d emulator-5554
```

## Validacao obrigatoria

- Depois de alterar C#/Razor: `dotnet build InfiniteCoffee2.slnx --no-restore` e reinicie o servidor.
- Depois de alterar Dart: formatacao, `flutter analyze`, `flutter test` e build do alvo afetado.
- Teste o fluxo online e offline, incluindo reinicio do servidor.
- Confirme que uma exclusao retira o produto das listas sem apagar historico de venda.
- Nao coloque senha ou credencial em codigo, README, skill, log ou commit.

## Publicacao e instalador Windows

- O instalador completo e gerado por `Installer/publish.ps1`.
- O pacote inclui o backend ASP.NET Core self-contained, o aplicativo Flutter Windows,
  os scripts do banco e a rotina `Installer/Setup-Database.ps1`.
- O banco e inicializado pelo script idempotente `DatabaseScripts/InstallDatabase.sql`.
  Ele cria o banco `infiniteCoffee`, tabelas, procedures e dados iniciais sem apagar dados
  existentes.
- Durante a instalacao, o script procura SQL Server em `localhost\\KAIO`,
  `localhost\\SQLEXPRESS`, `localhost` e `(localdb)\\MSSQLLocalDB`. Se encontrar uma
  instancia, grava a conexao em `server/appsettings.Production.json`.
- O SQL Server nao e distribuido no instalador. Em um PC virgem, ele deve ser instalado
  previamente; se nao for encontrado, a instalacao informa o requisito com erro claro.
- O Inno Setup 7 compila `artifacts/installer/PadariaDebortolo-Setup.exe`. O script de
  publicacao detecta Inno Setup 7 ou 6 automaticamente.
- Os icones do aplicativo sao gerados a partir de `InfiniteCoffeeMobile/assets/icon/app_icon.png`
  para Android, Windows e Web usando `flutter_launcher_icons`.
- O instalador nao contem tokens, senhas, credenciais OAuth ou strings de conexao com
  credenciais.
- As APIs estao publicas para o trabalho demonstrativo: nao exigem mais `X-Api-Key` no
  mobile, desktop ou web. A credencial do Google Drive continua somente no servidor e nao
  deve ser distribuida nos aplicativos.
- Os tokens continuam aceitos por compatibilidade, mas nao sao obrigatorios enquanto a API
  demonstrativa estiver publica. APKs novos podem ser compilados sem `API_ACCESS_TOKEN` e
  `API_WRITE_TOKEN`.
- O cliente mobile e o desktop usam por padrao `https://padaria-debortolo-api-8v6w.onrender.com`
  para leitura e escrita. Para desenvolvimento local, compile explicitamente com
  `API_BASE_URL` e `API_WRITE_BASE_URL` apontando para a API local. O cliente aguarda ate 60
  segundos para permitir o despertar da instancia gratuita.
- No modo demonstrativo, o mobile mantém uma cópia local persistente dos produtos, atualiza
  o saldo imediatamente após entrada/saída e mantém operações pendentes para sincronização
  posterior pela API. O Google Drive recebe somente uma cópia do SQL Server.
- O Render em `PADARIA_SNAPSHOT_ONLY=false` e a API central de leitura e escrita. O arquivo
  do Google Drive nunca e a fonte de escrita.
- A API central publica o snapshot do SQL Server no Drive a cada 30 minutos. O mobile e o
  desktop chamam `POST /api/estoque/backup`; nenhuma credencial do Google Drive e distribuida
  nos aplicativos.
- O desktop e o APK usam por padrao a API central no Render. O backend local continua
  disponivel somente para desenvolvimento, mediante `API_BASE_URL` explicito.
- Para compilar APK e Windows automaticamente, use `Installer/Build-Apps.ps1`. O script lê
  `PADARIA_READONLY_TOKEN` e `PADARIA_MOBILE_WRITE_TOKEN` do ambiente apenas quando elas
  existirem e nunca salva esses valores no repositorio. Os dois aplicativos usam a URL do
  Render por padrao.

## Limitacoes e proximos cuidados

- O Hive e populado pelo primeiro sync; ainda nao existe um arquivo de banco prepopulado
  dentro do APK.
- A fila usa `clientUuid`, mas o servidor ainda precisa de uma tabela de idempotencia para
  impedir duplicacao se a mesma operacao for reenviada apos uma falha de resposta.
- A inativacao incremental precisa de tombstones para remover automaticamente o produto de
  outros dispositivos que ja tenham o cache; atualmente o dispositivo que executa a exclusao
  remove o item localmente.
- O APK exige Android SDK, NDK e uma imagem de emulador instalados.

## Integracao centralizada

- `POST /api/sync/push` persiste cada `clientUuid` em `SyncOperations`; reenvios da mesma
  operacao sao tratados como aceitos sem repetir a baixa ou a venda.
- O pull inclui produtos inativados com `ativo = 0` como tombstones, permitindo que os
  caches removam o item sem apagar o historico no SQL Server.
- O PDV envia uma venda unica para `/api/vendas`, deixando o servidor calcular o total e
  executar pedido, itens, pagamento e baixa na mesma transacao.
- O Render deve executar a API central com `PADARIA_SNAPSHOT_ONLY=false`, receber a string
  de conexao por segredo (`PADARIA_CONNECTION_STRING`) e o JSON completo da conta de serviço em
  `GOOGLE_DRIVE_SERVICE_ACCOUNT_JSON`. Compartilhe a pasta do Drive com o e-mail da conta de
  serviço. O Google Drive continua somente como destino de backup/snapshot e é acessado apenas
  pelo backend via API.

# Documentação para IAs e Desenvolvedores

Este arquivo resume o estado implementado do demonstrativo Padaria Debortolo. Infinite Coffee
foi o nome anterior do projeto. Antes de alterar o código, leia este arquivo, `AGENTS.md`,
`README.md` e a skill relacionada ao fluxo.

## Identidade do projeto

- Aplicativo demonstrativo: Padaria Debortolo. Nome anterior do projeto: Infinite Coffee.
- Backend: ASP.NET Core MVC em .NET 10.
- Banco oficial: SQL Server; o identificador do banco no script é `infiniteCoffee`.
- Acesso ao banco: `InfiniteCoffee2/Data/Banco.cs`.
- API REST e Swagger: `InfiniteCoffee2/Controllers/Api`.
- Pasta Flutter versionada no repositorio: `InfiniteCoffeeMobile`.
- Branch oficial para publicacao: `kaio`.

## Ordem de leitura por tarefa

1. `AGENTS.md` para regras obrigatorias.
2. Este documento para arquitetura e contratos.
3. Controller, View/modelo e `Banco.cs` do fluxo alterado.
4. Skill especifica em `.opencode/skills/`.
5. Testes e README antes de editar.

## Arquitetura implementada

```text
Flutter (Android / Windows / Web)
        | HTTP REST + JSON
        v
ASP.NET Core .NET 10 (MVC + API)
        | Banco.cs / SQL
        v
SQL Server (fonte oficial)

Cliente: shared_preferences (cache do catálogo e fila pendente)
```

- O cliente não acessa o SQL Server diretamente. Os dispositivos comunicam-se com o servidor pela API REST.
- O cliente usa `shared_preferences`; não há Hive ou SQLite implementado no código Flutter atual.
- `API_BASE_URL` configura consultas e `API_WRITE_BASE_URL` pode separar a URL de escrita.
- `InventoryRepository.load()` consulta `GET /api/estoque`, atualiza `cached_products` e tenta reenviar pendências.
- Sem resposta da API, a tela usa o catálogo salvo localmente. Entrada, saída e venda podem ficar em `pending_stock_exits`.
- A fila é enviada por `POST /api/sync/push`. O cliente atual não executa o pull incremental, embora exista endpoint de pull no backend.
- Ao recuperar conectividade e durante a atualização periódica da tela, o app tenta carregar o estoque e sincronizar a fila.

Arquivos Flutter principais:

- `lib/services/inventory_api.dart`: requisições HTTP para a API.
- `lib/repositories/inventory_repository.dart`: cache, fila offline e regras do cliente.
- `lib/models/product.dart` e `lib/models/sales_by_product.dart`: modelos de resposta.
- `lib/screens/home_screen.dart`: navegação, estoque, produtos, PDV e histórico.
- `lib/screens/sales_report_screen.dart`: gráfico de vendas agregadas por produto.
- `lib/screens/management_screen.dart`: cadastros online de clientes, funcionários e mesas.

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
- `GET /api/relatorios/vendas/produtos`: quantidade e faturamento por produto em pedidos finalizados e pagos.
- `GET /api/relatorios/estoque`: estoque e alertas.

### Cadastros

- `GET /api/cadastros/clientes?incluirInativos=true`: lista clientes com nome, e-mail, ID e estado.
- `POST` e `PUT /api/cadastros/clientes[/{id}]`: cria ou atualiza cliente.
- `DELETE /api/cadastros/clientes/{id}` inativa; `PATCH /api/cadastros/clientes/{id}/ativo` reativa.
- Os mesmos verbos estão disponíveis em `/api/cadastros/funcionarios` e `/api/cadastros/mesas`.
- Funcionários usam nome e cargo; mesas usam número e capacidade. IDs são gerados no SQL Server.
- Excluir é inativar (`ativo = 0`), preservando registros e referências históricas. Mesa ocupada,
  reservada ou com pedido aberto não pode ser inativada; número de mesa ativa não pode ser duplicado.
- `sp_CriarPedido` valida os vínculos ativos e cria o pedido com locks transacionais para serializar
  sua execução com a inativação de mesas, clientes e funcionários.
- Esses cadastros dependem de rede/API e não entram na fila offline de estoque/vendas.
- Antes de publicar esse contrato, aplique `DatabaseScripts/UpgradeEntityManagement.sql` uma vez
  (script idempotente) no banco; ele adiciona as flags `ativo` e atualiza procedures de listagem.

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
- No atendimento MVC, adicionar item compara a quantidade solicitada com o saldo menos as quantidades já incluídas no pedido aberto; a inclusão não reserva nem baixa o estoque.
- Ao finalizar o atendimento, `Banco.FinalizarAtendimento` revalida todos os itens e grava baixa, movimentações, pagamento, status do pedido e liberação da mesa na mesma transação.
- O fechamento legado de pedidos usa `Banco.FecharPedidoComBaixaEstoque` para validar e registrar as saídas.
- O POST de cancelamento só remove pedidos abertos quando vem do formulário explícito; a requisição beacon de recarga/volta do navegador é ignorada.
- Foreign keys relacionam pedidos, itens, pagamentos, produtos, clientes, funcionarios e mesas.
- Produto com historico nao deve sofrer `DELETE` fisico. A exclusao da interface e inativacao:
  `ativo = 0` e `quantidade_estoque = 0`.
- Clientes, funcionários e mesas também usam exclusão lógica via `ativo = 0`; nunca apague as linhas,
  pois pedidos existentes podem referenciá-las.
- A limpeza completa executada no ambiente de testes removeu os registros, nao as tabelas.
  Nunca repetir limpeza em outro ambiente sem confirmacao explicita.

## Fluxo offline implementado

1. O app consulta `GET /api/estoque` e persiste o catálogo serializado em `cached_products`.
2. Se a API falhar, apresenta o catálogo salvo e sinaliza a condição offline.
3. Entradas, saídas e vendas que falham por erro temporário de rede são guardadas em `pending_stock_exits` com `clientUuid`.
4. Ao voltar a conexão ou atualizar o estoque, o cliente envia a fila para `POST /api/sync/push`.
5. O servidor revalida estoque, aplica a operação transacionalmente e retorna os identificadores aceitos.
6. O cliente remove da fila somente as operações aceitas; o SQL Server continua sendo a fonte oficial.

Cadastro/edição de produto, histórico e relatório de vendas por produto requerem comunicação com a API. O total do PDV no cliente é estimado; o backend confirma preços, estoque e total antes de finalizar.

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

## Publicação da API e do aplicativo

- `Installer/publish.ps1` gera o pacote Windows para instalação local.
- A publicação automática para a VM Hostinger está descrita em `DEPLOY-HOSTINGER.md` e no job
  `deploy-hostinger` de `.github/workflows/validate.yml`.
- O deploy automático só roda após validação bem-sucedida de um `push` em `master` e quando a
  variável `HOSTINGER_DEPLOY_ENABLED=true` e os secrets SSH estiverem configurados no GitHub.
- A publicação cria backup no servidor, preserva `/opt/padaria-api/app.env`, reinicia `padaria-api`
  e valida `/api/health`; em falha, restaura a versão anterior.
- A API continua usando `PADARIA_CONNECTION_STRING` no backend. Segredos e arquivos `app.env` nunca
  devem entrar no GitHub ou nos pacotes do APK/Windows.
- O deploy da API não recompila nem distribui os clientes Flutter. Para que um APK/EXE use a VM,
  configure `API_BASE_URL` e `API_WRITE_BASE_URL` no build. O valor padrão em `Build-Apps.ps1` ainda
  pode apontar para outro ambiente.
- O workflow não aplica alterações de schema. Mudanças em tabelas/procedures requerem script SQL
  revisado, backup e aplicação controlada no banco da VM.

## Limites da implementação atual

- O armazenamento local mobile usa `shared_preferences`, não Hive nem SQLite.
- O cliente mantém cache de produtos e fila de entradas, saídas e vendas. Cadastro/edição de produtos
  e histórico de vendas dependem da API.
- O backend implementa `GET /api/sync/pull`, mas o cliente atual consulta o estoque por
  `GET /api/estoque` e envia pendências por `POST /api/sync/push`; não descreva o cliente como pull
  incremental/bidirecional.
- `GET /api/relatorios/vendas/produtos` agrega quantidade e faturamento de pedidos finalizados com pagamento para
  o gráfico de vendas por produto. O endpoint considera todo o histórico e ainda não recebe filtro
  de período.
- O APK requer Android SDK para ser recompilado; Windows e Android usam a mesma base Flutter.

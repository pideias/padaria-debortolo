# Aplicativo demonstrativo Padaria Debortolo

O projeto teve anteriormente o nome Infinite Coffee. Este diretório contém o cliente Flutter
multiplataforma do demonstrativo Padaria Debortolo. O mesmo código gera
Android (`flutter build apk`), Windows (`flutter build windows`) e Web.

## Fonte de contexto

Leia primeiro, na raiz do repositorio:

- `AGENTS.md`: regras obrigatorias de desenvolvimento e banco.
- `DOCUMENTACAO-IA.md`: arquitetura atual, contratos REST e comandos.
- `Backlog-Sync.md`: propostas/planejamento de sincronização, não uma descrição do armazenamento atual.
- `.opencode/skills/`: regras por dominio para IAs e desenvolvedores.

## Arquitetura

- SQL Server é a fonte oficial dos dados.
- `shared_preferences` mantém o catálogo em cache (`cached_products`) e a fila local (`pending_stock_exits`).
- Windows e Android usam `https://padaria-debortolo-api-8w5w.onrender.com` por padrao.
  Para desenvolvimento local, informe `API_BASE_URL` explicitamente no build.
- `InventoryRepository` carrega o catálogo, atualiza o cache e reenvia operações pendentes por `POST /api/sync/push`.
- A leitura do catálogo usa `GET /api/estoque`; o cliente atual não executa o endpoint de pull incremental.
- Produto excluido e inativado no servidor (`ativo = 0`) para preservar historico de vendas.

## Validacao

```powershell
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter build windows
flutter build apk
```

O diretório `InfiniteCoffeeMobile` é a cópia Flutter versionada usada para análise, testes e builds.

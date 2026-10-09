# Infinite Coffee Mobile

Este diretorio e o projeto Flutter multiplataforma do Infinite Coffee. O mesmo codigo gera
Android (`flutter build apk`), Windows (`flutter build windows`) e Web.

## Fonte de contexto

Leia primeiro, na raiz do repositorio:

- `AGENTS.md`: regras obrigatorias de desenvolvimento e banco.
- `DOCUMENTACAO-IA.md`: arquitetura, contratos REST, Hive, sync e comandos.
- `Backlog-Sync.md`: plano de implementacao e validacao.
- `.opencode/skills/`: regras por dominio para IAs e desenvolvedores.

## Arquitetura

- SQL Server e a fonte oficial dos dados.
- Hive e o espelho local offline; nao e SQLite.
- Windows e Android usam `https://padaria-debortolo-api-8w5w.onrender.com` por padrao.
  Para desenvolvimento local, informe `API_BASE_URL` explicitamente no build.
- `LocalDatabase` persiste produtos, movimentacoes, fila (`sync_queue`) e token (`sync_state`).
- `SyncService` executa push/pull em segundo plano; a tela nao deve piscar durante sync.
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

O codigo Flutter em desenvolvimento pode estar em
`C:\Users\kaiof\Desktop\infinite_coffee_app`; ao publicar, sincronize as alteracoes
com este diretorio versionado.

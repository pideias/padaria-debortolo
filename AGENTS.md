# Regras do Infinite Coffee

Estas regras valem para todo trabalho neste repositorio.

## Contexto tecnico

- Aplicacao ASP.NET Core MVC em .NET 10.
- O projeto deve permanecer em .NET 10 ou superior; nunca regredir para .NET 8 ou outra versao inferior.
- Views Razor em `InfiniteCoffee2/Views`.
- Estilos estaticos em `InfiniteCoffee2/wwwroot`.
- A `CdmEdu` e a fonte oficial do HTML e do visual do sistema.
- Somente a `CdmEdu` pode criar ou alterar HTML, Views Razor, CSS e componentes visuais; outras branches devem receber essas mudancas por merge.
- Acesso ao SQL Server centralizado em `InfiniteCoffee2/Data/Banco.cs`.
- O banco usa procedures armazenadas e chaves estrangeiras para manter integridade.

## Regras de desenvolvimento

- Inspecione Controller, View, Banco.cs e README antes de alterar um fluxo existente.
- Preserve as rotas, nomes de campos, parametros de procedures e contratos entre Controller e View.
- Telas, HTML, CSS e rotas ja criados nao podem ser alterados, movidos ou removidos.
- Novas funcionalidades devem ser adicionadas em novas telas, arquivos ou rotas, sem modificar o que ja existe.
- Prefira a menor alteracao correta; nao reescreva a arquitetura sem necessidade concreta.
- Nao coloque senhas, tokens ou strings de conexao com credenciais no repositorio.
- Toda operacao de escrita deve validar entrada e retornar feedback compreensivel ao usuario.
- Exclusoes devem ser `POST`, pedir confirmacao na interface e respeitar historico e chaves estrangeiras.
- Nao apague pedidos, pagamentos ou itens relacionados sem autorizacao explicita; quando autorizado, use transacao e documente a perda de historico.
- Ao alterar uma View, preserve a acessibilidade basica, responsividade e as acoes existentes.
- Antes de integrar outra branch, compare suas Views e estilos com a `CdmEdu` e preserve o padrao visual dela.
- Depois de alterar C# ou Razor, execute `dotnet build InfiniteCoffee2.slnx --no-restore`.
- Se o servidor local estiver em execucao e bloquear o build, reinicie o processo antes de validar.

## Regras de banco de dados

- Antes de alterar schema ou procedure, consulte dependencias, foreign keys e dados existentes.
- Nunca execute `DROP DATABASE`, `TRUNCATE`, `DELETE` sem filtro ou alteracoes destrutivas sem confirmacao explicita.
- Prefira migrations ou scripts versionados e idempotentes; documente ordem de execucao.
- Teste inserts, updates, deletes e consultas em uma base de desenvolvimento.
- Preserve dados historicos de pedidos e pagamentos.
- Ao encontrar erro de integridade referencial, explique a causa e implemente tratamento explicito; cascade destrutivo exige autorizacao explicita.

## Git e publicacao

- O remoto oficial e `https://github.com/pideias/padaria-debortolo.git`.
- Todo commit e push de desenvolvimento deste projeto deve ser feito exclusivamente na branch `kaio`.
- Antes de qualquer commit ou push, confirme que a branch atual e `kaio`; nunca publique diretamente na `master`.
- Antes de qualquer commit ou push, atualize as referencias remotas e confira a `master` para verificar se a branch esta sincronizada e se existem mudancas que precisam ser integradas:
  `git fetch origin master` e `git log --oneline --decorate -5 origin/master`.
- Se a `master` estiver mais avancada ou houver divergencia, pare e informe antes de fazer commit ou push.
- A `master` recebe mudancas somente por merge aprovado da `kaio`.
- Antes de commit, confira `git status`, `git diff` e o resultado do build.
- Nao use `git reset --hard`, `git checkout --` ou force push para apagar trabalho existente.
- Use mensagens de commit curtas e descreva uma mudanca coesa.

## Regras adicionais do aplicativo mobile

- O aplicativo mobile deve ser desenvolvido em Flutter usando Dart.
- O projeto Flutter fica em `InfiniteCoffeeMobile` e deve permanecer separado do MVC.
- O backend continua em ASP.NET Core .NET 10.
- A API do ambiente demonstrativo deve permanecer pública (`PADARIA_PUBLIC_API=true`):
  APK, desktop e web não exigem `X-Api-Key` nem tokens embutidos no aplicativo. Credenciais
  do Google Drive e demais segredos devem permanecer exclusivamente no backend.
- O SQL Server permanece como fonte oficial dos dados.
- Operacoes offline devem ser persistidas localmente e sincronizadas depois.
- Nunca confirme uma venda sem revalidar o estoque no backend.
- Toda alteracao de estoque deve gerar historico e respeitar transacao.
- O PDV deve calcular valores no cliente apenas para exibicao; o servidor confirma o total.
- Nao altere ou remova telas HTML existentes; adicione novas rotas ou arquivos quando necessario.
- Apos alterar Dart, execute formatacao, analise, testes e build do alvo afetado.

## Arquitetura alvo e plataformas

- Um unico codigo Flutter (`infinite_coffee_app`) gera Windows (`flutter build windows`,
  exe em `build\windows\x64\runner\Release\infinite_coffee_app.exe`) e mobile
  (`flutter build apk`). Os dois sao o mesmo app em plataformas diferentes.
- O app embute um banco local **Hive** (offline-first, sem SQLite) que ja vem populado apos o primeiro sync.
- A "conversa entre Windows/mobile" e a web acontece SEMPRE via a API REST
  (`/api/*` no SQL Server), nunca peer-to-peer. Venda no mobile sobe para o servidor e o
  Windows enxerga no proximo pull; e vice-versa.
- Sync bidirecional: `GET /api/sync/pull?since={token}` (server -> app) e
  `POST /api/sync/push` (app -> server, operacoes offline). Detalhes na skill `sync-architecture`.
- Rede: app Windows usa `http://localhost:5049`; app mobile na mesma LAN usa o IP da maquina
  (ex.: `http://192.168.x.x:5049`). O CORS em `Program.cs` deve liberar essa origem.
- SQL Server continua sendo a fonte da verdade; Hive no app e um espelho offline.

## Preservacao de historico

- Produto nunca deve ser apagado fisicamente quando possuir vendas, itens de pedido,
  pagamentos ou movimentacoes vinculadas.
- A exclusao de produto significa inativacao (`ativo = 0`) e estoque zero, preservando
  pedidos, itens, pagamentos e movimentacoes para relatorios e auditoria.
- Limpeza completa de dados de teste so pode ocorrer com confirmacao explicita do usuario,
  sempre mantendo a estrutura, foreign keys e procedures do banco.

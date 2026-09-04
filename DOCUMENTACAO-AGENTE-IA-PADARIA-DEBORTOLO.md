# Plano de Integracao — Padaria Debortolo

Este documento e o contexto oficial para outro agente de IA implementar a integracao no
repositorio `https://github.com/pideias/padaria-debortolo`. **Nao implementar este plano no
repositorio `pideias-infinittecoffee`.**

## Objetivo final

Fazer Web, desktop Windows e mobile do Debortolo usarem a mesma API central e trabalharem
com os mesmos dados. O Google Drive sera apenas backup/snapshot, nunca o banco principal.

```text
Web Debortolo
Desktop Debortolo  ──> API central Debortolo ──> SQL Server principal
Mobile Debortolo                                  |
                                                   v
                                           Backup Google Drive
```

A opcao escolhida e **API compartilhada**. As APIs existentes devem ser preservadas sempre
que possivel; nao reescrever todos os controllers.

---

## 1. O que ja existe no Debortolo

Repositorio e branch observados:

- Repositorio: `pideias/padaria-debortolo`.
- Branch analisada: `CdmEdu`.
- Ultimo commit observado: `9a84666` (`fix: separar endereco local do desktop e mobile`).
- O repositorio contem `InfiniteCoffee2`, `InfiniteCoffeeMobile`, `Installer`,
  `DatabaseScripts`, `render.yaml`, workflows e documentacao.

### Backend

- ASP.NET Core MVC em .NET 10.
- SQL Server acessado por `InfiniteCoffee2/Data/Banco.cs`.
- API REST em `InfiniteCoffee2/Controllers/Api`.
- Swagger habilitado.
- Controllers existentes para estoque, produtos, vendas, relatorios, sync e health.
- Servico `GoogleDriveSnapshotHostedService` publica snapshot periodicamente.
- Servico `GoogleDriveSnapshotStore` le snapshot publico do Drive.

### Aplicativos

- Flutter mobile/desktop em `InfiniteCoffeeMobile`.
- Mesmo codigo Flutter pode gerar Android, Windows e Web.
- Instalador Windows em `Installer`.
- O mobile/desktop consome a API por HTTP; nao deve acessar SQL Server diretamente.

### Google Drive

- O desktop/local API pode publicar `estoque.json` no Google Drive.
- O Render esta configurado com `PADARIA_SNAPSHOT_ONLY=true`.
- Nesse modo, a API hospedada le o snapshot do Drive e fica somente leitura.
- O backup nao deve ser usado como banco concorrente ou mecanismo de merge.

### Situacao verificada

- O workflow `Validate` do GitHub Actions passou no ultimo commit consultado.
- Isso comprova build, testes e smoke tests do workflow, mas nao comprova sync completo em
  producao.
- O endpoint publico observado `https://padaria-debortolo-api-8w5w.onrender.com/api/health`
  retornou HTTP 503.
- O endpoint publico `/api/estoque` tambem retornou HTTP 503.
- Antes de declarar a integracao pronta, corrigir a configuracao do Render, o arquivo do
  Drive e os segredos necessarios.

---

## 2. Enderecos atuais

O codigo observado separa os enderecos por plataforma:

- Desktop local: `http://localhost:5049`.
- Emulador Android: preferir `http://10.0.2.2:5049` quando a API estiver no PC.
- Celular fisico: IP LAN do computador, por exemplo `http://192.168.1.101:5049`.
- Web local: `http://localhost:5049` para a API e porta separada para o Flutter Web.
- API Render: `https://padaria-debortolo-api-8w5w.onrender.com` quando estiver configurada.

Regra importante: `localhost` no celular aponta para o celular, nao para o computador.

---

## 3. Arquitetura escolhida: API central

Todos os clientes devem apontar para a mesma API que possui acesso ao banco principal:

```text
Desktop ─┐
Mobile  ─┼──> https://api-central-ou-host-local ──> SQL Server
Web     ─┘
```

### O que nao fazer

- Nao colocar senha do SQL Server no APK ou no Web.
- Nao fazer o mobile conectar diretamente no SQL Server.
- Nao usar o Google Drive como banco em tempo real.
- Nao deixar duas bases locais sobrescreverem o mesmo `estoque.json` sem fila/conflito.
- Nao apagar vendas, pagamentos ou itens para remover um produto.

### O que fazer

- Manter o SQL Server como fonte oficial.
- Manter os contratos REST atuais.
- Configurar uma unica `API_BASE_URL` para cada ambiente.
- Usar o Google Drive somente para copia de backup e snapshot de consulta.
- Fazer o servidor validar estoque e totais de venda.
- Usar `device_id`, `clientUuid` e fila offline para operacoes feitas sem rede.

---

## 4. Como conectar o Web aos mesmos aplicativos

### Caso os contratos sejam iguais

Nao alterar as APIs. Apenas configurar o Web para consumir a API central:

1. Definir `API_BASE_URL` no ambiente Web.
2. Usar os endpoints existentes de produtos, estoque, vendas e relatorios.
3. Confirmar que os nomes JSON sao os mesmos (`id_produto`, `nome_produto`,
   `quantidade_estoque`, `formaPagamento`, `itens`).
4. Liberar CORS para o dominio Web.
5. Testar Web, mobile e desktop contra a mesma URL.

### Caso existam diferencas

Adicionar um adapter/servico no Web ou na API, sem alterar os controllers existentes:

```text
Web Infinite Coffee -> Adapter -> API Debortolo
```

O adapter traduz nomes de campos e respostas. So criar endpoint novo quando o contrato
realmente nao existir.

---

## 5. Banco principal e bancos locais

### Recomendacao principal

Ter um SQL Server central acessivel pela API e usar armazenamento local do app somente como
cache/fila offline. Assim, os clientes nao precisam de um SQL Server completo em cada PC.

```text
API central -> SQL Server principal
App        -> cache local + fila offline
```

### Se cada computador realmente tiver SQL Server local

Cada instalacao precisa de:

- SQL Server Express ou LocalDB.
- Banco `infiniteCoffee` criado pelo script idempotente.
- API local com string de conexao protegida.
- `device_id` exclusivo.
- Log de operacoes locais.
- Push de operacoes para a API central.
- Pull de alteracoes confirmadas.
- Regra clara de conflito.

Nesse modelo, o Google Drive pode distribuir um snapshot inicial ou backup, mas nao deve
mesclar automaticamente duas escritas simultaneas.

---

## 6. Google Drive: configuracao correta

O Google Drive deve receber um backup produzido pelo servidor local/central.

### Variaveis do servidor

- `GOOGLE_DRIVE_OAUTH_CLIENT_PATH`: caminho fora do repositorio para o JSON OAuth.
- `GOOGLE_DRIVE_FOLDER_ID`: pasta de destino.
- `GOOGLE_DRIVE_SNAPSHOT_NAME`: normalmente `estoque.json`.
- `GOOGLE_DRIVE_SNAPSHOT_FILE_ID`: arquivo que o Web snapshot-only pode ler.

Nunca versionar o JSON OAuth, refresh token, senha ou chave privada.

### Tipos de backup

- `estoque.json`: snapshot operacional para consultas do Web.
- `.bak`: backup completo do SQL Server para restauração.
- O `.json` nao substitui o `.bak`.
- O Drive nao deve ser usado para decidir qual venda ganhou.

### Fluxo de upload

1. API local consulta SQL Server.
2. API monta snapshot ou executa backup.
3. API autentica no Google Drive por OAuth guardado no servidor.
4. API cria/atualiza um arquivo na pasta configurada.
5. Web pode ler o snapshot publicado.
6. Alteracoes nunca sao gravadas pelo Web diretamente no Drive.

---

## 7. Sync offline e bidirecional

### Push

```http
POST /api/sync/push
Content-Type: application/json
```

Exemplo:

```json
{
  "operacoes": [
    {
      "tipo": "venda",
      "clientUuid": "device-abc-123",
      "payload": {
        "formaPagamento": "Pix",
        "itens": [
          { "produtoId": 1, "quantidade": 2 }
        ]
      }
    }
  ]
}
```

O servidor deve:

- Validar todos os campos.
- Revalidar estoque.
- Executar pedido, itens, pagamento e baixa na mesma transacao.
- Registrar o `clientUuid` processado para impedir duplicacao.
- Responder quais operacoes foram aceitas ou rejeitadas.

### Pull

```http
GET /api/sync/pull?since=TOKEN
```

O servidor retorna produtos/movimentacoes alterados e um novo `serverTime` ou token.

O cliente deve:

1. Aplicar upsert no armazenamento local.
2. Atualizar o token somente depois de processar a resposta.
3. Tratar tombstones de produtos inativados.
4. Preservar operacoes pendentes que foram rejeitadas.

### Conflitos

- Estoque: servidor decide.
- Catalogo: `modified_at`/versao do servidor.
- Venda: append-only e idempotente por `clientUuid`.
- Produto removido: inativar com `ativo = 0`; nao excluir historico.

---

## 8. Preservacao de APIs

Os endpoints existentes devem continuar funcionando:

- `GET /api/produtos`
- `POST /api/produtos`
- `GET /api/estoque`
- `POST /api/estoque/entrada`
- `POST /api/estoque/saida`
- `POST /api/vendas`
- `GET /api/relatorios/vendas`
- `GET /api/relatorios/estoque`
- `GET /api/health`
- `GET /api/estoque/snapshot`
- `POST /api/estoque/backup`

Novos endpoints de integracao podem ser adicionados, por exemplo:

- `GET /api/integracao/status`
- `POST /api/sync/push`
- `GET /api/sync/pull`
- `GET /api/sync/versao`

Nao remover rotas nem trocar nomes de campos sem adapter e plano de migracao.

---

## 9. Plano de implementacao para a IA

### Fase 1 — Diagnostico

1. Clonar `padaria-debortolo`.
2. Confirmar branch de trabalho autorizada.
3. Ler `AGENTS.md`, `DOCUMENTACAO-IA.md`, `README.md` e `Backlog-Sync.md`.
4. Mapear todos os clientes e URLs atuais.
5. Verificar health do Render e logs.
6. Confirmar banco principal e ambiente local.

### Fase 2 — API central

1. Escolher a API do Debortolo como API central.
2. Preservar controllers existentes.
3. Corrigir `API_BASE_URL` por plataforma.
4. Garantir CORS para Web.
5. Garantir autenticação sem credenciais no cliente.
6. Testar produtos, estoque, vendas e relatorios.

### Fase 3 — Banco e backup

1. Criar/validar schema idempotente.
2. Adicionar `modified_at`, `ativo`, `device_id` e controle de operacao quando necessario.
3. Configurar OAuth do Google Drive no servidor.
4. Publicar snapshot `.json` e backup `.bak`.
5. Confirmar que Drive e somente backup.

### Fase 4 — Clientes

1. Fazer desktop, mobile e Web apontarem para a API central.
2. Manter cache/fila offline no cliente.
3. Implementar pull depois do push.
4. Atualizar a interface sem piscar durante sync.
5. Mostrar erro de API, offline e conflito separadamente.

### Fase 5 — Validacao

1. Cadastrar produto no desktop e confirmar no mobile/Web.
2. Registrar entrada no mobile e confirmar no desktop.
3. Fazer venda no desktop e confirmar baixa no mobile/Web.
4. Desligar a rede, fazer venda e reconectar.
5. Reenviar a mesma operacao e confirmar que nao duplica.
6. Inativar produto com venda e confirmar preservacao do historico.
7. Fazer backup no Drive e restaurar em ambiente de teste.
8. Validar `/api/health`, Swagger e workflow do GitHub.

---

## 10. Comandos esperados

Backend:

```powershell
dotnet restore InfiniteCoffee2.slnx
dotnet build InfiniteCoffee2.slnx --no-restore
dotnet test InfiniteCoffee2.slnx --no-restore
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

## Regras obrigatorias para o agente

- Trabalhar no `padaria-debortolo`, nao no `pideias-infinittecoffee`.
- Confirmar branch antes de commit/push.
- Nao commitar credenciais.
- Nao apagar historico de venda.
- Nao usar Google Drive como banco.
- Nao alterar todas as APIs quando um adapter resolver.
- Sempre testar localmente antes de declarar pronto.
- Registrar neste documento qualquer mudanca de arquitetura, URL, schema ou contrato.

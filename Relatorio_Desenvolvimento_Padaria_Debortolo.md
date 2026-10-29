# DESENVOLVIMENTO DA SOLUÇÃO MOBILE

Esta seção descreve a implementação do aplicativo demonstrativo Padaria Debortolo e sua comunicação com os serviços que atendem às operações de produtos, estoque e vendas. O nome anterior do projeto era Infinite Coffee; neste trabalho, a aplicação apresentada é a Padaria Debortolo.

## Tecnologias e interface

O cliente foi desenvolvido em Flutter, com código em Dart. A mesma base pode ser compilada para Android, Windows e Web. A interface se adapta à largura disponível: no Android utiliza navegação inferior; no Windows, apresenta navegação lateral. O tema visual aplica cores em tons de marrom e laranja, cartões, campos de pesquisa e componentes Material (PADARIA DEBORTOLO, 2026c; PADARIA DEBORTOLO, 2026d).

O ponto de entrada configura o tema e instancia o repositório de inventário. Esse repositório coordena a tela inicial e o serviço de comunicação. O modelo `Product` converte os campos recebidos em JSON — como `id_produto`, `nome_produto`, `preco` e `quantidade_estoque` — em objetos Dart utilizados pela interface (PADARIA DEBORTOLO, 2026c).

## Funcionalidades implementadas

A navegação principal apresenta seis áreas: **Início**, **Produtos**, **Estoque**, **PDV**, **Vendas** e **Relatórios**. O painel inicial exibe a quantidade de produtos cadastrados, o valor estimado do estoque e um alerta visual para produtos com cinco unidades ou menos.

Na área **Produtos**, o usuário pesquisa pelo nome ou código de barras, cadastra produtos, altera informações e solicita a inativação de itens. A busca não diferencia maiúsculas, minúsculas ou acentos e filtra o catálogo localmente enquanto o usuário digita.

Na área **Estoque**, são registradas entradas e saídas com quantidade e motivo. O saldo é exibido junto ao produto, com mensagens de confirmação ou erro. A interface também permite atualizar a consulta do estoque.

O **PDV** permite selecionar produtos, montar e alterar o carrinho, informar o cliente e escolher a forma de pagamento. O total mostrado no cliente é uma estimativa; o servidor consulta os preços e o estoque atuais antes de confirmar a venda. A área **Vendas** apresenta o histórico consultado na API (PADARIA DEBORTOLO, 2026b; PADARIA DEBORTOLO, 2026c).

A nova área **Relatórios** apresenta um gráfico de pizza com a participação dos produtos nos pedidos finalizados e pagos. O usuário pode alternar entre quantidade de unidades vendidas e faturamento por produto, tocar nas fatias/legendas para destacá-las e atualizar os dados pelo botão de recarga. Para manter o gráfico legível, os cinco maiores resultados aparecem individualmente e os demais são agrupados em “Outros produtos”. A consulta considera todo o histórico disponível de pedidos finalizados e pagos; não há filtro por data nesta versão.

## Persistência local e sincronização

O repositório consulta `GET /api/estoque`. Quando recebe os dados, grava o catálogo localmente com `shared_preferences`, na chave `cached_products`. Se a API não responder, a tela pode apresentar o último catálogo salvo e indicar que os dados estão offline.

Entradas, saídas e vendas que não podem ser enviadas por uma falha temporária de conexão ficam na fila `pending_stock_exits`, junto a um identificador `clientUuid`. Quando a conexão retorna ou o usuário atualiza os dados, o aplicativo envia as operações para `POST /api/sync/push`. O servidor retorna os identificadores aceitos; as operações não aceitas permanecem na fila para nova tentativa. O SQL Server registra os identificadores já processados para evitar aplicar novamente uma operação repetida (PADARIA DEBORTOLO, 2026a; PADARIA DEBORTOLO, 2026b; PADARIA DEBORTOLO, 2026c).

O funcionamento offline cobre consulta do catálogo e fila de operações de estoque e venda. Cadastro e edição de produtos, assim como a consulta do histórico de vendas, dependem da API. O cache local é uma cópia de apoio; o servidor continua responsável por confirmar saldo e venda.

# PROJETO DO BANCO DE DADOS

O banco é relacional e utiliza SQL Server. O script idempotente de instalação cria o banco e as tabelas que ainda não existem, sem remover tabelas já presentes. O nome técnico do banco no script é `infiniteCoffee`, identificador interno anterior do projeto; o nome do aplicativo demonstrativo descrito neste trabalho é Padaria Debortolo (PADARIA DEBORTOLO, 2026a).

As tabelas utilizam chaves primárias inteiras com incremento automático e chaves estrangeiras para relacionar os dados. A tabela a seguir resume as entidades que participam do cadastro, do estoque e das vendas.

| Entidade | Campos principais e chaves | Finalidade |
|---|---|---|
| `Produtos` | `id_produto` (PK), `nome_produto`, `preco`, `tipo`, `quantidade_estoque`, `codigo_barras`, `descricao`, `ativo`, `modified_at` | Cadastro, preço e saldo atual dos produtos. |
| `Clientes` | `id_cliente` (PK), `nome_cliente`, `email`, `telefone` | Dados do cliente associado ao pedido. |
| `Funcionarios` | `id_funcionario` (PK), `nome_funcionario`, `cargo` | Funcionários associados aos pedidos. |
| `Mesas` | `id_mesa` (PK), `numero`, `capacidade`, `status_mesa` | Identificação e situação das mesas relacionadas a pedidos. |
| `Pedidos` | `id_pedido` (PK), `mesaid`, `funcionarioid`, `clienteid`, `datahora`, `status_pedido` | Cabeçalho do pedido; mesa, funcionário e cliente podem ser nulos. |
| `Itens_Pedidos` | `id_itens_pedidos` (PK), `pedidoid` (FK), `produtoid` (FK), `quantidade`, `preco_unitario` | Produtos e quantidades pertencentes ao pedido, com o preço registrado na venda. |
| `Pagamentos` | `id_pagamento` (PK), `pedidoid` (FK), `forma_pagamento`, `valor_total` | Forma e valor do pagamento associado ao pedido. |
| `MovimentacoesEstoque` | `id_movimentacao` (PK), `produtoid` (FK), `tipo_movimentacao`, `quantidade`, `motivo`, `data_movimentacao`, `modified_at` | Histórico de entradas e saídas de produtos. |
| `SyncOperations` | `client_uuid` (PK), `tipo`, `created_at` | Identificadores de operações recebidas pela sincronização. |

Fonte: elaboração própria com base no script de instalação e na camada de dados (PADARIA DEBORTOLO, 2026a; PADARIA DEBORTOLO, 2026b).

As chaves primárias usam `INT IDENTITY`. Quantidades são armazenadas como inteiros; valores monetários, como `DECIMAL(10,2)`; indicadores de situação, como `BIT`; e datas em `DATETIME` ou `DATETIME2`. Campos opcionais, como e-mail, telefone, código de barras e descrição do produto, aceitam valor nulo conforme o esquema definido no script (PADARIA DEBORTOLO, 2026a).

## Relacionamentos e integridade

Um cliente, funcionário ou mesa pode estar relacionado a vários pedidos. `Pedidos.clienteid`, `Pedidos.funcionarioid` e `Pedidos.mesaid` são chaves estrangeiras opcionais. Cada item de pedido referencia um pedido e um produto; pagamentos referenciam o pedido; movimentações de estoque referenciam o produto. Assim, itens, pagamentos e movimentações mantêm a ligação com seus registros de origem.

A tabela `Itens_Pedidos` guarda `preco_unitario` no momento da venda, além da referência ao produto. Desse modo, o pedido conserva o preço praticado no momento da operação. Produtos associados ao histórico não são apagados fisicamente: a API os inativa (`ativo = 0`) e zera seu saldo, preservando pedidos e movimentações relacionados (PADARIA DEBORTOLO, 2026b).

O relatório de vendas por produto utiliza essas linhas persistidas: soma `quantidade` e `quantidade * preco_unitario`, agrupando por produto e considerando pedidos com status `Finalizado` e pagamento registrado. A agregação é executada no backend, sem criar uma tabela ou alterar o schema; os valores agregados são enviados ao cliente pelo endpoint `GET /api/relatorios/vendas/produtos` (PADARIA DEBORTOLO, 2026b).

## Gravações transacionais

Entradas e saídas de estoque são executadas em transação: o backend atualiza a quantidade do produto e registra a movimentação correspondente. A saída só é aceita quando existe saldo suficiente.

A venda também é processada em uma transação. O servidor valida os itens, recupera os preços atuais, verifica e baixa o estoque e grava pedido, itens, pagamento e movimentações. Se a validação de um produto ou do saldo falhar, a venda não é confirmada como concluída. Essas regras mantêm os dados relacionados consistentes no SQL Server (PADARIA DEBORTOLO, 2026b).

# ARQUITETURA DE SOFTWARE

## Organização em camadas

A solução separa a interface Flutter, o armazenamento local do cliente, a comunicação HTTP, a API e o banco de dados. O aplicativo envia requisições REST com JSON. Os controladores ASP.NET Core validam as solicitações e chamam a classe `Banco.cs`, que concentra o acesso ao SQL Server. A string de conexão fica no backend e não é incorporada ao aplicativo (PADARIA DEBORTOLO, 2026b; PADARIA DEBORTOLO, 2026c).

| Camada | Responsabilidade | Componentes |
|---|---|---|
| Aplicativo mobile/desktop | Interface e ações do usuário. | Flutter, Dart, `HomeScreen`, `SalesReportScreen`, modelo `Product` |
| Repositório e persistência local | Carregar o catálogo, manter cache e fila pendente. | `InventoryRepository`, `shared_preferences` |
| Comunicação | Enviar e receber dados JSON pela rede. | `InventoryApi`, HTTP REST |
| Backend | Expor endpoints e aplicar validações e regras. | ASP.NET Core, controladores da API |
| Acesso a dados | Consultar e alterar registros, incluindo transações. | `Banco.cs`, SQL parametrizado e procedures |
| Banco oficial | Persistir catálogo, estoque, pedidos, pagamentos e histórico. | SQL Server |

Fonte: elaboração própria com base no código-fonte do cliente e do backend (2026).

## Fluxo das operações

Na consulta do estoque, o cliente solicita os produtos à API; o backend consulta o SQL Server e devolve o resultado em JSON. O aplicativo converte os objetos para o modelo `Product`, atualiza o cache e apresenta a lista. Se a consulta falhar, carrega a cópia local disponível.

Nas operações de estoque, o cliente envia produto, quantidade e motivo. O backend valida os dados, altera o saldo e grava a movimentação. Na venda, o aplicativo envia cliente, pagamento e itens; o servidor confirma preço e disponibilidade antes de persistir a transação. Se o cliente estiver offline, as operações compatíveis ficam em fila e são reenviadas quando houver conexão.

| Operação do cliente | Endpoint da API |
|---|---|
| Consultar estoque | `GET /api/estoque` |
| Cadastrar produto | `POST /api/produtos` |
| Atualizar ou inativar produto | `PUT /api/produtos/{id}` ou `DELETE /api/produtos/{id}` |
| Registrar entrada ou saída | `POST /api/estoque/entrada` ou `POST /api/estoque/saida` |
| Finalizar venda | `POST /api/vendas` |
| Consultar histórico | `GET /api/relatorios/vendas/historico` |
| Enviar operações pendentes | `POST /api/sync/push` |

Fonte: elaboração própria com base nos controladores da API e no cliente HTTP do aplicativo (2026).

O gráfico da aba **Relatórios** obtém os valores agregados de `GET /api/relatorios/vendas/produtos`; o backend agrupa unidades e faturamento dos pedidos finalizados e pagos por produto.

## Validação

Foram executados `flutter analyze` e `flutter test` no projeto mobile. A análise estática não apontou problemas e os testes disponíveis foram aprovados. Os cenários incluem a recuperação do catálogo após falha de conexão, pesquisa por nome/código de barras e carregamento do relatório agregado por produto na nova aba. As capturas a seguir foram feitas antes da inclusão da aba **Relatórios**; portanto, elas documentam as demais telas do aplicativo, não o gráfico novo.

# REFERÊNCIAS DESTA PARTE

PADARIA DEBORTOLO. **DatabaseScripts/InstallDatabase.sql: script de criação e inicialização do banco de dados**. Repositório do projeto, 2026a. Acesso em: 7 out. 2026.

PADARIA DEBORTOLO. **InfiniteCoffee2: API e persistência de dados**. Repositório do projeto, 2026b. Arquivos consultados: `Controllers/Api/EstoqueApiController.cs`, `Controllers/Api/ProdutosApiController.cs`, `Controllers/Api/VendasApiController.cs`, `Controllers/Api/SyncApiController.cs` e `Data/Banco.cs`. Acesso em: 7 out. 2026.

PADARIA DEBORTOLO. **InfiniteCoffeeMobile: código-fonte Flutter**. Repositório do projeto, 2026c. Arquivos consultados: `lib/main.dart`, `lib/screens/home_screen.dart`, `lib/screens/sales_report_screen.dart`, `lib/repositories/inventory_repository.dart`, `lib/services/inventory_api.dart`, `lib/models/product.dart`, `lib/models/sales_by_product.dart` e testes automatizados. Acesso em: 7 out. 2026.

PADARIA DEBORTOLO. **README do projeto (nome anterior: Infinite Coffee)**. Repositório do projeto, 2026d. Acesso em: 7 out. 2026.

# REGISTROS VISUAIS DO APLICATIVO

As figuras foram organizadas como material desta seção para facilitar sua incorporação ao documento coletivo. A captura da lista de produtos no Android não foi utilizada porque continha a sobreposição dos controles de captura de tela.

**Figura 1 – Painel inicial no Windows**

![Painel inicial do aplicativo Padaria Debortolo no Windows](<fotos/Captura de tela 2026-10-07 152543.png>)

Fonte: captura de tela fornecida pela equipe do projeto (2026).

<!-- QUEBRA DE PÁGINA -->

**Figura 2 – Produtos no Windows**

![Consulta de produtos no aplicativo Padaria Debortolo no Windows](<fotos/Captura de tela 2026-10-07 152607.png>)

Fonte: captura de tela fornecida pela equipe do projeto (2026).

<!-- QUEBRA DE PÁGINA -->

**Figura 3 – Estoque no Windows**

![Controle de estoque no aplicativo Padaria Debortolo no Windows](<fotos/Captura de tela 2026-10-07 152620.png>)

Fonte: captura de tela fornecida pela equipe do projeto (2026).

<!-- QUEBRA DE PÁGINA -->

**Figura 4 – Ponto de venda no Windows**

![Ponto de venda no aplicativo Padaria Debortolo no Windows](<fotos/Captura de tela 2026-10-07 152629.png>)

Fonte: captura de tela fornecida pela equipe do projeto (2026).

<!-- QUEBRA DE PÁGINA -->

**Figura 5 – Histórico de vendas no Windows**

![Histórico de vendas no aplicativo Padaria Debortolo no Windows](<fotos/Captura de tela 2026-10-07 152636.png>)

Fonte: captura de tela fornecida pela equipe do projeto (2026).

<!-- QUEBRA DE PÁGINA -->

**Figura 6 – Painel inicial no Android**

![Painel inicial do aplicativo Padaria Debortolo no Android](<fotos/0753cc89-221b-4dcf-8979-58b08a0d9b7f.jpg>)

Fonte: captura de tela fornecida pela equipe do projeto (2026).

<!-- QUEBRA DE PÁGINA -->

**Figura 7 – Estoque no Android**

![Controle de estoque no aplicativo Padaria Debortolo no Android](<fotos/641bde09-cbfa-41bf-ab8a-222d1bb0d664.jpg>)

Fonte: captura de tela fornecida pela equipe do projeto (2026).

<!-- QUEBRA DE PÁGINA -->

**Figura 8 – Ponto de venda no Android**

![Ponto de venda no aplicativo Padaria Debortolo no Android](<fotos/9870436f-8eb4-40be-b621-404b9414f4bc.jpg>)

Fonte: captura de tela fornecida pela equipe do projeto (2026).

<!-- QUEBRA DE PÁGINA -->

**Figura 9 – Histórico de vendas no Android**

![Histórico de vendas no aplicativo Padaria Debortolo no Android](<fotos/caa7d37e-0783-44e6-86c2-68757bb4fc5d.jpg>)

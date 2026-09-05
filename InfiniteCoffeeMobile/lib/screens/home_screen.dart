import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../models/product.dart';
import '../repositories/inventory_repository.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.repository});
  final InventoryRepository repository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String _search = '';
  final Map<int, CartLine> _cart = {};
  late Future<InventorySnapshot> _stock;
  Timer? _refreshTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _stock = widget.repository.load();
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 30),
      (_) => _reload(_search),
    );
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      if (results.any((result) => result != ConnectivityResult.none) &&
          mounted) {
        _reload(_search);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  void _reload([String search = '']) {
    setState(() {
      _search = search;
      _stock = widget.repository.load(search: search);
    });
  }

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 900;
    final content = FutureBuilder<InventorySnapshot>(
      future: _stock,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return _ErrorView(onRetry: _reload);
        final data =
            snapshot.data ??
            const InventorySnapshot(products: [], isOffline: true);
        return _selectedIndex == 0
            ? _Dashboard(
                products: data.products,
                offline: data.isOffline,
                onOpenStock: () => setState(() => _selectedIndex = 2),
              )
            : _selectedIndex == 1
            ? _ProductsView(products: data.products, onSearch: _reload)
            : _selectedIndex == 2
            ? _StockView(
                products: data.products,
                offline: data.isOffline,
                errorMessage: data.errorMessage,
                search: _search,
                onSearch: _reload,
                onExit: _registerExit,
                onEntry: _registerEntry,
                onCreateProduct: _showProductDialog,
                onSync: _syncNow,
              )
            : _selectedIndex == 3
            ? _SaleView(
                products: data.products,
                search: _search,
                onSearch: _reload,
                cart: _cart.values.toList(),
                onAdd: _addToCart,
                onRemove: _removeFromCart,
                onFinish: _finishSale,
              )
            : _SalesHistory(repository: widget.repository);
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Padaria Debortolo'),
        toolbarHeight: desktop ? 76 : null,
        actions: [
          if (desktop)
            const Padding(
              padding: EdgeInsets.only(left: 8, right: 24),
              child: Center(
                child: Text(
                  'GESTÃO DA PADARIA',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: desktop
          ? Row(
              children: [
                _DesktopNavigation(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) =>
                      setState(() => _selectedIndex = index),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1440),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: content,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : content,
      bottomNavigationBar: desktop
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) =>
                  setState(() => _selectedIndex = index),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Início',
                ),
                NavigationDestination(
                  icon: Icon(Icons.local_cafe_outlined),
                  selectedIcon: Icon(Icons.local_cafe),
                  label: 'Produtos',
                ),
                NavigationDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory_2),
                  label: 'Estoque',
                ),
                NavigationDestination(
                  icon: Icon(Icons.point_of_sale_outlined),
                  selectedIcon: Icon(Icons.point_of_sale),
                  label: 'PDV',
                ),
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long),
                  label: 'Vendas',
                ),
              ],
            ),
    );
  }

  Future<void> _syncNow() async {
    await _runSync('Banco de dados atualizado.');
  }

  Future<void> _runSync(String successMessage) async {
    setState(() => _stock = widget.repository.syncNow(search: _search));
    final result = await _stock;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isOffline
              ? result.errorMessage ?? 'Sincronizacao pendente.'
              : successMessage,
        ),
      ),
    );
  }

  Future<void> _registerExit(Product product) async {
    final quantity = await _showMovementDialog(
      product,
      'Venda: ${product.name}',
      'Saída pelo aplicativo',
    );
    if (quantity == null || !mounted) return;
    final result = await widget.repository.registerExit(
      product: product,
      quantity: quantity.quantity,
      reason: quantity.reason,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(result.message)));
    if (result.success) _reload(_search);
  }

  void _addToCart(Product product) {
    final current = _cart[product.id]?.quantity ?? 0;
    if (current >= product.quantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quantidade maior que o estoque disponível.'),
        ),
      );
      return;
    }
    setState(
      () =>
          _cart[product.id] = CartLine(product: product, quantity: current + 1),
    );
  }

  void _removeFromCart(Product product) {
    setState(() {
      final current = _cart[product.id];
      if (current == null || current.quantity <= 1) {
        _cart.remove(product.id);
      } else {
        _cart[product.id] = CartLine(
          product: product,
          quantity: current.quantity - 1,
        );
      }
    });
  }

  Future<void> _finishSale(String customer, String payment) async {
    if (_cart.isEmpty) return;
    final result = await widget.repository.createSale(
      customer: customer,
      payment: payment,
      items: _cart.values
          .map(
            (line) => {
              'produtoId': line.product.id,
              'quantidade': line.quantity,
            },
          )
          .toList(),
    );
    final success = result.success;
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(result.message)));
    if (success) {
      setState(() => _cart.clear());
      _reload();
    }
  }

  Future<void> _showProductDialog() async {
    final name = TextEditingController();
    final description = TextEditingController();
    final barcode = TextEditingController();
    final price = TextEditingController();
    final quantity = TextEditingController(text: '0');
    final type = TextEditingController(text: 'Produto');
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cadastrar produto'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nome'),
              ),
              TextField(
                controller: description,
                decoration: const InputDecoration(labelText: 'Descrição'),
              ),
              TextField(
                controller: barcode,
                decoration: const InputDecoration(
                  labelText: 'Código de barras',
                ),
              ),
              TextField(
                controller: price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Preço'),
              ),
              TextField(
                controller: quantity,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantidade inicial',
                ),
              ),
              TextField(
                controller: type,
                decoration: const InputDecoration(labelText: 'Categoria/tipo'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final result = await widget.repository.createProduct(
                name: name.text,
                description: description.text,
                barcode: barcode.text,
                type: type.text,
                price: double.tryParse(price.text.replaceAll(',', '.')) ?? 0,
                quantity: int.tryParse(quantity.text) ?? -1,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(result.message)));
                Navigator.pop(context, result.success);
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (created == true && mounted) _reload();
  }

  Future<void> _registerEntry(Product product) async {
    final movement = await _showMovementDialog(
      product,
      'Entrada: ${product.name}',
      'Reposição de estoque',
    );
    if (movement == null || !mounted) return;
    final result = await widget.repository.registerEntry(
      product: product,
      quantity: movement.quantity,
      reason: movement.reason,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(result.message)));
    if (result.success) _reload(_search);
  }

  Future<_ExitData?> _showMovementDialog(
    Product product,
    String title,
    String defaultReason,
  ) {
    final quantity = TextEditingController(text: '1');
    final reason = TextEditingController(text: defaultReason);
    return showDialog<_ExitData>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Saldo disponível: ${product.quantity} unidades'),
            const SizedBox(height: 12),
            TextField(
              controller: quantity,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantidade'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reason,
              decoration: const InputDecoration(labelText: 'Motivo'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = int.tryParse(quantity.text) ?? 0;
              if (value > 0) {
                Navigator.pop(context, _ExitData(value, reason.text));
              }
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }
}

class _DesktopNavigation extends StatelessWidget {
  const _DesktopNavigation({
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 236,
      decoration: const BoxDecoration(
        color: Color(0xFFFFFBF7),
        border: Border(right: BorderSide(color: Color(0xFFE6DCD2))),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 16, 20),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5E5D7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.local_cafe, color: Color(0xFFB5541A)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Padaria\nDebortolo',
                    style: TextStyle(
                      color: Color(0xFF2C1A0E),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, indent: 20, endIndent: 20),
          const SizedBox(height: 16),
          Expanded(
            child: NavigationRail(
              extended: true,
              minExtendedWidth: 236,
              backgroundColor: Colors.transparent,
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              labelType: NavigationRailLabelType.none,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: Text('Início'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.local_cafe_outlined),
                  selectedIcon: Icon(Icons.local_cafe),
                  label: Text('Produtos'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory_2),
                  label: Text('Estoque'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.point_of_sale_outlined),
                  selectedIcon: Icon(Icons.point_of_sale),
                  label: Text('PDV'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long),
                  label: Text('Vendas'),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'PAINEL ADMINISTRATIVO',
                style: TextStyle(
                  color: Color(0xFF8B7B70),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({
    required this.products,
    required this.offline,
    required this.onOpenStock,
  });
  final List<Product> products;
  final bool offline;
  final VoidCallback onOpenStock;

  @override
  Widget build(BuildContext context) {
    final low = products.where((product) => product.quantity <= 5).toList();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'PAINEL DA CASA',
          style: TextStyle(
            color: Color(0xFFB5541A),
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Text('Olá, equipe!', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          offline
              ? 'Modo offline: mostrando os últimos dados salvos.'
              : 'Dados sincronizados com o servidor.',
          style: const TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 24),
        if (low.isNotEmpty)
          Card(
            color: const Color(0xFFFFF0C9),
            child: ListTile(
              leading: const Icon(
                Icons.warning_amber,
                color: Color(0xFFC88A20),
              ),
              title: Text('${low.length} produto(s) com estoque baixo'),
              subtitle: Text(
                low.map((item) => '${item.name} (${item.quantity})').join(', '),
              ),
              onTap: onOpenStock,
            ),
          ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.inventory_2),
            title: const Text('Controle de estoque'),
            subtitle: Text('${products.length} produtos cadastrados'),
            trailing: const Icon(Icons.arrow_forward),
            onTap: onOpenStock,
          ),
        ),
      ],
    );
  }
}

class _ProductsView extends StatelessWidget {
  const _ProductsView({required this.products, required this.onSearch});
  final List<Product> products;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) =>
      _ProductList(title: 'Produtos', products: products, onSearch: onSearch);
}

class _StockView extends StatelessWidget {
  const _StockView({
    required this.products,
    required this.offline,
    this.errorMessage,
    required this.search,
    required this.onSearch,
    required this.onExit,
    required this.onEntry,
    required this.onCreateProduct,
    required this.onSync,
  });
  final List<Product> products;
  final bool offline;
  final String? errorMessage;
  final String search;
  final ValueChanged<String> onSearch;
  final ValueChanged<Product> onExit;
  final ValueChanged<Product> onEntry;
  final VoidCallback onCreateProduct;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final low = products.where((product) => product.quantity <= 5).length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onSync,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Atualizar banco'),
                ),
                ElevatedButton.icon(
                  onPressed: onCreateProduct,
                  icon: const Icon(Icons.add_box_outlined),
                  label: const Text('Cadastrar produto'),
                ),
              ],
            ),
          ),
        ),
        if (offline)
          MaterialBanner(
            content: Text(
              errorMessage ?? 'Consulta offline: mostrando o cache local.',
            ),
            actions: [SizedBox.shrink()],
          ),
        if (low > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Card(
              color: const Color(0xFFFFF0C9),
              child: ListTile(
                leading: const Icon(
                  Icons.warning_amber,
                  color: Color(0xFFC88A20),
                ),
                title: Text('$low produto(s) precisam de reposição'),
                subtitle: const Text('Limite configurado: 5 unidades.'),
              ),
            ),
          ),
        Expanded(
          child: _ProductList(
            title: 'Estoque',
            products: products,
            search: search,
            onSearch: onSearch,
            onExit: onExit,
            onEntry: onEntry,
          ),
        ),
      ],
    );
  }
}

class _ProductList extends StatelessWidget {
  const _ProductList({
    required this.title,
    required this.products,
    required this.onSearch,
    this.search = '',
    this.onExit,
    this.onEntry,
    this.onAdd,
  });
  final String title;
  final List<Product> products;
  final String search;
  final ValueChanged<String> onSearch;
  final ValueChanged<Product>? onExit;
  final ValueChanged<Product>? onEntry;
  final ValueChanged<Product>? onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: onSearch,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Pesquisar nome ou código de barras',
              suffixIcon: search.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () => onSearch(''),
                      icon: const Icon(Icons.clear),
                    ),
            ),
          ),
        ),
        Expanded(
          child: products.isEmpty
              ? const Center(child: Text('Nenhum produto encontrado.'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final low = product.quantity <= 5;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        title: Text(
                          product.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${product.type} • ${product.barcode ?? 'Sem código'}',
                        ),
                        trailing:
                            onExit == null && onEntry == null && onAdd == null
                            ? Text('${product.quantity} un.')
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${product.quantity} un.',
                                    style: TextStyle(
                                      color: low ? Colors.red : Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (onEntry != null)
                                    IconButton(
                                      tooltip: 'Registrar entrada',
                                      onPressed: () => onEntry!(product),
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                      ),
                                    ),
                                  if (onExit != null)
                                    IconButton(
                                      tooltip: 'Registrar saída',
                                      onPressed: product.quantity == 0
                                          ? null
                                          : () => onExit!(product),
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                      ),
                                    ),
                                  if (onAdd != null)
                                    IconButton(
                                      tooltip: 'Adicionar à venda',
                                      onPressed: product.quantity == 0
                                          ? null
                                          : () => onAdd!(product),
                                      icon: const Icon(Icons.add_shopping_cart),
                                    ),
                                ],
                              ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// O PDV mantém o cliente e a forma de pagamento enquanto o carrinho e montado.
class _SaleView extends StatefulWidget {
  const _SaleView({
    required this.products,
    required this.search,
    required this.onSearch,
    required this.cart,
    required this.onAdd,
    required this.onRemove,
    required this.onFinish,
  });
  final List<Product> products;
  final String search;
  final ValueChanged<String> onSearch;
  final List<CartLine> cart;
  final ValueChanged<Product> onAdd;
  final ValueChanged<Product> onRemove;
  final Future<void> Function(String customer, String payment) onFinish;

  @override
  State<_SaleView> createState() => _SaleViewState();
}

class _SaleViewState extends State<_SaleView> {
  final _customer = TextEditingController();
  String _payment = 'Pix';

  @override
  Widget build(BuildContext context) {
    final total = widget.cart.fold<double>(
      0,
      (sum, line) => sum + line.product.price * line.quantity,
    );
    return Column(
      children: [
        Card(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Carrinho (${widget.cart.length} itens)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'R\$ ${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                TextField(
                  controller: _customer,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Cliente'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _payment,
                  decoration: const InputDecoration(
                    labelText: 'Forma de pagamento',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Pix', child: Text('Pix')),
                    DropdownMenuItem(value: 'Cartão', child: Text('Cartão')),
                    DropdownMenuItem(
                      value: 'Dinheiro',
                      child: Text('Dinheiro'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _payment = value ?? 'Pix'),
                ),
                if (widget.cart.isNotEmpty)
                  ...widget.cart.map(
                    (line) => Row(
                      children: [
                        Expanded(
                          child: Text('${line.quantity}x ${line.product.name}'),
                        ),
                        Text(
                          'R\$ ${(line.product.price * line.quantity).toStringAsFixed(2)}',
                        ),
                        IconButton(
                          onPressed: () => widget.onRemove(line.product),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                      ],
                    ),
                  ),
                if (widget.cart.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _customer.text.trim().isEmpty
                          ? null
                          : () => widget.onFinish(
                              _customer.text.trim(),
                              _payment,
                            ),
                      icon: const Icon(Icons.check),
                      label: const Text('Finalizar venda'),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _ProductList(
            title: 'Adicionar itens à venda',
            products: widget.products,
            search: widget.search,
            onSearch: widget.onSearch,
            onAdd: widget.onAdd,
          ),
        ),
      ],
    );
  }
}

class _SalesHistory extends StatelessWidget {
  const _SalesHistory({required this.repository});
  final InventoryRepository repository;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: repository.getSalesHistory(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(
            child: Text('Nao foi possivel carregar o historico.'),
          );
        }
        final sales = snapshot.data ?? const <Map<String, dynamic>>[];
        if (sales.isEmpty) {
          return const Center(child: Text('Nenhuma venda registrada.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sales.length,
          itemBuilder: (context, index) {
            final sale = sales[index];
            final value = double.tryParse('${sale['valor_total']}') ?? 0;
            return Card(
              child: ListTile(
                leading: const Icon(Icons.receipt_long),
                title: Text('Pedido #${sale['id_pedido']}'),
                subtitle: Text(
                  '${sale['cliente_nome'] ?? 'Cliente não informado'} • '
                  '${sale['forma_pagamento']} • ${sale['itens']} item(ns)',
                ),
                trailing: Text('R\$ ${value.toStringAsFixed(2)}'),
              ),
            );
          },
        );
      },
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Não foi possível carregar os dados.'),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: onRetry,
          child: const Text('Tentar novamente'),
        ),
      ],
    ),
  );
}

class _ExitData {
  const _ExitData(this.quantity, this.reason);
  final int quantity;
  final String reason;
}

class CartLine {
  const CartLine({required this.product, required this.quantity});
  final Product product;
  final int quantity;
}

import 'dart:convert';
import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/product.dart';
import '../services/inventory_api.dart';

class InventoryRepository {
  InventoryRepository(this._api);

  static const _productsKey = 'cached_products';
  static const _pendingKey = 'pending_stock_exits';
  final InventoryApi _api;

  Future<InventorySnapshot> load({String search = ''}) async {
    try {
      final products = await _api.getStock(search: search);
      await _saveProducts(products);
      unawaited(_syncPending().catchError((_) {}));
      return InventorySnapshot(products: products, isOffline: false);
    } catch (error) {
      final products = await _readProducts();
      final term = search.trim().toLowerCase();
      final filtered = term.isEmpty
          ? products
          : products
                .where(
                  (product) =>
                      product.name.toLowerCase().contains(term) ||
                      (product.barcode ?? '').contains(term),
                )
                .toList();
      final message = switch (error) {
        ApiException(:final message) => message,
        TimeoutException() => 'O servidor demorou para responder. Tente novamente em alguns segundos.',
        _ => 'Nao foi possivel conectar a API. Verifique a rede e se o servidor esta ligado.',
      };
      return InventorySnapshot(
        products: filtered,
        isOffline: true,
        errorMessage: message,
      );
    }
  }

  Future<InventorySnapshot> syncNow({String search = ''}) async {
    try {
      await _syncPending();
    } catch (_) {
      // The queue remains persisted and will be retried on the next refresh.
    }
    return load(search: search);
  }

  Future<void> backup() => _api.backup();

  Future<List<Map<String, dynamic>>> getSalesHistory() =>
      _api.getSalesHistory();

  Future<ExitResult> createSale({
    required String payment,
    required List<Map<String, int>> items,
  }) async {
    try {
      await _api.createSale(payment: payment, items: items);
      return const ExitResult(true, 'Venda finalizada com sucesso.');
    } catch (error) {
      if (!_isRetryable(error)) {
        return ExitResult(false, _errorMessage(error));
      }
      final preferences = await SharedPreferences.getInstance();
      final pending = preferences.getStringList(_pendingKey) ?? [];
      pending.add(
        jsonEncode({
          'tipo': 'venda',
          'clientUuid': _clientUuid(),
          'formaPagamento': payment,
          'itens': items,
        }),
      );
      await preferences.setStringList(_pendingKey, pending);
      for (final item in items) {
        await _changeCachedQuantity(item['produtoId']!, -item['quantidade']!);
      }
      return const ExitResult(
        true,
        'Venda salva offline e sera sincronizada depois.',
      );
    }
  }

  Future<ExitResult> registerExit({
    required Product product,
    required int quantity,
    required String reason,
  }) async {
    if (quantity < 1) {
      return const ExitResult(false, 'Informe uma quantidade valida.');
    }
    if (quantity > product.quantity) {
      return const ExitResult(false, 'Estoque insuficiente.');
    }
    try {
      await _api.registerExit(
        productId: product.id,
        quantity: quantity,
        reason: reason,
      );
      await _changeCachedQuantity(product.id, -quantity);
      return const ExitResult(true, 'Saida registrada com sucesso.');
    } catch (error) {
      if (!_isRetryable(error)) {
        return ExitResult(false, _errorMessage(error));
      }
      // Sem internet, a operacao fica guardada para envio posterior.
      final preferences = await SharedPreferences.getInstance();
      final pending = preferences.getStringList(_pendingKey) ?? [];
      pending.add(
        jsonEncode({
          'tipo': 'saida',
          'clientUuid': _clientUuid(),
          'produtoId': product.id,
          'quantidade': quantity,
          'motivo': reason,
        }),
      );
      await preferences.setStringList(_pendingKey, pending);
      await _changeCachedQuantity(product.id, -quantity);
      return const ExitResult(
        true,
        'Saida salva offline e sera sincronizada quando houver internet.',
      );
    }
  }

  Future<ExitResult> registerEntry({
    required Product product,
    required int quantity,
    required String reason,
  }) async {
    if (quantity < 1) {
      return const ExitResult(false, 'Informe uma quantidade valida.');
    }
    try {
      await _api.registerEntry(
        productId: product.id,
        quantity: quantity,
        reason: reason,
      );
      await _changeCachedQuantity(product.id, quantity);
      return const ExitResult(true, 'Entrada registrada com sucesso.');
    } catch (error) {
      if (!_isRetryable(error)) {
        return ExitResult(false, _errorMessage(error));
      }
      final preferences = await SharedPreferences.getInstance();
      final pending = preferences.getStringList(_pendingKey) ?? [];
      pending.add(
        jsonEncode({
          'tipo': 'entrada',
          'clientUuid': _clientUuid(),
          'produtoId': product.id,
          'quantidade': quantity,
          'motivo': reason,
        }),
      );
      await preferences.setStringList(_pendingKey, pending);
      await _changeCachedQuantity(product.id, quantity);
      return const ExitResult(
        true,
        'Entrada salva offline e sera sincronizada depois.',
      );
    }
  }

  Future<ExitResult> createProduct({
    required String name,
    required String description,
    required String barcode,
    required String type,
    required double price,
    required int quantity,
  }) async {
    try {
      await _api.createProduct(
        name: name,
        description: description,
        barcode: barcode,
        type: type,
        price: price,
        quantity: quantity,
      );
      return const ExitResult(true, 'Produto cadastrado com sucesso.');
    } catch (_) {
      return const ExitResult(
        false,
        'Cadastros de produtos exigem conexão com o servidor.',
      );
    }
  }

  Future<void> _syncPending() async {
    final preferences = await SharedPreferences.getInstance();
    final pending = preferences.getStringList(_pendingKey) ?? [];
    if (pending.isEmpty) return;
    final operations = pending.map((item) {
      final operation = jsonDecode(item) as Map<String, dynamic>;
      operation['clientUuid'] ??= _clientUuid();
      operation['tipo'] ??= 'saida';
      operation['payload'] ??= Map<String, dynamic>.from(operation)
        ..remove('tipo')
        ..remove('clientUuid')
        ..remove('payload');
      return operation;
    }).toList();
    final accepted = await _api.pushSync(operations);
    final remaining = operations
        .where((item) => !accepted.contains(item['clientUuid']))
        .map(jsonEncode)
        .toList();
    await preferences.setStringList(_pendingKey, remaining);
  }

  String _clientUuid() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_api.hashCode}';

  bool _isRetryable(Object error) {
    if (error is! ApiException) return true;
    final status = error.statusCode;
    return status == null || status == 408 || status == 429 || status >= 500;
  }

  String _errorMessage(Object error) => error is ApiException
      ? error.message
      : 'Nao foi possivel concluir a operacao.';

  Future<void> _saveProducts(List<Product> products) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _productsKey,
      jsonEncode(products.map(_toJson).toList()),
    );
  }

  Future<List<Product>> _readProducts() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_productsKey);
    if (raw == null) {
      return [];
    }
    return (jsonDecode(raw) as List<dynamic>)
        .map((item) => Product.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> _changeCachedQuantity(int productId, int change) async {
    final products = await _readProducts();
    final index = products.indexWhere((item) => item.id == productId);
    if (index < 0) return;
    final product = products[index];
    products[index] = product.withQuantity(
      (product.quantity + change).clamp(0, 2147483647).toInt(),
    );
    await _saveProducts(products);
  }

  Map<String, dynamic> _toJson(Product product) => {
    'id_produto': product.id,
    'nome_produto': product.name,
    'preco': product.price,
    'tipo': product.type,
    'quantidade_estoque': product.quantity,
    'codigo_barras': product.barcode,
    'descricao': product.description,
  };
}

class InventorySnapshot {
  const InventorySnapshot({
    required this.products,
    required this.isOffline,
    this.errorMessage,
  });
  final List<Product> products;
  final bool isOffline;
  final String? errorMessage;
}

class ExitResult {
  const ExitResult(this.success, this.message);
  final bool success;
  final String message;
}

import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
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
      unawaited(_syncPending());
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
    await _syncPending();
    return load(search: search);
  }

  Future<void> backup() => _api.backup();

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
      if (error is ApiException &&
          (error.statusCode == 401 || error.statusCode == 403)) {
        return ExitResult(false, error.message);
      }
      // Sem internet, a operacao fica guardada para envio posterior.
      final preferences = await SharedPreferences.getInstance();
      final pending = preferences.getStringList(_pendingKey) ?? [];
      pending.add(
        jsonEncode({
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
      if (error is ApiException &&
          (error.statusCode == 401 || error.statusCode == 403)) {
        return ExitResult(false, error.message);
      }
      final preferences = await SharedPreferences.getInstance();
      final pending = preferences.getStringList(_pendingKey) ?? [];
      pending.add(
        jsonEncode({
          'tipo': 'entrada',
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
    } catch (error) {
      debugPrint('[CreateProduct] Falha ao cadastrar produto "$name": $error');
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

    final remaining = <String>[];
    const maxConcurrent = 5;

    // Processa em blocos de maxConcurrent para evitar sobrecarga de conexoes.
    for (var i = 0; i < pending.length; i += maxConcurrent) {
      final batch = pending.sublist(
        i,
        i + maxConcurrent > pending.length ? pending.length : i + maxConcurrent,
      );
      final futures = batch.map((item) async {
        final data = jsonDecode(item) as Map<String, dynamic>;
        try {
          if (data['tipo'] == 'entrada') {
            await _api.registerEntry(
              productId: data['produtoId'],
              quantity: data['quantidade'],
              reason: data['motivo'],
            );
          } else {
            await _api.registerExit(
              productId: data['produtoId'],
              quantity: data['quantidade'],
              reason: data['motivo'],
            );
          }
        } catch (error) {
          debugPrint(
            '[SyncPending] Falha ao sincronizar '
            '${data['tipo'] ?? '?'} '
            'produtoId=${data['produtoId'] ?? '?'}: '
            '$error',
          );
          remaining.add(item);
        }
      });
      await Future.wait(futures);
    }

    await preferences.setStringList(_pendingKey, remaining);
  }

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

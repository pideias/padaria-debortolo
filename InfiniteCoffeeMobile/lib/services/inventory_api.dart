import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/product.dart';

class InventoryApi {
  InventoryApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const _configuredWriteBaseUrl = String.fromEnvironment(
    'API_WRITE_BASE_URL',
  );
  static const _apiToken = String.fromEnvironment('API_ACCESS_TOKEN');
  static const _writeToken = String.fromEnvironment('API_WRITE_TOKEN');
  static const _localNetworkBaseUrl = String.fromEnvironment(
    'API_LOCAL_URL',
    defaultValue: 'http://192.168.1.101:5049',
  );
  static const _localDesktopBaseUrl = 'http://127.0.0.1:5049';

  Map<String, String> _headers([
    Map<String, String>? extra,
    bool write = false,
  ]) {
    final token = write && _writeToken.trim().isNotEmpty
        ? _writeToken
        : _apiToken;
    return {if (token.trim().isNotEmpty) 'X-Api-Key': token, ...?extra};
  }

  // API_BASE_URL permite apontar para o backend local durante o desenvolvimento.
  String get baseUrl {
    if (_configuredBaseUrl.trim().isNotEmpty) {
      return _configuredBaseUrl.replaceFirst(RegExp(r'/$'), '');
    }
    // Use IPv4 on desktop to avoid localhost resolving to ::1 while the API
    // is listening only on 0.0.0.0.
    if (kIsWeb) return _localDesktopBaseUrl;
    return defaultTargetPlatform == TargetPlatform.android
        ? _localNetworkBaseUrl
        : _localDesktopBaseUrl;
  }

  // Escritas e backup precisam chegar ao servidor que acessa o SQL Server.
  String get writeBaseUrl {
    if (_configuredWriteBaseUrl.trim().isNotEmpty) {
      return _configuredWriteBaseUrl.replaceFirst(RegExp(r'/$'), '');
    }
    return defaultTargetPlatform == TargetPlatform.windows
        ? _localDesktopBaseUrl
        : baseUrl;
  }

  Future<List<Product>> getStock({String search = ''}) async {
    final uri = Uri.parse('$baseUrl/api/estoque').replace(
      queryParameters: search.trim().isEmpty ? null : {'busca': search.trim()},
    );
    final response = await _client
        .get(uri, headers: _headers())
        .timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) {
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw ApiException(
          'A API recusou o acesso. Gere o APK com o token de leitura correto.',
          response.statusCode,
        );
      }
      throw ApiException(
        'A API retornou o erro ${response.statusCode}.',
        response.statusCode,
      );
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => Product.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> registerExit({
    required int productId,
    required int quantity,
    required String reason,
  }) async {
    final response = await _client
        .post(
          Uri.parse('$writeBaseUrl/api/estoque/saida'),
          headers: _headers({'Content-Type': 'application/json'}, true),
          body: jsonEncode({
            'produtoId': productId,
            'quantidade': quantity,
            'motivo': reason,
          }),
        )
        .timeout(const Duration(seconds: 60));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(
        '${body['mensagem'] ?? 'Nao foi possivel registrar a saida.'}',
        response.statusCode,
      );
    }
  }

  Future<void> registerEntry({
    required int productId,
    required int quantity,
    required String reason,
  }) async {
    final response = await _client
        .post(
          Uri.parse('$writeBaseUrl/api/estoque/entrada'),
          headers: _headers({'Content-Type': 'application/json'}, true),
          body: jsonEncode({
            'produtoId': productId,
            'quantidade': quantity,
            'motivo': reason,
          }),
        )
        .timeout(const Duration(seconds: 60));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Nao foi possivel registrar a entrada.',
        response.statusCode,
      );
    }
  }

  Future<Set<String>> pushSync(List<Map<String, dynamic>> operations) async {
    final response = await _client
        .post(
          Uri.parse('$writeBaseUrl/api/sync/push'),
          headers: _headers({'Content-Type': 'application/json'}, true),
          body: jsonEncode({'operacoes': operations}),
        )
        .timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) {
      throw ApiException(
        'Nao foi possivel sincronizar as operacoes.',
        response.statusCode,
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['aceitos'] as List<dynamic>? ?? const [])
        .cast<String>()
        .toSet();
  }

  Future<void> createSale({
    required String payment,
    required List<Map<String, int>> items,
  }) async {
    final response = await _client
        .post(
          Uri.parse('$writeBaseUrl/api/vendas'),
          headers: _headers({'Content-Type': 'application/json'}, true),
          body: jsonEncode({'formaPagamento': payment, 'itens': items}),
        )
        .timeout(const Duration(seconds: 60));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(
        '${body['mensagem'] ?? 'Nao foi possivel finalizar a venda.'}',
        response.statusCode,
      );
    }
  }

  Future<List<Map<String, dynamic>>> getSalesHistory() async {
    final response = await _client
        .get(
          Uri.parse('$baseUrl/api/relatorios/vendas/historico'),
          headers: _headers(),
        )
        .timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) {
      throw ApiException(
        'Nao foi possivel carregar o historico de vendas.',
        response.statusCode,
      );
    }
    return (jsonDecode(response.body) as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  Future<void> createProduct({
    required String name,
    required String description,
    required String barcode,
    required String type,
    required double price,
    required int quantity,
  }) async {
    final response = await _client
        .post(
          Uri.parse('$writeBaseUrl/api/produtos'),
          headers: _headers({'Content-Type': 'application/json'}, true),
          body: jsonEncode({
            'nome': name,
            'descricao': description,
            'codigoBarras': barcode,
            'tipo': type,
            'preco': price,
            'quantidade': quantity,
          }),
        )
        .timeout(const Duration(seconds: 60));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const ApiException('Nao foi possivel cadastrar o produto.');
    }
  }

  Future<void> backup() async {
    final response = await _client
        .post(
          Uri.parse('$writeBaseUrl/api/estoque/backup'),
          headers: _headers(null, true),
        )
        .timeout(const Duration(seconds: 60));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(
        '${body['mensagem'] ?? 'Nao foi possivel enviar o backup.'}',
        response.statusCode,
      );
    }
  }
}

class ApiException implements Exception {
  const ApiException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;
}

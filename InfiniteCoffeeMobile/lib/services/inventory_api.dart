import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;

import '../models/addam_reply.dart';
import '../models/product.dart';
import '../models/sales_by_product.dart';

class InventoryApi {
  InventoryApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://padaria-debortolo-api-8w5w.onrender.com',
  );
  static const _configuredWriteBaseUrl = String.fromEnvironment(
    'API_WRITE_BASE_URL',
  );
  static const _apiToken = String.fromEnvironment('API_ACCESS_TOKEN');
  static const _writeToken = String.fromEnvironment('API_WRITE_TOKEN');
  Map<String, String> _headers([
    Map<String, String>? extra,
    bool write = false,
  ]) {
    final token = write && _writeToken.trim().isNotEmpty
        ? _writeToken
        : _apiToken;
    return {if (token.trim().isNotEmpty) 'X-Api-Key': token, ...?extra};
  }

  // API_BASE_URL pode apontar para um backend local somente em desenvolvimento.
  String get baseUrl {
    return _configuredBaseUrl.replaceFirst(RegExp(r'/$'), '');
  }

  // Escritas precisam chegar ao servidor que acessa o SQL Server.
  String get writeBaseUrl {
    if (_configuredWriteBaseUrl.trim().isNotEmpty) {
      return _configuredWriteBaseUrl.replaceFirst(RegExp(r'/$'), '');
    }
    return baseUrl;
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
    required String customer,
    required String payment,
    required List<Map<String, int>> items,
  }) async {
    final response = await _client
        .post(
          Uri.parse('$writeBaseUrl/api/vendas'),
          headers: _headers({'Content-Type': 'application/json'}, true),
          body: jsonEncode({
            'clienteNome': customer,
            'formaPagamento': payment,
            'itens': items,
          }),
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

  Future<List<SalesByProduct>> getSalesByProduct() async {
    final response = await _client
        .get(
          Uri.parse('$baseUrl/api/relatorios/vendas/produtos'),
          headers: _headers(),
        )
        .timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) {
      throw ApiException(
        'Nao foi possivel carregar o relatorio de vendas por produto.',
        response.statusCode,
      );
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => SalesByProduct.fromJson(item as Map<String, dynamic>))
        .where((item) => item.quantitySold > 0)
        .toList();
  }

  Future<AddamReply> chatWithAddam(
    String message, {
    List<Map<String, String>> history = const [],
    List<Map<String, dynamic>> catalog = const [],
  }) async {
    final response = await _client
        .post(
          Uri.parse('$writeBaseUrl/api/addam/chat'),
          headers: _headers({'Content-Type': 'application/json'}, true),
          body: jsonEncode({
            'mensagem': message,
            'historico': history,
            'catalogo': catalog,
          }),
        )
        .timeout(const Duration(seconds: 75));
    if (response.statusCode != 200) {
      throw _managementError(response, 'O Addam não conseguiu responder.');
    }
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return AddamReply.fromJson(data);
    } on FormatException {
      throw ApiException('A resposta do Addam veio em um formato inválido.');
    } on TypeError {
      throw ApiException('A resposta do Addam veio em um formato inválido.');
    }
  }

  Future<String> executeAddamAction(AddamActionDraft action) async {
    final fields = action.fields;
    String text(String key) => fields[key]?.toString().trim() ?? '';
    int integer(String key) => int.tryParse('${fields[key]}') ?? 0;
    double decimal(String key) => double.tryParse('${fields[key]}') ?? 0;

    switch (action.type) {
      case 'create_customer':
        await saveCadastro(
          'clientes',
          dados: {'nome': text('nome'), 'email': text('email')},
        );
        return 'Cliente cadastrado pela API.';
      case 'update_customer':
        await saveCadastro(
          'clientes',
          id: integer('id_cliente'),
          dados: {'nome': text('nome'), 'email': text('email')},
        );
        return 'Cliente atualizado pela API.';
      case 'create_product':
        await createProduct(
          name: text('nome'),
          description: text('descricao'),
          barcode: text('codigoBarras'),
          type: text('tipo'),
          price: decimal('preco'),
          quantity: integer('quantidade'),
          stockReason: text('motivoEstoqueInicial').isEmpty
              ? 'Estoque inicial via Addam'
              : text('motivoEstoqueInicial'),
        );
        return 'Produto cadastrado e estoque inicial enviado à API.';
      case 'stock_entry':
        await registerEntry(
          productId: integer('produtoId'),
          quantity: integer('quantidade'),
          reason: text('motivo'),
        );
        return 'Entrada de estoque registrada pela API.';
      case 'stock_exit':
        await registerExit(
          productId: integer('produtoId'),
          quantity: integer('quantidade'),
          reason: text('motivo'),
        );
        return 'Saída de estoque registrada pela API.';
      case 'update_product':
        await updateProduct(
          productId: integer('id_produto'),
          name: text('nome'),
          description: text('descricao'),
          barcode: text('codigoBarras'),
          type: text('tipo'),
          price: decimal('preco'),
        );
        return 'Produto atualizado pela API.';
      case 'create_employee':
        await saveCadastro(
          'funcionarios',
          dados: {'nome': text('nome'), 'cargo': text('cargo')},
        );
        return 'Funcionário cadastrado pela API.';
      case 'update_employee':
        await saveCadastro(
          'funcionarios',
          id: integer('id_funcionario'),
          dados: {'nome': text('nome'), 'cargo': text('cargo')},
        );
        return 'Funcionário atualizado pela API.';
      case 'create_table':
        await saveCadastro(
          'mesas',
          dados: {
            'numero': integer('numero'),
            'capacidade': integer('capacidade'),
          },
        );
        return 'Mesa cadastrada pela API.';
      case 'update_table':
        await saveCadastro(
          'mesas',
          id: integer('id_mesa'),
          dados: {
            'numero': integer('numero'),
            'capacidade': integer('capacidade'),
          },
        );
        return 'Mesa atualizada pela API.';
      case 'create_sale':
        final rawItems = fields['itens'];
        if (rawItems is! List || rawItems.isEmpty) {
          throw const ApiException(
            'A proposta da venda não tem itens válidos.',
          );
        }
        final items = rawItems
            .whereType<Map>()
            .map(
              (item) => {
                'produtoId': int.tryParse('${item['produtoId']}') ?? 0,
                'quantidade': int.tryParse('${item['quantidade']}') ?? 0,
              },
            )
            .toList();
        await createSale(
          customer: text('clienteNome'),
          payment: text('formaPagamento'),
          items: items,
        );
        return 'Venda enviada para validação e gravação pela API.';
      default:
        throw const ApiException(
          'Essa ação do Addam ainda não está disponível.',
        );
    }
  }

  Future<void> updateProduct({
    required int productId,
    required String name,
    required String description,
    required String barcode,
    required String type,
    required double price,
  }) async {
    final response = await _client
        .put(
          Uri.parse('$writeBaseUrl/api/produtos/$productId'),
          headers: _headers({'Content-Type': 'application/json'}, true),
          body: jsonEncode({
            'nome': name,
            'descricao': description,
            'codigoBarras': barcode,
            'tipo': type,
            'preco': price,
          }),
        )
        .timeout(const Duration(seconds: 60));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        throw ApiException(
          '${body['mensagem'] ?? 'Nao foi possivel atualizar o produto.'}',
          response.statusCode,
        );
      } on FormatException {
        throw ApiException(
          'A API retornou o erro ${response.statusCode}.',
          response.statusCode,
        );
      }
    }
  }

  Future<void> deleteProduct(int productId) async {
    final response = await _client
        .delete(
          Uri.parse('$writeBaseUrl/api/produtos/$productId'),
          headers: _headers(null, true),
        )
        .timeout(const Duration(seconds: 60));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        throw ApiException(
          '${body['mensagem'] ?? 'Nao foi possivel excluir o produto.'}',
          response.statusCode,
        );
      } on FormatException {
        throw ApiException(
          'A API retornou o erro ${response.statusCode}.',
          response.statusCode,
        );
      }
    }
  }

  Future<void> createProduct({
    required String name,
    required String description,
    required String barcode,
    required String type,
    required double price,
    required int quantity,
    String stockReason = 'Estoque inicial do produto',
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
            'motivoEstoqueInicial': stockReason,
          }),
        )
        .timeout(const Duration(seconds: 60));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        throw ApiException(
          '${body['mensagem'] ?? 'Nao foi possivel cadastrar o produto.'}',
          response.statusCode,
        );
      } on FormatException {
        throw ApiException(
          'A API retornou o erro ${response.statusCode}.',
          response.statusCode,
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> getCadastros(
    String tipo, {
    required bool incluirInativos,
  }) async {
    final uri = Uri.parse('$baseUrl/api/cadastros/$tipo').replace(
      queryParameters: incluirInativos ? {'incluirInativos': 'true'} : null,
    );
    final response = await _client
        .get(uri, headers: _headers())
        .timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) {
      throw _managementError(
        response,
        'Nao foi possivel carregar os cadastros.',
      );
    }
    return (jsonDecode(response.body) as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  Future<void> saveCadastro(
    String tipo, {
    int? id,
    required Map<String, dynamic> dados,
  }) async {
    final uri = Uri.parse(
      '$writeBaseUrl/api/cadastros/$tipo${id == null ? '' : '/$id'}',
    );
    final headers = _headers({'Content-Type': 'application/json'}, true);
    final response = id == null
        ? await _client
              .post(uri, headers: headers, body: jsonEncode(dados))
              .timeout(const Duration(seconds: 60))
        : await _client
              .put(uri, headers: headers, body: jsonEncode(dados))
              .timeout(const Duration(seconds: 60));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _managementError(response, 'Nao foi possivel salvar o cadastro.');
    }
  }

  Future<void> setCadastroAtivo(
    String tipo, {
    required int id,
    required bool ativo,
  }) async {
    final uri = Uri.parse(
      '$writeBaseUrl/api/cadastros/$tipo/$id${ativo ? '/ativo' : ''}',
    );
    final headers = ativo
        ? _headers({'Content-Type': 'application/json'}, true)
        : _headers(null, true);
    final response = ativo
        ? await _client
              .patch(uri, headers: headers, body: jsonEncode({'ativo': true}))
              .timeout(const Duration(seconds: 60))
        : await _client
              .delete(uri, headers: headers)
              .timeout(const Duration(seconds: 60));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _managementError(response, 'Nao foi possivel alterar o cadastro.');
    }
  }

  ApiException _managementError(http.Response response, String fallback) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiException(
        '${body['mensagem'] ?? fallback}',
        response.statusCode,
      );
    } on FormatException {
      return ApiException(
        'A API retornou o erro ${response.statusCode}.',
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

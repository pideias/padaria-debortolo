import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infinite_coffee_app/repositories/inventory_repository.dart';
import 'package:infinite_coffee_app/services/inventory_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cache offline sempre mantém o catálogo completo', () async {
    SharedPreferences.setMockInitialValues({});
    var online = true;
    final client = MockClient((request) async {
      expect(request.url.path, '/api/estoque');
      expect(request.url.queryParameters, isEmpty);
      if (!online) throw const SocketException('offline');
      return http.Response(
        jsonEncode([
          {
            'id_produto': 1,
            'nome_produto': 'Pão Francês',
            'preco': 0.75,
            'tipo': 'Unidade',
            'quantidade_estoque': 50,
            'codigo_barras': '1001',
          },
          {
            'id_produto': 2,
            'nome_produto': 'Bolo de cenoura',
            'preco': 20.0,
            'tipo': 'Unidade',
            'quantidade_estoque': 4,
            'codigo_barras': '2002',
          },
        ]),
        200,
      );
    });
    final repository = InventoryRepository(InventoryApi(client: client));

    final onlineResult = await repository.load();
    expect(onlineResult.products, hasLength(2));

    online = false;
    final offlineResult = await repository.load();

    expect(offlineResult.isOffline, isTrue);
    expect(offlineResult.products, hasLength(2));
    expect(
      offlineResult.products.map((product) => product.name),
      containsAll(['Pão Francês', 'Bolo de cenoura']),
    );
  });
}

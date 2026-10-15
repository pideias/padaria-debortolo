import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infinite_coffee_app/services/inventory_api.dart';

void main() {
  test('consulta o endpoint agregado e converte valores do produto', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/relatorios/vendas/produtos');
      return http.Response(
        jsonEncode([
          {
            'id_produto': 7,
            'nome_produto': 'Bolo de cenoura',
            'quantidade_vendida': 12,
            'faturamento': 180.50,
          },
        ]),
        200,
      );
    });

    final result = await InventoryApi(client: client).getSalesByProduct();

    expect(result, hasLength(1));
    expect(result.single.productId, 7);
    expect(result.single.productName, 'Bolo de cenoura');
    expect(result.single.quantitySold, 12);
    expect(result.single.revenue, 180.50);
  });
}

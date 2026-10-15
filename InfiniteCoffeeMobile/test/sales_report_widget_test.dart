import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infinite_coffee_app/repositories/inventory_repository.dart';
import 'package:infinite_coffee_app/screens/home_screen.dart';
import 'package:infinite_coffee_app/services/inventory_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a aba Relatórios mostra o gráfico por produto', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final requestedPaths = <String>[];
    final client = MockClient((request) async {
      requestedPaths.add(request.url.path);
      if (request.url.path == '/api/estoque') {
        return http.Response('[]', 200);
      }
      if (request.url.path == '/api/relatorios/vendas/produtos') {
        return http.Response(
          jsonEncode([
            {
              'id_produto': 1,
              'nome_produto': 'Café Expresso',
              'quantidade_vendida': 10,
              'faturamento': 60.0,
            },
            {
              'id_produto': 2,
              'nome_produto': 'Pão de Queijo',
              'quantidade_vendida': 5,
              'faturamento': 25.0,
            },
          ]),
          200,
        );
      }
      return http.Response('{}', 404);
    });
    final repository = InventoryRepository(InventoryApi(client: client));

    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Relatórios').last);
    await tester.pumpAndSettle();

    expect(find.text('Relatórios de vendas'), findsOneWidget);
    expect(find.text('Café Expresso'), findsOneWidget);
    expect(find.text('Pão de Queijo'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(requestedPaths, contains('/api/relatorios/vendas/produtos'));
  });
}

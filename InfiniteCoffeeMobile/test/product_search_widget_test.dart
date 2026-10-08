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

  testWidgets('pesquisa filtra sem recarregar a lista a cada tecla', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    var stockRequests = 0;
    final client = MockClient((request) async {
      stockRequests++;
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

    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(stockRequests, 1);

    await tester.tap(find.text('Estoque').last);
    await tester.pumpAndSettle();

    final searchField = find.byType(TextField).first;
    await tester.enterText(searchField, 'pao');
    await tester.pumpAndSettle();

    expect(find.text('Pão Francês'), findsOneWidget);
    expect(find.text('Bolo de cenoura'), findsNothing);
    expect(tester.widget<TextField>(searchField).controller!.text, 'pao');
    expect(stockRequests, 1);

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();
    await tester.enterText(searchField, '2002');
    await tester.pumpAndSettle();

    expect(find.text('Bolo de cenoura'), findsOneWidget);
    expect(find.text('Pão Francês'), findsNothing);
    expect(stockRequests, 1);
  });
}

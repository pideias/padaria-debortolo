import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infinite_coffee_app/screens/addam_chat_screen.dart';
import 'package:infinite_coffee_app/services/inventory_api.dart';

void main() {
  testWidgets('mostra boas-vindas e conversa com o serviço Addam', (
    tester,
  ) async {
    final api = InventoryApi(
      client: MockClient((request) async {
        return http.Response(
          '{"assistant":"Addam","reply":"Abra Estoque no aplicativo.","suggestions":["Como vejo vendas?"]}',
          200,
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AddamChatScreen(api: api)),
      ),
    );

    expect(
      find.text(
        'Olá! Sou o Addam, assistente de teste da Padaria Debortolo. '
        'Nesta versão posso orientar você pelo aplicativo. Ainda não consulto '
        'nem altero dados, não crio pedidos e não gero PDFs.',
      ),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), 'Como consulto o estoque?');
    await tester.tap(find.byTooltip('Enviar mensagem'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Como consulto o estoque?'), findsOneWidget);
    expect(find.text('Abra Estoque no aplicativo.'), findsOneWidget);
    expect(find.text('Como vejo vendas?'), findsOneWidget);
  });
}

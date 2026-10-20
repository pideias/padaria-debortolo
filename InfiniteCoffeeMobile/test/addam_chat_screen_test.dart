import 'dart:convert';

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
        'Olá! Sou o Addam, assistente da Padaria Debortolo. Posso conversar sobre '
        'estoque e preparar cadastros, vendas e movimentações. Antes de gravar, '
        'vou mostrar uma proposta para você revisar e confirmar.',
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

  testWidgets('pede confirmação antes de enviar um produto à API', (
    tester,
  ) async {
    Map<String, dynamic>? productBody;
    final api = InventoryApi(
      client: MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/api/estoque') {
          return http.Response(
            '[{"id_produto":12,"nome_produto":"Pão","tipo":"comida","preco":3.5,"quantidade_estoque":0}]',
            200,
          );
        }
        if (request.url.path == '/api/addam/chat') {
          return http.Response(
            jsonEncode({
              'assistant': 'Addam',
              'reply': 'Preparei o cadastro do pão. Revise os campos.',
              'suggestions': [],
              'action': {
                'type': 'create_product',
                'fields': {
                  'nome': 'Pão',
                  'tipo': 'comida',
                  'preco': 3.5,
                  'quantidade': 12,
                  'descricao': '',
                  'codigoBarras': '',
                },
              },
            }),
            200,
          );
        }
        if (request.method == 'POST' && request.url.path == '/api/produtos') {
          productBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response('{"mensagem":"ok"}', 201);
        }
        return http.Response('{}', 404);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AddamChatScreen(api: api)),
      ),
    );
    await tester.enterText(
      find.byType(TextField),
      'Cadastre pão por 3,50 com 12 unidades',
    );
    await tester.tap(find.byTooltip('Enviar mensagem'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Proposta para revisão'), findsOneWidget);
    expect(productBody, isNull);
    await tester.tap(find.text('Confirmar').last);
    await tester.pumpAndSettle();
    expect(find.text('Cadastrar produto'), findsOneWidget);
    await tester.tap(find.text('Confirmar e gravar'));
    await tester.pump();
    await tester.pumpAndSettle();

    final savedProduct = productBody!;
    expect(savedProduct['nome'], 'Pão');
    expect(savedProduct['preco'], 3.5);
    expect(savedProduct['quantidade'], 12);
    expect(savedProduct['motivoEstoqueInicial'], 'Estoque inicial via Addam');
    expect(
      find.text('Produto cadastrado e estoque inicial enviado à API.'),
      findsOneWidget,
    );
  });
}

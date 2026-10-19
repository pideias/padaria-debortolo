import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infinite_coffee_app/services/inventory_api.dart';

void main() {
  test('envia a pergunta ao endpoint Addam e interpreta sugestões', () async {
    late http.Request captured;
    final api = InventoryApi(
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'assistant': 'Addam',
            'reply': 'Abra Estoque no aplicativo.',
            'suggestions': ['Como vejo vendas?'],
          }),
          200,
        );
      }),
    );

    final reply = await api.chatWithAddam('Como consulto o estoque?');

    expect(captured.method, 'POST');
    expect(captured.url.path, '/api/addam/chat');
    expect(jsonDecode(captured.body)['mensagem'], 'Como consulto o estoque?');
    expect(reply.assistant, 'Addam');
    expect(reply.text, 'Abra Estoque no aplicativo.');
    expect(reply.suggestions, ['Como vejo vendas?']);
  });

  test(
    'mostra mensagem do backend quando o serviço não está disponível',
    () async {
      final api = InventoryApi(
        client: MockClient(
          (_) async =>
              http.Response('{"mensagem":"Serviço Addam indisponível."}', 503),
        ),
      );

      await expectLater(
        api.chatWithAddam('Oi'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            'Serviço Addam indisponível.',
          ),
        ),
      );
    },
  );
}

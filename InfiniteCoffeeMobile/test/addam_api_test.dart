import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infinite_coffee_app/models/addam_reply.dart';
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
            'action': {
              'type': 'create_product',
              'fields': {
                'nome': 'Pão',
                'tipo': 'comida',
                'preco': 3.5,
                'quantidade': 12,
              },
            },
          }),
          200,
        );
      }),
    );

    final reply = await api.chatWithAddam(
      'Como consulto o estoque?',
      history: [
        {'role': 'user', 'content': 'Oi'},
      ],
      catalog: [
        {
          'id': 7,
          'nome': 'Pão',
          'tipo': 'comida',
          'quantidade': 8,
          'preco': 3.5,
        },
      ],
    );

    expect(captured.method, 'POST');
    expect(captured.url.path, '/api/addam/chat');
    expect(jsonDecode(captured.body)['mensagem'], 'Como consulto o estoque?');
    expect(jsonDecode(captured.body)['historico'], hasLength(1));
    expect(jsonDecode(captured.body)['catalogo'], hasLength(1));
    expect(reply.assistant, 'Addam');
    expect(reply.text, 'Abra Estoque no aplicativo.');
    expect(reply.suggestions, ['Como vejo vendas?']);
    expect(reply.action?.type, 'create_product');
    expect(reply.action?.fields['quantidade'], 12);
  });

  test('desembrulha JSON acidental e elimina sugestões repetidas', () {
    final reply = AddamReply.fromJson({
      'assistant': 'Addam',
      'reply': jsonEncode({
        'reply': 'Nintendo destaca os exclusivos; Steam Deck a flexibilidade.',
        'suggestions': [
          'Qual tipo de jogo você prefere?',
          'Qual tipo de jogo você prefere?',
          'Steam Deck ou Nintendo',
          'Nintendo ou Steam Deck',
          'alterar_quantidade',
        ],
      }),
      'suggestions': [],
    });

    expect(
      reply.text,
      'Nintendo destaca os exclusivos; Steam Deck a flexibilidade.',
    );
    expect(reply.suggestions, [
      'Qual tipo de jogo você prefere?',
      'Steam Deck ou Nintendo',
    ]);
  });

  test('não exibe JSON incompleto como texto da conversa', () {
    final reply = AddamReply.fromJson({
      'assistant': 'Addam',
      'reply': '{"reply":"texto quebrado",',
      'suggestions': [],
    });

    expect(reply.text, contains('não consegui organizar uma resposta'));
    expect(reply.text, isNot(contains('{')));
  });

  test(
    'encaminha a proposta confirmada ao endpoint normal de produtos',
    () async {
      late http.Request captured;
      final api = InventoryApi(
        client: MockClient((request) async {
          captured = request;
          return http.Response('{"mensagem":"ok"}', 201);
        }),
      );

      await api.executeAddamAction(
        const AddamActionDraft(
          type: 'create_product',
          fields: {
            'nome': 'Pão',
            'tipo': 'comida',
            'preco': 3.5,
            'quantidade': 12,
          },
        ),
      );

      expect(captured.method, 'POST');
      expect(captured.url.path, '/api/produtos');
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['nome'], 'Pão');
      expect(body['preco'], 3.5);
      expect(body['quantidade'], 12);
      expect(body['motivoEstoqueInicial'], 'Estoque inicial via Addam');
    },
  );

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

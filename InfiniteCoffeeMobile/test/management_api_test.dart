import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infinite_coffee_app/services/inventory_api.dart';

void main() {
  test('usa os contratos REST de leitura, CRUD e inativação', () async {
    final requests = <http.Request>[];
    final api = InventoryApi(
      client: MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET') {
          return http.Response(
            '[{"id_cliente":7,"nome_cliente":"Ana","email":"ana@example.com","ativo":true}]',
            200,
          );
        }
        return http.Response('{"mensagem":"ok"}', 200);
      }),
    );

    final clientes = await api.getCadastros('clientes', incluirInativos: true);
    await api.saveCadastro(
      'clientes',
      dados: {'nome': 'Ana', 'email': 'ana@example.com'},
    );
    await api.saveCadastro(
      'funcionarios',
      id: 4,
      dados: {'nome': 'João', 'cargo': 'Caixa'},
    );
    await api.setCadastroAtivo('mesas', id: 2, ativo: false);
    await api.setCadastroAtivo('mesas', id: 2, ativo: true);

    expect(clientes.single['id_cliente'], 7);
    expect(requests[0].url.path, '/api/cadastros/clientes');
    expect(requests[0].url.queryParameters['incluirInativos'], 'true');
    expect(requests[1].method, 'POST');
    expect(jsonDecode(requests[1].body)['nome'], 'Ana');
    expect(requests[2].method, 'PUT');
    expect(requests[2].url.path, '/api/cadastros/funcionarios/4');
    expect(requests[3].method, 'DELETE');
    expect(requests[3].url.path, '/api/cadastros/mesas/2');
    expect(requests[4].method, 'PATCH');
    expect(requests[4].url.path, '/api/cadastros/mesas/2/ativo');
    expect(jsonDecode(requests[4].body)['ativo'], isTrue);
  });
}

import 'package:flutter/material.dart';

import '../services/inventory_api.dart';

class ManagementScreen extends StatelessWidget {
  const ManagementScreen({super.key, required this.api});

  final InventoryApi api;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const Material(
            color: Colors.white,
            child: TabBar(
              isScrollable: true,
              tabs: [
                Tab(icon: Icon(Icons.people_outline), text: 'Clientes'),
                Tab(icon: Icon(Icons.badge_outlined), text: 'Funcionários'),
                Tab(icon: Icon(Icons.table_restaurant_outlined), text: 'Mesas'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _CadastroList(api: api, tipo: 'clientes'),
                _CadastroList(api: api, tipo: 'funcionarios'),
                _CadastroList(api: api, tipo: 'mesas'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CadastroList extends StatefulWidget {
  const _CadastroList({required this.api, required this.tipo});

  final InventoryApi api;
  final String tipo;

  @override
  State<_CadastroList> createState() => _CadastroListState();
}

class _CadastroListState extends State<_CadastroList> {
  bool _incluirInativos = false;
  late Future<List<Map<String, dynamic>>> _cadastros;

  String get _titulo => switch (widget.tipo) {
    'clientes' => 'cliente',
    'funcionarios' => 'funcionário',
    _ => 'mesa',
  };

  @override
  void initState() {
    super.initState();
    _cadastros = widget.api.getCadastros(
      widget.tipo,
      incluirInativos: _incluirInativos,
    );
  }

  Future<void> _carregar() async {
    final request = widget.api.getCadastros(
      widget.tipo,
      incluirInativos: _incluirInativos,
    );
    setState(() => _cadastros = request);
    try {
      await request;
    } catch (_) {
      // FutureBuilder apresenta o erro; o refresh apenas encerra o indicador.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Gerencie os $_titulo${widget.tipo == 'mesas' ? '' : 's'}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Flexible(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Mostrar inativos'),
                  value: _incluirInativos,
                  onChanged: (value) async {
                    setState(() => _incluirInativos = value ?? false);
                    await _carregar();
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _cadastros,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _ErroCadastros(onRetry: _carregar);
              }
              final itens = snapshot.data ?? const <Map<String, dynamic>>[];
              if (itens.isEmpty) {
                return RefreshIndicator(
                  onRefresh: _carregar,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 100),
                      Icon(
                        Icons.inbox_outlined,
                        size: 48,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(height: 12),
                      Center(child: Text('Nenhum $_titulo cadastrado.')),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: _carregar,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                  itemCount: itens.length,
                  itemBuilder: (context, index) => _item(itens[index]),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _editar(),
              icon: const Icon(Icons.add),
              label: Text('Cadastrar $_titulo'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _item(Map<String, dynamic> item) {
    final ativo = item['ativo'] == true || item['ativo'] == 1;
    final id = _id(item);
    final title = switch (widget.tipo) {
      'clientes' => '${item['nome_cliente'] ?? ''}',
      'funcionarios' => '${item['nome_funcionario'] ?? ''}',
      _ => 'Mesa ${item['numero'] ?? ''}',
    };
    final subtitle = switch (widget.tipo) {
      'clientes' =>
        'ID: $id • ${_texto(item['email']).isEmpty ? 'Sem e-mail' : item['email']}',
      'funcionarios' => 'ID: $id • ${item['cargo'] ?? ''}',
      _ =>
        'ID: $id • ${item['capacidade'] ?? 0} lugares • ${item['status_mesa'] ?? ''}',
    };

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(switch (widget.tipo) {
            'clientes' => Icons.person_outline,
            'funcionarios' => Icons.badge_outlined,
            _ => Icons.table_restaurant_outlined,
          }),
        ),
        title: Text(title),
        subtitle: Text('$subtitle${ativo ? '' : ' • Inativo'}'),
        trailing: PopupMenuButton<String>(
          tooltip: 'Ações',
          onSelected: (action) {
            if (action == 'editar') _editar(item);
            if (action == 'inativar') _alterarAtivo(item, false);
            if (action == 'reativar') _alterarAtivo(item, true);
          },
          itemBuilder: (context) => [
            if (ativo) ...[
              const PopupMenuItem(value: 'editar', child: Text('Editar')),
              const PopupMenuItem(
                value: 'inativar',
                child: Text('Excluir / inativar'),
              ),
            ] else
              const PopupMenuItem(value: 'reativar', child: Text('Reativar')),
          ],
        ),
      ),
    );
  }

  Future<void> _editar([Map<String, dynamic>? item]) async {
    final dados = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _CadastroFormDialog(tipo: widget.tipo, item: item),
    );
    if (dados == null || !mounted) return;

    try {
      await widget.api.saveCadastro(
        widget.tipo,
        id: item == null ? null : _id(item),
        dados: switch (widget.tipo) {
          'clientes' => {'nome': dados['nome'], 'email': dados['email']},
          'funcionarios' => {'nome': dados['nome'], 'cargo': dados['cargo']},
          _ => {
            'numero': int.parse(dados['numero']!),
            'capacidade': int.parse(dados['capacidade']!),
          },
        },
      );
      if (!mounted) return;
      _mensagem(item == null ? 'Cadastro criado.' : 'Cadastro atualizado.');
      await _carregar();
    } catch (error) {
      if (mounted) _mensagem(_mensagemErro(error));
    }
  }

  Future<void> _alterarAtivo(Map<String, dynamic> item, bool ativo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(ativo ? 'Reativar cadastro?' : 'Inativar cadastro?'),
        content: Text(
          ativo ? 'O cadastro voltará a aparecer nas listas disponíveis.' : 'O registro e o histórico relacionado serão preservados. Ele deixará de aparecer nas listas ativas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(ativo ? 'Reativar' : 'Inativar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    try {
      await widget.api.setCadastroAtivo(
        widget.tipo,
        id: _id(item),
        ativo: ativo,
      );
      if (!mounted) return;
      _mensagem(ativo ? 'Cadastro reativado.' : 'Cadastro inativado.');
      await _carregar();
    } catch (error) {
      if (mounted) _mensagem(_mensagemErro(error));
    }
  }

  int _id(Map<String, dynamic> item) =>
      (item[switch (widget.tipo) {
                'clientes' => 'id_cliente',
                'funcionarios' => 'id_funcionario',
                _ => 'id_mesa',
              }]
              as num)
          .toInt();

  void _mensagem(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _mensagemErro(Object error) => error is ApiException
      ? error.message
      : 'Não foi possível concluir a operação. Verifique a conexão com a API.';

  String _texto(Object? valor) => valor?.toString().trim() ?? '';
}

class _CadastroFormDialog extends StatefulWidget {
  const _CadastroFormDialog({required this.tipo, this.item});

  final String tipo;
  final Map<String, dynamic>? item;

  @override
  State<_CadastroFormDialog> createState() => _CadastroFormDialogState();
}

class _CadastroFormDialogState extends State<_CadastroFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nome;
  late final TextEditingController _segundoCampo;

  bool get _mesa => widget.tipo == 'mesas';
  bool get _cliente => widget.tipo == 'clientes';

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nome = TextEditingController(
      text: item == null
          ? ''
          : '${item[_mesa
                    ? 'numero'
                    : _cliente
                    ? 'nome_cliente'
                    : 'nome_funcionario'] ?? ''}',
    );
    _segundoCampo = TextEditingController(
      text: item == null
          ? ''
          : '${item[_mesa
                    ? 'capacidade'
                    : _cliente
                    ? 'email'
                    : 'cargo'] ?? ''}',
    );
  }

  @override
  void dispose() {
    _nome.dispose();
    _segundoCampo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titulo = widget.item == null ? 'Novo cadastro' : 'Editar cadastro';
    return AlertDialog(
      title: Text(titulo),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nome,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: _mesa ? 'Número da mesa' : 'Nome',
                ),
                keyboardType: _mesa ? TextInputType.number : TextInputType.name,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return _mesa ? 'Informe o número.' : 'Informe o nome.';
                  }
                  if (_mesa && (int.tryParse(value) ?? 0) < 1) {
                    return 'Use um número maior que zero.';
                  }
                  if (!_mesa && value.trim().length > 100) {
                    return 'Use até 100 caracteres.';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _segundoCampo,
                decoration: InputDecoration(
                  labelText: _mesa
                      ? 'Capacidade'
                      : _cliente
                      ? 'E-mail (opcional)'
                      : 'Cargo',
                ),
                keyboardType: _mesa
                    ? TextInputType.number
                    : _cliente
                    ? TextInputType.emailAddress
                    : TextInputType.text,
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (_mesa && (int.tryParse(text) ?? 0) < 1) {
                    return 'Use uma capacidade maior que zero.';
                  }
                  if (!_mesa && !_cliente && text.isEmpty) {
                    return 'Informe o cargo.';
                  }
                  if (_cliente &&
                      text.isNotEmpty &&
                      (!text.contains('@') || !text.contains('.'))) {
                    return 'Informe um e-mail válido.';
                  }
                  if (text.length > 100) return 'Use até 100 caracteres.';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(context, {
              if (_mesa) 'numero': _nome.text.trim(),
              if (!_mesa) 'nome': _nome.text.trim(),
              if (_mesa) 'capacidade': _segundoCampo.text.trim(),
              if (_cliente) 'email': _segundoCampo.text.trim(),
              if (!_mesa && !_cliente) 'cargo': _segundoCampo.text.trim(),
            });
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

class _ErroCadastros extends StatelessWidget {
  const _ErroCadastros({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 42),
            const SizedBox(height: 12),
            const Text(
              'Não foi possível carregar os cadastros. Conecte-se à API e tente novamente.',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'dart:convert';

import '../models/addam_reply.dart';
import '../services/inventory_api.dart';

class AddamChatScreen extends StatefulWidget {
  const AddamChatScreen({super.key, required this.api});

  final InventoryApi api;

  @override
  State<AddamChatScreen> createState() => _AddamChatScreenState();
}

class _AddamChatScreenState extends State<AddamChatScreen> {
  static const _welcome = AddamReply(
    assistant: 'Addam',
    text:
        'Olá! Sou o Addam, assistente da Padaria Debortolo. Posso conversar sobre '
        'estoque e preparar cadastros, vendas e movimentações. Antes de gravar, '
        'vou mostrar uma proposta para você revisar e confirmar.',
    suggestions: [
      'O que você consegue fazer?',
      'Como consulto o estoque?',
      'Onde vejo as vendas?',
      'Você gera PDF?',
    ],
  );

  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_AddamMessage> _messages = [
    _AddamMessage(text: _welcome.text, fromAddam: true),
  ];
  List<Map<String, dynamic>> _catalog = const [];
  DateTime? _catalogLoadedAt;
  List<String> _suggestions = _welcome.suggestions;
  bool _sending = false;
  bool _executingAction = false;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send([String? suggestedMessage]) async {
    if (_sending || _executingAction) return;
    final message = (suggestedMessage ?? _inputController.text).trim();
    if (message.isEmpty) return;

    final priorMessages = _messages.skip(1).toList();
    final recentMessages = priorMessages.length > 6
        ? priorMessages.sublist(priorMessages.length - 6)
        : priorMessages;
    final history = recentMessages
        .map(
          (item) => <String, String>{
            'role': item.fromAddam ? 'assistant' : 'user',
            'content': item.action == null
                ? item.text
                : '${item.text}\nProposta estruturada anterior: '
                      '${jsonEncode({'type': item.action!.type, 'fields': item.action!.fields})}',
          },
        )
        .toList(growable: false);

    _inputController.clear();
    setState(() {
      _sending = true;
      _suggestions = const [];
      _messages.add(_AddamMessage(text: message, fromAddam: false));
    });
    _scrollToBottom();

    try {
      final catalog = await _carregarCatalogo();
      final answer = await widget.api.chatWithAddam(
        message,
        history: history,
        catalog: catalog,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(
          _AddamMessage(
            text: answer.text,
            fromAddam: true,
            action: answer.action,
          ),
        );
        _suggestions = answer.suggestions;
        _sending = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _AddamMessage(
            text: error is ApiException ? error.message : 'Não consegui falar com o serviço do Addam. Verifique a conexão e tente novamente.',
            fromAddam: true,
          ),
        );
        _suggestions = const [
          'Tentar novamente: oi',
          'O que você consegue fazer?',
        ];
        _sending = false;
      });
    }
    _scrollToBottom();
  }

  Future<List<Map<String, dynamic>>> _carregarCatalogo() async {
    final loadedAt = _catalogLoadedAt;
    if (loadedAt != null &&
        DateTime.now().difference(loadedAt) < const Duration(seconds: 30)) {
      return _catalog;
    }

    try {
      final products = await widget.api.getStock();
      final catalog = products
          .take(20)
          .map(
            (product) => <String, dynamic>{
              'id': product.id,
              'nome': product.name,
              'tipo': product.type,
              'quantidade': product.quantity,
              'preco': product.price,
              'descricao': product.description ?? '',
              'codigoBarras': product.barcode ?? '',
            },
          )
          .toList(growable: false);
      if (mounted) {
        _catalog = catalog;
        _catalogLoadedAt = DateTime.now();
      }
      return catalog;
    } catch (_) {
      return _catalog;
    }
  }

  Future<void> _confirmAction(_AddamMessage message) async {
    final action = message.action;
    if (action == null || _executingAction || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_tituloAcao(action.type)),
        content: Text(_resumoAcao(action)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Revisar depois'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar e gravar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _executingAction = true);
    try {
      final result = await widget.api.executeAddamAction(action);
      if (!mounted) return;
      setState(() {
        message.action = null;
        _messages.add(_AddamMessage(text: result, fromAddam: true));
        _suggestions = const [
          'O que você consegue fazer?',
          'Como consulto o estoque?',
        ];
        _executingAction = false;
        _catalogLoadedAt = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _AddamMessage(
            text: error is ApiException ? error.message : 'A API não concluiu a ação. Confira os dados e tente novamente.',
            fromAddam: true,
          ),
        );
        _executingAction = false;
      });
    }
    _scrollToBottom();
  }

  String _tituloAcao(String type) => switch (type) {
    'create_customer' => 'Cadastrar cliente',
    'update_customer' => 'Atualizar cliente',
    'create_product' => 'Cadastrar produto',
    'update_product' => 'Atualizar produto',
    'stock_entry' => 'Registrar entrada de estoque',
    'stock_exit' => 'Registrar saída de estoque',
    'create_employee' => 'Cadastrar funcionário',
    'update_employee' => 'Atualizar funcionário',
    'create_table' => 'Cadastrar mesa',
    'update_table' => 'Atualizar mesa',
    'create_sale' => 'Criar venda',
    _ => 'Confirmar ação do Addam',
  };

  String _resumoAcao(AddamActionDraft action) {
    final fields = action.fields;
    String value(String key) => fields[key]?.toString() ?? '';
    switch (action.type) {
      case 'create_customer':
        return 'Nome: ${value('nome')}\nE-mail: ${value('email').isEmpty ? 'não informado' : value('email')}';
      case 'create_product':
        return 'Produto: ${value('nome')}\nTipo: ${value('tipo')}\nPreço: R\$ ${value('preco')}\nEstoque inicial: ${value('quantidade')} unidades';
      case 'stock_entry':
      case 'stock_exit':
        return 'Produto: ${value('produtoNome').isEmpty ? 'ID ${value('produtoId')}' : value('produtoNome')}\nQuantidade: ${value('quantidade')}\nMotivo: ${value('motivo')}';
      case 'update_product':
        return 'Produto ID: ${value('id_produto')}\nNome: ${value('nome')}\nTipo: ${value('tipo')}\nPreço: R\$ ${value('preco')}';
      case 'create_employee':
        return 'Nome: ${value('nome')}\nCargo: ${value('cargo')}';
      case 'create_table':
        return 'Mesa ${value('numero')}\nCapacidade: ${value('capacidade')} lugares';
      case 'create_sale':
        final items = fields['itens'] is List
            ? (fields['itens'] as List)
                  .whereType<Map>()
                  .map(
                    (item) =>
                        '${item['produtoNome'] ?? 'Produto ID ${item['produtoId']}'} × ${item['quantidade']}',
                  )
                  .join('\n')
            : 'Nenhum item';
        return 'Forma de pagamento: ${value('formaPagamento')}\n$items';
      default:
        return fields.entries
            .map((entry) => '${entry.key}: ${entry.value}')
            .join('\n');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(
                  Icons.smart_toy_outlined,
                  color: colorScheme.primary,
                ),
              ),
              title: const Text('Addam'),
              subtitle: const Text(
                'Qwen local • ações pela API com confirmação',
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            itemCount: _messages.length + (_sending ? 1 : 0),
            itemBuilder: (context, index) {
              if (_sending && index == _messages.length) {
                return const _TypingIndicator();
              }
              final message = _messages[index];
              return _MessageBubble(
                message: message,
                onConfirmAction: message.action == null
                    ? null
                    : () => _confirmAction(message),
                onCancelAction: message.action == null
                    ? null
                    : () => setState(() => message.action = null),
                actionBusy: _executingAction,
              );
            },
          ),
        ),
        if (!_sending && _suggestions.isNotEmpty)
          SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              scrollDirection: Axis.horizontal,
              itemCount: _suggestions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return ActionChip(
                  label: Text(suggestion),
                  onPressed: () => _send(suggestion),
                );
              },
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    enabled: !_sending,
                    maxLength: 500,
                    minLines: 1,
                    maxLines: 3,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      hintText: 'Converse com o Addam...',
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: IconButton.filled(
                    tooltip: 'Enviar mensagem',
                    onPressed: _sending ? null : () => _send(),
                    icon: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AddamMessage {
  _AddamMessage({required this.text, required this.fromAddam, this.action});

  final String text;
  final bool fromAddam;
  AddamActionDraft? action;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.onConfirmAction,
    required this.onCancelAction,
    required this.actionBusy,
  });

  final _AddamMessage message;
  final VoidCallback? onConfirmAction;
  final VoidCallback? onCancelAction;
  final bool actionBusy;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fromAddam = message.fromAddam;
    return Align(
      alignment: fromAddam ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: fromAddam ? Colors.white : colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
            border: fromAddam
                ? Border.all(color: const Color(0xFFE9DED3))
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(message.text),
              if (message.action case final action?) ...[
                const SizedBox(height: 10),
                Text(
                  'Proposta para revisão',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                SelectableText(
                  action.fields.entries
                      .map((entry) => '${entry.key}: ${entry.value}')
                      .join('\n'),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton.tonal(
                      onPressed: actionBusy ? null : onConfirmAction,
                      child: const Text('Confirmar'),
                    ),
                    TextButton(
                      onPressed: actionBusy ? null : onCancelAction,
                      child: const Text('Cancelar'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Addam está pensando...'),
          ],
        ),
      ),
    );
  }
}

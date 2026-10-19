import 'package:flutter/material.dart';

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
        'Olá! Sou o Addam, assistente de teste da Padaria Debortolo. '
        'Nesta versão posso orientar você pelo aplicativo. Ainda não consulto '
        'nem altero dados, não crio pedidos e não gero PDFs.',
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
  List<String> _suggestions = _welcome.suggestions;
  bool _sending = false;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send([String? suggestedMessage]) async {
    if (_sending) return;
    final message = (suggestedMessage ?? _inputController.text).trim();
    if (message.isEmpty) return;

    _inputController.clear();
    setState(() {
      _sending = true;
      _suggestions = const [];
      _messages.add(_AddamMessage(text: message, fromAddam: false));
    });
    _scrollToBottom();

    try {
      final answer = await widget.api.chatWithAddam(message);
      if (!mounted) return;
      setState(() {
        _messages.add(_AddamMessage(text: answer.text, fromAddam: true));
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
                'Assistente experimental • respostas guiadas',
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
              return _MessageBubble(message: _messages[index]);
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
  const _AddamMessage({required this.text, required this.fromAddam});

  final String text;
  final bool fromAddam;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _AddamMessage message;

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
          child: SelectableText(message.text),
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

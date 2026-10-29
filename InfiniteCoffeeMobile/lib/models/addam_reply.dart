import 'dart:convert';

class AddamReply {
  const AddamReply({
    required this.assistant,
    required this.text,
    required this.suggestions,
    this.action,
  });

  final String assistant;
  final String text;
  final List<String> suggestions;
  final AddamActionDraft? action;

  factory AddamReply.fromJson(Map<String, dynamic> json) {
    final decodedReply = _decodeReply(json['reply']);
    final topSuggestions = json['suggestions'];
    final suggestions = _cleanSuggestions(
      topSuggestions is List && topSuggestions.isNotEmpty
          ? topSuggestions
          : decodedReply.suggestions,
    );
    return AddamReply(
      assistant: json['assistant']?.toString() ?? 'Addam',
      text: decodedReply.text,
      suggestions: suggestions,
      action: json['action'] is Map<String, dynamic>
          ? AddamActionDraft.fromJson(json['action'] as Map<String, dynamic>)
          : null,
    );
  }
}

class _DecodedReply {
  const _DecodedReply(this.text, [this.suggestions]);

  final String text;
  final List<dynamic>? suggestions;
}

_DecodedReply _decodeReply(Object? value) {
  var text = value?.toString().trim() ?? '';
  List<dynamic>? suggestions;
  for (var depth = 0; depth < 2; depth++) {
    if (!text.startsWith('{')) {
      return _DecodedReply(
        text.isEmpty ? 'Não consegui montar uma resposta.' : text,
        suggestions,
      );
    }
    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      return const _DecodedReply(
        'Desculpe, não consegui organizar uma resposta agora. Pode perguntar de outro jeito?',
      );
    }
    if (decoded is! Map || decoded['reply'] is! String) {
      return const _DecodedReply(
        'Desculpe, não consegui organizar uma resposta agora. Pode perguntar de outro jeito?',
      );
    }
    if (decoded['suggestions'] is List) {
      suggestions = (decoded['suggestions'] as List).cast<dynamic>();
    }
    text = (decoded['reply'] as String).trim();
  }
  if (text.startsWith('{')) {
    return const _DecodedReply(
      'Desculpe, não consegui organizar uma resposta agora. Pode perguntar de outro jeito?',
    );
  }
  return _DecodedReply(text, suggestions);
}

List<String> _cleanSuggestions(Object? value) {
  if (value is! List) return const [];
  final seen = <String>{};
  final result = <String>[];
  const connectives = {
    'a',
    'as',
    'o',
    'os',
    'de',
    'do',
    'da',
    'e',
    'ou',
    'como',
    'qual',
    'que',
    'voce',
    'para',
  };
  for (final item in value.whereType<String>()) {
    final suggestion = item.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (suggestion.isEmpty ||
        suggestion.length > 80 ||
        suggestion.split(' ').length < 2 ||
        RegExp(r'[_{}\[\]<>`]').hasMatch(suggestion)) {
      continue;
    }
    final signature =
        suggestion
            .toLowerCase()
            .split(' ')
            .where((word) => !connectives.contains(word))
            .toList()
          ..sort();
    final deduplicationKey = signature.join(' ');
    if (deduplicationKey.isEmpty || !seen.add(deduplicationKey)) continue;
    result.add(suggestion);
    if (result.length == 3) break;
  }
  return result;
}

class AddamActionDraft {
  const AddamActionDraft({required this.type, required this.fields});

  final String type;
  final Map<String, dynamic> fields;

  factory AddamActionDraft.fromJson(Map<String, dynamic> json) {
    final rawFields = json['fields'];
    return AddamActionDraft(
      type: json['type']?.toString() ?? '',
      fields: rawFields is Map<String, dynamic> ? rawFields : const {},
    );
  }
}

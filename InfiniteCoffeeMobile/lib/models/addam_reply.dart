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
    final rawSuggestions = json['suggestions'];
    return AddamReply(
      assistant: json['assistant']?.toString() ?? 'Addam',
      text: json['reply']?.toString() ?? 'Não consegui montar uma resposta.',
      suggestions: rawSuggestions is List
          ? rawSuggestions.whereType<String>().take(4).toList(growable: false)
          : const [],
      action: json['action'] is Map<String, dynamic>
          ? AddamActionDraft.fromJson(json['action'] as Map<String, dynamic>)
          : null,
    );
  }
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

class AddamReply {
  const AddamReply({
    required this.assistant,
    required this.text,
    required this.suggestions,
  });

  final String assistant;
  final String text;
  final List<String> suggestions;

  factory AddamReply.fromJson(Map<String, dynamic> json) {
    final rawSuggestions = json['suggestions'];
    return AddamReply(
      assistant: json['assistant']?.toString() ?? 'Addam',
      text: json['reply']?.toString() ?? 'Não consegui montar uma resposta.',
      suggestions: rawSuggestions is List
          ? rawSuggestions.whereType<String>().take(4).toList(growable: false)
          : const [],
    );
  }
}

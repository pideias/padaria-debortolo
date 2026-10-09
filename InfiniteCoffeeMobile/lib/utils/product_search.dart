import '../models/product.dart';

List<Product> filterProducts(Iterable<Product> products, String query) {
  final term = _normalize(query);
  if (term.isEmpty) return products.toList(growable: false);

  return products
      .where(
        (product) =>
            _normalize(product.name).contains(term) ||
            _normalize(product.barcode ?? '').contains(term),
      )
      .toList(growable: false);
}

String _normalize(String value) {
  const diacritics = {
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
  };
  final normalized = StringBuffer();
  for (final rune in value.toLowerCase().runes) {
    final character = String.fromCharCode(rune);
    normalized.write(diacritics[character] ?? character);
  }
  return normalized.toString().trim();
}

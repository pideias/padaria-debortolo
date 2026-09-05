class Product {
  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.type,
    required this.quantity,
    this.barcode,
    this.description,
  });

  final int id;
  final String name;
  final double price;
  final String type;
  final int quantity;
  final String? barcode;
  final String? description;

  // Converte o JSON da API (que usa os nomes do banco CdmEdu) em um objeto Dart.
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: _int(json['id_produto']),
      name: '${json['nome_produto'] ?? ''}',
      price: _double(json['preco']),
      type: '${json['tipo'] ?? ''}',
      quantity: _int(json['quantidade_estoque']),
      barcode: _text(json['codigo_barras']),
      description: _text(json['descricao']),
    );
  }

  Product withQuantity(int value) => Product(
    id: id,
    name: name,
    price: price,
    type: type,
    quantity: value,
    barcode: barcode,
    description: description,
  );

  static int _int(Object? value) => int.tryParse('$value') ?? 0;
  static double _double(Object? value) => double.tryParse('$value') ?? 0;
  static String? _text(Object? value) {
    if (value == null || value is Map && value.isEmpty) return null;
    final text = '$value'.trim();
    return text.isEmpty || text == '{}' ? null : text;
  }
}

class SalesByProduct {
  const SalesByProduct({
    required this.productId,
    required this.productName,
    required this.quantitySold,
    required this.revenue,
  });

  final int productId;
  final String productName;
  final int quantitySold;
  final double revenue;

  factory SalesByProduct.fromJson(Map<String, dynamic> json) {
    return SalesByProduct(
      productId: _toInt(json['id_produto']),
      productName: '${json['nome_produto'] ?? 'Produto'}',
      quantitySold: _toInt(json['quantidade_vendida']),
      revenue: _toDouble(json['faturamento']),
    );
  }

  static int _toInt(Object? value) => int.tryParse('$value') ?? 0;

  static double _toDouble(Object? value) => double.tryParse('$value') ?? 0;
}

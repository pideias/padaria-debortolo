import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_coffee_app/models/product.dart';
import 'package:infinite_coffee_app/utils/product_search.dart';

void main() {
  const products = [
    Product(
      id: 1,
      name: 'Pão Francês',
      price: 0.75,
      type: 'Unidade',
      quantity: 50,
      barcode: '7891234567890',
    ),
    Product(
      id: 2,
      name: 'Café Expresso',
      price: 6,
      type: 'Bebida',
      quantity: 8,
      barcode: 'CAF-002',
    ),
  ];

  test('filtra pelo nome sem diferenciar caixa ou acentos', () {
    expect(filterProducts(products, 'pao'), [products.first]);
    expect(filterProducts(products, 'CAFÉ'), [products.last]);
  });

  test('filtra por trecho do código de barras sem diferenciar caixa', () {
    expect(filterProducts(products, '45678'), [products.first]);
    expect(filterProducts(products, 'caf-002'), [products.last]);
  });

  test('consulta vazia mantém o catálogo completo', () {
    expect(filterProducts(products, '  '), products);
  });
}

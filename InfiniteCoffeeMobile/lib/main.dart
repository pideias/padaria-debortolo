import 'package:flutter/material.dart';

import 'repositories/inventory_repository.dart';
import 'screens/home_screen.dart';
import 'services/inventory_api.dart';
import 'utils/app_theme.dart';

void main() {
  // O main e o ponto inicial do aplicativo Flutter.
  runApp(const InfiniteCoffeeApp());
}

class InfiniteCoffeeApp extends StatefulWidget {
  const InfiniteCoffeeApp({super.key});

  @override
  State<InfiniteCoffeeApp> createState() => _InfiniteCoffeeAppState();
}

class _InfiniteCoffeeAppState extends State<InfiniteCoffeeApp> {
  late final InventoryRepository _repository;

  @override
  void initState() {
    super.initState();
    // A API e o repositorio sao injetados uma vez e compartilhados pelas telas.
    _repository = InventoryRepository(InventoryApi());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Infinite Coffee',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: HomeScreen(repository: _repository),
    );
  }
}

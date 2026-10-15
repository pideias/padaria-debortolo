import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/sales_by_product.dart';
import '../repositories/inventory_repository.dart';

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key, required this.repository});

  final InventoryRepository repository;

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  static const _colors = [
    Color(0xFFB5541A),
    Color(0xFF3F786A),
    Color(0xFFE6A23C),
    Color(0xFF6574A8),
    Color(0xFFBC5B68),
    Color(0xFF8B6848),
  ];

  late Future<List<SalesByProduct>> _report;
  _SalesMeasure _measure = _SalesMeasure.quantity;
  int? _selectedSlice;

  @override
  void initState() {
    super.initState();
    _report = widget.repository.getSalesByProduct();
  }

  Future<void> _refresh() async {
    final request = widget.repository.getSalesByProduct();
    setState(() {
      _report = request;
      _selectedSlice = null;
    });
    try {
      await request;
    } catch (_) {
      // O FutureBuilder apresenta a mensagem de erro e permite tentar novamente.
    }
  }

  double _value(SalesByProduct item) => switch (_measure) {
    _SalesMeasure.quantity => item.quantitySold.toDouble(),
    _SalesMeasure.revenue => item.revenue,
  };

  List<_SalesSlice> _makeSlices(List<SalesByProduct> sales) {
    final ordered = sales.where((item) => _value(item) > 0).toList()
      ..sort((a, b) => _value(b).compareTo(_value(a)));
    if (ordered.length <= 6) {
      return [
        for (var index = 0; index < ordered.length; index++)
          _SalesSlice(
            label: ordered[index].productName,
            value: _value(ordered[index]),
            color: _colors[index % _colors.length],
          ),
      ];
    }

    final slices = [
      for (var index = 0; index < 5; index++)
        _SalesSlice(
          label: ordered[index].productName,
          value: _value(ordered[index]),
          color: _colors[index % _colors.length],
        ),
    ];
    slices.add(
      _SalesSlice(
        label: 'Outros produtos',
        value: ordered
            .skip(5)
            .fold<double>(0, (sum, item) => sum + _value(item)),
        color: _colors[5],
      ),
    );
    return slices;
  }

  String _formatCurrency(double value) =>
      'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';

  String _formatValue(double value) => _measure == _SalesMeasure.quantity
      ? '${value.round()} un.'
      : _formatCurrency(value);

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 900;
    return FutureBuilder<List<SalesByProduct>>(
      future: _report,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 40),
                  const SizedBox(height: 12),
                  const Text(
                    'Não foi possível carregar o relatório. Verifique a conexão com o servidor.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
          );
        }

        final sales = snapshot.data ?? const <SalesByProduct>[];
        if (sales.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _ReportHeader(onRefresh: _refresh),
              const SizedBox(height: 32),
              const Icon(Icons.pie_chart_outline, size: 52),
              const SizedBox(height: 12),
              const Text(
                'Ainda não há vendas finalizadas para gerar o gráfico.',
                textAlign: TextAlign.center,
              ),
            ],
          );
        }

        final slices = _makeSlices(sales);
        final totalUnits = sales.fold<int>(
          0,
          (total, item) => total + item.quantitySold,
        );
        final totalRevenue = sales.fold<double>(
          0,
          (total, item) => total + item.revenue,
        );
        final chart = _SalesPieChart(
          slices: slices,
          selectedIndex: _selectedSlice,
          onSliceSelected: (index) => setState(() => _selectedSlice = index),
        );
        final legend = _SalesLegend(
          slices: slices,
          selectedIndex: _selectedSlice,
          total: slices.fold<double>(0, (sum, slice) => sum + slice.value),
          valueLabel: _formatValue,
          onSelected: (index) => setState(() => _selectedSlice = index),
        );

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _ReportHeader(onRefresh: _refresh),
            const SizedBox(height: 8),
            Text(
              'Distribuição por produto · todo o histórico de pedidos finalizados',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: Colors.black54),
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<_SalesMeasure>(
                      initialValue: _measure,
                      decoration: const InputDecoration(
                        labelText: 'Exibir no gráfico',
                        prefixIcon: Icon(Icons.tune),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: _SalesMeasure.quantity,
                          child: Text('Unidades vendidas'),
                        ),
                        DropdownMenuItem(
                          value: _SalesMeasure.revenue,
                          child: Text('Faturamento por produto'),
                        ),
                      ],
                      onChanged: (value) => setState(() {
                        _measure = value ?? _SalesMeasure.quantity;
                        _selectedSlice = null;
                      }),
                    ),
                    const SizedBox(height: 20),
                    if (desktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: chart),
                          const SizedBox(width: 20),
                          Expanded(child: legend),
                        ],
                      )
                    else ...[
                      chart,
                      const SizedBox(height: 12),
                      legend,
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _SummaryCard(
                  icon: Icons.inventory_2_outlined,
                  label: 'Unidades vendidas',
                  value: '$totalUnits',
                ),
                _SummaryCard(
                  icon: Icons.payments_outlined,
                  label: 'Faturamento registrado',
                  value: _formatCurrency(totalRevenue),
                ),
                _SummaryCard(
                  icon: Icons.category_outlined,
                  label: 'Produtos vendidos',
                  value: '${sales.length}',
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _ReportHeader extends StatelessWidget {
  const _ReportHeader({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          'Relatórios de vendas',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      IconButton.filledTonal(
        tooltip: 'Atualizar relatório',
        onPressed: onRefresh,
        icon: const Icon(Icons.refresh),
      ),
    ],
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 220,
    child: Card(
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFFB5541A)),
        title: Text(label, style: Theme.of(context).textTheme.bodySmall),
        subtitle: Text(
          value,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    ),
  );
}

class _SalesSlice {
  const _SalesSlice({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;
}

class _SalesPieChart extends StatelessWidget {
  const _SalesPieChart({
    required this.slices,
    required this.selectedIndex,
    required this.onSliceSelected,
  });

  final List<_SalesSlice> slices;
  final int? selectedIndex;
  final ValueChanged<int> onSliceSelected;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1.15,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onTapUp: (details) {
            final index = _sliceAt(details.localPosition, size);
            if (index != null) onSliceSelected(index);
          },
          child: CustomPaint(
            painter: _PiePainter(slices: slices, selectedIndex: selectedIndex),
            child: const SizedBox.expand(),
          ),
        );
      },
    ),
  );

  int? _sliceAt(Offset point, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final dx = point.dx - center.dx;
    final dy = point.dy - center.dy;
    if (math.sqrt(dx * dx + dy * dy) >
        math.min(size.width, size.height) * .46) {
      return null;
    }

    final total = slices.fold<double>(0, (sum, slice) => sum + slice.value);
    if (total <= 0) return null;
    final angle =
        (math.atan2(dy, dx) + math.pi / 2 + math.pi * 2) % (math.pi * 2);
    var cursor = 0.0;
    for (var index = 0; index < slices.length; index++) {
      cursor += slices[index].value / total * math.pi * 2;
      if (angle <= cursor) return index;
    }
    return slices.isEmpty ? null : slices.length - 1;
  }
}

class _PiePainter extends CustomPainter {
  const _PiePainter({required this.slices, required this.selectedIndex});

  final List<_SalesSlice> slices;
  final int? selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<double>(0, (sum, slice) => sum + slice.value);
    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * .43;
    var startAngle = -math.pi / 2;
    for (var index = 0; index < slices.length; index++) {
      final slice = slices[index];
      final sweepAngle = slice.value / total * math.pi * 2;
      final middleAngle = startAngle + sweepAngle / 2;
      final selected = index == selectedIndex;
      final offset = selected
          ? Offset(math.cos(middleAngle) * 6, math.sin(middleAngle) * 6)
          : Offset.zero;
      final sliceCenter = center + offset;
      final rect = Rect.fromCircle(center: sliceCenter, radius: radius);
      final path = Path()
        ..moveTo(sliceCenter.dx, sliceCenter.dy)
        ..arcTo(rect, startAngle, sweepAngle, false)
        ..close();

      canvas.drawShadow(
        path,
        Colors.black.withValues(alpha: .18),
        selected ? 7 : 3,
        true,
      );
      canvas.drawPath(path, Paint()..color = slice.color);
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _PiePainter oldDelegate) =>
      oldDelegate.slices != slices ||
      oldDelegate.selectedIndex != selectedIndex;
}

class _SalesLegend extends StatelessWidget {
  const _SalesLegend({
    required this.slices,
    required this.selectedIndex,
    required this.total,
    required this.valueLabel,
    required this.onSelected,
  });

  final List<_SalesSlice> slices;
  final int? selectedIndex;
  final double total;
  final String Function(double value) valueLabel;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var index = 0; index < slices.length; index++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: selectedIndex == index
                ? slices[index].color.withValues(alpha: .10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onSelected(index),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: slices[index].color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        slices[index].label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(valueLabel(slices[index].value)),
                    const SizedBox(width: 8),
                    Text(
                      total == 0
                          ? '0%'
                          : '${(slices[index].value / total * 100).toStringAsFixed(1).replaceAll('.', ',')}%',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

enum _SalesMeasure { quantity, revenue }

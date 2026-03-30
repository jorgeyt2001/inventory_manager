import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/sale_provider.dart';
import '../../providers/product_provider.dart';
import '../../utils/formatters.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Analytics'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Resumen'),
              Tab(text: 'Por Categoría'),
              Tab(text: 'Top Productos'),
              Tab(text: 'Pago'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ResumenTab(),
            _CategoriasTab(),
            _TopProductosTab(),
            _PagoTab(),
          ],
        ),
      ),
    );
  }
}

// ── Resumen tab ───────────────────────────────────────────────────────────────

class _ResumenTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SaleProvider>();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    final todaySales = provider.getSalesByDateRange(today, tomorrow);
    final weekSales = provider.getSalesByDateRange(weekStart, tomorrow);
    final monthSales = provider.getSalesByDateRange(monthStart, tomorrow);
    final allSales = provider.sales;

    double sumSales(List s) => s.fold<double>(0, (a, b) => a + b.total);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Períodos de ventas', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.4,
            children: [
              _periodCard(context, 'Hoy', todaySales.length, sumSales(todaySales), Colors.green),
              _periodCard(context, 'Esta semana', weekSales.length, sumSales(weekSales), Colors.blue),
              _periodCard(context, 'Este mes', monthSales.length, sumSales(monthSales), Colors.purple),
              _periodCard(context, 'Total', allSales.length, sumSales(allSales), Colors.orange),
            ],
          ),
          const SizedBox(height: 24),
          Text('Ticket medio', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _avgRow(context, 'Hoy', todaySales),
                  _avgRow(context, 'Esta semana', weekSales),
                  _avgRow(context, 'Este mes', monthSales),
                  _avgRow(context, 'Total', allSales),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _periodCard(BuildContext context, String label, int count, double total, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppFormatters.currency(total),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color),
                ),
                Text('$count transacciones', style: const TextStyle(fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _avgRow(BuildContext context, String label, List sales) {
    final avg = sales.isEmpty ? 0.0 : sales.fold<double>(0, (a, b) => a + b.total) / sales.length;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(AppFormatters.currency(avg), style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Por categoría tab ─────────────────────────────────────────────────────────

class _CategoriasTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final saleProvider = context.watch<SaleProvider>();
    final productProvider = context.watch<ProductProvider>();

    final productById = Map.fromEntries(
      productProvider.allProducts.map((p) => MapEntry(p.id, p)),
    );

    final Map<String, ({int units, double revenue})> catStats = {};
    for (final sale in saleProvider.sales) {
      for (final item in sale.items) {
        final product = productById[item.productId];
        final cat = product?.category ?? 'Sin categoría';
        final prev = catStats[cat] ?? (units: 0, revenue: 0.0);
        catStats[cat] = (
          units: prev.units + item.quantity,
          revenue: prev.revenue + item.total,
        );
      }
    }

    final sorted = catStats.entries.toList()
      ..sort((a, b) => b.value.revenue.compareTo(a.value.revenue));

    if (sorted.isEmpty) {
      return const Center(child: Text('No hay ventas registradas'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final entry = sorted[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue[50],
              child: Text('${index + 1}', style: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.bold)),
            ),
            title: Text(entry.key),
            subtitle: Text('${entry.value.units} unidades'),
            trailing: Text(
              AppFormatters.currency(entry.value.revenue),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        );
      },
    );
  }
}

// ── Top productos tab ─────────────────────────────────────────────────────────

class _TopProductosTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final saleProvider = context.watch<SaleProvider>();

    final Map<String, ({int units, double revenue, String productId})> stats = {};
    for (final sale in saleProvider.sales) {
      for (final item in sale.items) {
        final key = item.productName;
        final prev = stats[key] ?? (units: 0, revenue: 0.0, productId: item.productId);
        stats[key] = (
          units: prev.units + item.quantity,
          revenue: prev.revenue + item.total,
          productId: item.productId,
        );
      }
    }

    final top = stats.entries.toList()
      ..sort((a, b) => b.value.units.compareTo(a.value.units));
    final top10 = top.take(10).toList();

    if (top10.isEmpty) {
      return const Center(child: Text('No hay ventas registradas'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: top10.length,
      itemBuilder: (context, index) {
        final entry = top10[index];
        final medalColor = index == 0
            ? const Color(0xFFFFD700)
            : index == 1
                ? const Color(0xFFC0C0C0)
                : index == 2
                    ? const Color(0xFFCD7F32)
                    : Colors.blue[200]!;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: medalColor.withAlpha(50),
              child: Text(
                '${index + 1}',
                style: TextStyle(color: medalColor, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(entry.key, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('${entry.value.units} unidades vendidas'),
            trailing: Text(
              AppFormatters.currency(entry.value.revenue),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }
}

// ── Por método de pago tab ────────────────────────────────────────────────────

class _PagoTab extends StatelessWidget {
  static const _colors = {
    'Efectivo': Colors.green,
    'Tarjeta': Colors.blue,
    'Bizum': Colors.purple,
    'Transferencia': Colors.orange,
  };

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SaleProvider>();

    final Map<String, ({int count, double total})> stats = {};
    double grandTotal = 0;
    for (final sale in provider.sales) {
      final prev = stats[sale.paymentMethod] ?? (count: 0, total: 0.0);
      stats[sale.paymentMethod] = (count: prev.count + 1, total: prev.total + sale.total);
      grandTotal += sale.total;
    }

    final sorted = stats.entries.toList()
      ..sort((a, b) => b.value.total.compareTo(a.value.total));

    if (sorted.isEmpty) {
      return const Center(child: Text('No hay ventas registradas'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total general', style: Theme.of(context).textTheme.titleSmall),
                Text(
                  AppFormatters.currency(grandTotal),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...sorted.map((entry) {
          final pct = grandTotal > 0 ? entry.value.total / grandTotal : 0.0;
          final color = (_colors[entry.key] as Color?) ?? Colors.grey;
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(_paymentIcon(entry.key), color: color, size: 20),
                          const SizedBox(width: 8),
                          Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(AppFormatters.currency(entry.value.total),
                              style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                          Text('${entry.value.count} transacciones',
                              style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: pct,
                    color: color,
                    backgroundColor: color.withAlpha(30),
                  ),
                  const SizedBox(height: 4),
                  Text('${(pct * 100).toStringAsFixed(1)}% del total',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  IconData _paymentIcon(String method) {
    switch (method) {
      case 'Tarjeta': return Icons.credit_card;
      case 'Bizum': return Icons.smartphone;
      case 'Transferencia': return Icons.account_balance;
      default: return Icons.payments;
    }
  }
}

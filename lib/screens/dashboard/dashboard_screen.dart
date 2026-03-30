import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../providers/product_provider.dart';
import '../../providers/sale_provider.dart';
import '../../providers/reservation_provider.dart';
import '../../services/api_service.dart';
import '../../utils/formatters.dart';
import '../products/products_screen.dart';
import '../sales/sales_screen.dart';
import '../sales/sale_history_screen.dart';
import '../returns/returns_screen.dart';
import '../reservations/reservations_screen.dart';
import '../settings/settings_screen.dart';
import '../analytics/analytics_screen.dart';

// ── Navigation Shell ──────────────────────────────────────────────────────────

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  void _showMoreSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.assignment_return, color: Colors.orange),
              title: const Text('Devoluciones'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ReturnsScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_outlined, color: Colors.teal),
              title: const Text('Reservas'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ReservationsScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart, color: Colors.blue),
              title: const Text('Analytics'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AnalyticsScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined, color: Colors.grey),
              title: const Text('Ajustes'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()));
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          _DashboardTab(),
          SalesScreen(),
          ProductsScreen(),
          SaleHistoryScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (i) {
          if (i == 4) {
            _showMoreSheet();
          } else {
            setState(() => _currentIndex = i);
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.point_of_sale_outlined),
            activeIcon: Icon(Icons.point_of_sale),
            label: 'Ventas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2),
            label: 'Productos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Historial',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.more_horiz),
            label: 'Más',
          ),
        ],
      ),
    );
  }
}

// ── Dashboard Tab ─────────────────────────────────────────────────────────────

class _DashboardTab extends StatefulWidget {
  const _DashboardTab();

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  bool? _isConnected;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final productProvider = context.read<ProductProvider>();
    final saleProvider = context.read<SaleProvider>();
    final reservationProvider = context.read<ReservationProvider>();

    final connectionFuture = ApiService.checkConnection();

    await productProvider.loadProducts();
    await saleProvider.loadSales();
    await reservationProvider.loadReservations();

    final connected = await connectionFuture;

    try {
      _stats = await ApiService.getDashboardStats();
    } catch (e) {
      debugPrint('Error loading stats: $e');
      _stats = {
        'total_products': productProvider.allProducts.length,
        'low_stock_count': productProvider.lowStockProducts.length,
        'today_sales': 0.0,
        'total_sales': 0.0,
      };
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isConnected = connected;
      });
    }
  }

  void _showQuickRestock(Product product) {
    final diff = (product.minStock - product.stock).clamp(1, 999);
    final controller = TextEditingController(text: '$diff');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reponer — ${product.name}',
            overflow: TextOverflow.ellipsis, maxLines: 1),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Cantidad a añadir',
            prefixIcon: Icon(Icons.add_circle_outline),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final qty = int.tryParse(controller.text);
              if (qty != null && qty > 0) {
                await context.read<ProductProvider>().updateStock(product.id, qty);
                if (ctx.mounted) Navigator.pop(ctx);
                _loadData();
              }
            },
            child: const Text('Reponer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.f5) {
          _loadData();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Selene Inventory'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualizar (F5)',
              onPressed: _loadData,
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Ajustes',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildConnectionBar(),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _loadData,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Resumen',
                                style: Theme.of(context).textTheme.headlineSmall),
                            const SizedBox(height: 12),
                            _buildStatsGrid(),
                            const SizedBox(height: 24),
                            _buildWeeklySalesChart(),
                            const SizedBox(height: 24),
                            _buildLowStockAlert(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildConnectionBar() {
    final connected = _isConnected;
    if (connected == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: connected ? Colors.green[50] : Colors.red[50],
      child: Row(
        children: [
          Icon(Icons.circle,
              size: 10, color: connected ? Colors.green[700] : Colors.red[700]),
          const SizedBox(width: 8),
          Text(
            connected ? 'Conectado al servidor' : 'Sin conexión con el servidor',
            style: TextStyle(
              fontSize: 12,
              color: connected ? Colors.green[800] : Colors.red[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final pendingReservations =
        context.watch<ReservationProvider>().pendingReservations.length;
    final products = context.watch<ProductProvider>().allProducts;
    final stockValue =
        products.fold<double>(0, (s, p) => s + p.price * p.stock);
    final costValue =
        products.fold<double>(0, (s, p) => s + p.cost * p.stock);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.6,
      children: [
        _buildStatCard('Productos', '${_stats['total_products'] ?? 0}',
            Icons.inventory_2, Colors.blue),
        _buildStatCard('Stock Bajo', '${_stats['low_stock_count'] ?? 0}',
            Icons.warning_amber_rounded, Colors.orange),
        _buildStatCard(
            'Ventas Hoy',
            AppFormatters.currency(
                (_stats['today_sales'] as num?)?.toDouble() ?? 0.0),
            Icons.today,
            Colors.green),
        _buildStatCard(
            'Total Ventas',
            AppFormatters.currency(
                (_stats['total_sales'] as num?)?.toDouble() ?? 0.0),
            Icons.euro,
            Colors.purple),
        _buildStatCard('Valor Stock', AppFormatters.currency(stockValue),
            Icons.account_balance_wallet, Colors.indigo),
        _buildStatCard('Valor Coste', AppFormatters.currency(costValue),
            Icons.price_change, Colors.brown),
        if (pendingReservations > 0)
          _buildStatCard('Reservas', '$pendingReservations pendientes',
              Icons.bookmark, Colors.teal),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 26),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklySalesChart() {
    final saleProvider = context.watch<SaleProvider>();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final days = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
    final totals = days.map((day) {
      final nextDay = day.add(const Duration(days: 1));
      return saleProvider
          .getSalesByDateRange(day, nextDay)
          .fold<double>(0, (sum, s) => sum + s.total);
    }).toList();

    final maxTotal = totals.fold<double>(0, max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ventas esta semana',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Card(
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 140,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (i) {
                  final total = totals[i];
                  final barHeight =
                      maxTotal > 0 ? (total / maxTotal) * 100.0 : 0.0;
                  final isToday = i == 6;
                  final label = _dayLabel(days[i]);
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (total > 0)
                            Text(
                              AppFormatters.currency(total),
                              style: TextStyle(
                                fontSize: 8,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          const SizedBox(height: 2),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            height: barHeight.clamp(4.0, 100.0),
                            decoration: BoxDecoration(
                              color: isToday
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withAlpha(100),
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4)),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isToday
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isToday
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _dayLabel(DateTime day) {
    const labels = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return labels[day.weekday - 1];
  }

  Widget _buildLowStockAlert() {
    final lowStock = context.watch<ProductProvider>().lowStockProducts;
    if (lowStock.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange[700]),
          const SizedBox(width: 8),
          Text(
            'Stock Bajo',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          Text('${lowStock.length} productos',
              style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        ]),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: lowStock.length > 5 ? 5 : lowStock.length,
          itemBuilder: (context, index) {
            final product = lowStock[index];
            return Card(
              elevation: 0,
              color: Colors.orange[50],
              margin: const EdgeInsets.only(bottom: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange[200],
                  foregroundColor: Colors.orange[900],
                  radius: 18,
                  child: Text('${product.stock}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                title: Text(product.name, style: const TextStyle(fontSize: 14)),
                subtitle: Row(
                  children: [
                    Text('Min: ${product.minStock}',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[600])),
                    if (product.color != null) ...[
                      const SizedBox(width: 8),
                      Text(product.color!,
                          style:
                              TextStyle(fontSize: 11, color: Colors.purple[400])),
                    ],
                    if (product.talla != null) ...[
                      const SizedBox(width: 4),
                      Text('T.${product.talla!}',
                          style: TextStyle(
                              fontSize: 11, color: Colors.indigo[400])),
                    ],
                  ],
                ),
                trailing: IconButton(
                  icon: Icon(Icons.add_circle_outline,
                      color: Colors.orange[700]),
                  tooltip: 'Reponer stock',
                  onPressed: () => _showQuickRestock(product),
                ),
                dense: true,
                visualDensity: VisualDensity.compact,
              ),
            );
          },
        ),
        if (lowStock.length > 5)
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProductsScreen()),
            ),
            icon: const Icon(Icons.arrow_forward, size: 16),
            label: Text('Ver todos (${lowStock.length})'),
          ),
      ],
    );
  }
}

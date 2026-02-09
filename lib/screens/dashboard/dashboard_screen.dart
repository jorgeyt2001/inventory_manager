import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/sale_provider.dart';
import '../../providers/reservation_provider.dart';
import '../../database/database_service.dart';
import '../../utils/formatters.dart';
import '../products/products_screen.dart';
import '../sales/sales_screen.dart';
import '../sales/sale_history_screen.dart';
import '../returns/returns_screen.dart';
import '../reservations/reservations_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

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

    await productProvider.loadProducts();
    await saleProvider.loadSales();
    await reservationProvider.loadReservations();
    _stats = await DatabaseService.instance.getStats();

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Selene Inventory'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Resumen', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 12),
                    _buildStatsGrid(),
                    const SizedBox(height: 24),
                    Text('Acciones', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 12),
                    _buildQuickActions(),
                    const SizedBox(height: 24),
                    _buildLowStockAlert(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatsGrid() {
    final pendingReservations = context.watch<ReservationProvider>().pendingReservations.length;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.6,
      children: [
        _buildStatCard('Productos', '${_stats['productsCount'] ?? 0}', Icons.inventory_2, Colors.blue),
        _buildStatCard('Stock Bajo', '${_stats['lowStockCount'] ?? 0}', Icons.warning_amber_rounded, Colors.orange),
        _buildStatCard('Ventas Hoy', AppFormatters.currency(_stats['todaySales'] ?? 0.0), Icons.today, Colors.green),
        _buildStatCard('Total Ventas', AppFormatters.currency(_stats['totalSales'] ?? 0.0), Icons.euro, Colors.purple),
        if (pendingReservations > 0)
          _buildStatCard('Reservas', '$pendingReservations pendientes', Icons.bookmark, Colors.teal),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
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
                Text(value,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(title, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.95,
      children: [
        _buildActionCard('Nueva\nVenta', Icons.point_of_sale, Colors.green,
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesScreen()))),
        _buildActionCard('Productos', Icons.inventory, Colors.blue,
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductsScreen()))),
        _buildActionCard('Historial', Icons.history, Colors.purple,
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SaleHistoryScreen()))),
        _buildActionCard('Devolu-\nciones', Icons.assignment_return, Colors.orange,
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReturnsScreen()))),
        _buildActionCard('Reservas', Icons.bookmark, Colors.teal,
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReservationsScreen()))),
      ],
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 8),
              Text(title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                  maxLines: 2),
            ],
          ),
        ),
      ),
    );
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
          Text('Stock Bajo', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const Spacer(),
          Text('${lowStock.length} productos', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
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
                  child: Text('${product.stock}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                title: Text(product.name, style: const TextStyle(fontSize: 14)),
                subtitle: Row(
                  children: [
                    Text('Min: ${product.minStock}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    if (product.color != null) ...[
                      const SizedBox(width: 8),
                      Text(product.color!, style: TextStyle(fontSize: 11, color: Colors.purple[400])),
                    ],
                    if (product.talla != null) ...[
                      const SizedBox(width: 4),
                      Text('T.${product.talla!}', style: TextStyle(fontSize: 11, color: Colors.indigo[400])),
                    ],
                  ],
                ),
                dense: true,
                visualDensity: VisualDensity.compact,
              ),
            );
          },
        ),
      ],
    );
  }
}

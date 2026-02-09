import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/sale_provider.dart';
import '../../database/database_service.dart';
import '../../utils/formatters.dart';
import '../products/products_screen.dart';
import '../sales/sales_screen.dart';
import '../sales/sale_history_screen.dart';
import '../returns/returns_screen.dart';

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

    await productProvider.loadProducts();
    await saleProvider.loadSales();
    _stats = await DatabaseService.instance.getStats();

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Manager'),
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
                    const SizedBox(height: 16),
                    _buildStatsGrid(),
                    const SizedBox(height: 32),
                    Text('Acciones Rapidas', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 16),
                    _buildQuickActions(),
                    const SizedBox(height: 32),
                    _buildLowStockAlert(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard('Productos', '${_stats['productsCount'] ?? 0}', Icons.inventory_2, Colors.blue),
        _buildStatCard('Stock Bajo', '${_stats['lowStockCount'] ?? 0}', Icons.warning, Colors.orange),
        _buildStatCard('Ventas Hoy', AppFormatters.currency(_stats['todaySales'] ?? 0.0), Icons.today, Colors.green),
        _buildStatCard('Total Ventas', AppFormatters.currency(_stats['totalSales'] ?? 0.0), Icons.attach_money, Colors.purple),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 28),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
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
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: [
        _buildActionCard('Nueva Venta', Icons.point_of_sale, Colors.green,
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesScreen()))),
        _buildActionCard('Productos', Icons.inventory, Colors.blue,
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductsScreen()))),
        _buildActionCard('Historial', Icons.history, Colors.purple,
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SaleHistoryScreen()))),
        _buildActionCard('Devoluciones', Icons.assignment_return, Colors.orange,
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReturnsScreen()))),
      ],
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 40),
              const SizedBox(height: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
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
          const Icon(Icons.warning, color: Colors.orange),
          const SizedBox(width: 8),
          Text('Productos con Stock Bajo', style: Theme.of(context).textTheme.titleMedium),
        ]),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: lowStock.length > 5 ? 5 : lowStock.length,
          itemBuilder: (context, index) {
            final product = lowStock[index];
            return ListTile(
              leading: CircleAvatar(backgroundColor: Colors.orange[100], child: Text('${product.stock}')),
              title: Text(product.name),
              subtitle: Text('Min: ${product.minStock}'),
              dense: true,
            );
          },
        ),
      ],
    );
  }
}

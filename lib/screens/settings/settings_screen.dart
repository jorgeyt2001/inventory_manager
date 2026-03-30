import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/database_service.dart';
import '../../services/api_service.dart';
import '../../providers/category_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/sale_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/export_service.dart';
import 'categories_screen.dart';
import 'locations_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _apiConnected = false;
  bool _checkingConnection = true;
  bool _migrating = false;
  int _migrationProgress = 0;
  int _migrationTotal = 0;
  int _migrationSuccess = 0;
  String? _migrationError;
  bool _migrationDone = false;

  @override
  void initState() {
    super.initState();
    _checkApiConnection();
  }

  Future<void> _checkApiConnection() async {
    setState(() => _checkingConnection = true);
    final connected = await ApiService.checkConnection();
    if (mounted) setState(() { _apiConnected = connected; _checkingConnection = false; });
  }

  Future<void> _migrateLocalData() async {
    setState(() {
      _migrating = true;
      _migrationProgress = 0;
      _migrationTotal = 0;
      _migrationSuccess = 0;
      _migrationError = null;
      _migrationDone = false;
    });

    try {
      final localProducts = await DatabaseService.instance.getAllProducts();
      if (!mounted) return;
      setState(() => _migrationTotal = localProducts.length);

      if (localProducts.isEmpty) {
        setState(() { _migrating = false; _migrationDone = true; });
        return;
      }

      final categoryProvider = context.read<CategoryProvider>();
      await categoryProvider.loadCategories();
      final apiCategories = categoryProvider.categories;

      final categoryMap = <String, int>{
        for (final c in apiCategories) c.name.toLowerCase(): c.id,
      };

      for (final product in localProducts) {
        if (!mounted) return;

        final categoryName = product.category.isEmpty ? 'General' : product.category;
        final categoryKey = categoryName.toLowerCase();

        int? categoryId = categoryMap[categoryKey];
        if (categoryId == null) {
          try {
            final created = await ApiService.createCategory(categoryName);
            categoryId = created['id'] as int;
            categoryMap[categoryKey] = categoryId;
          } catch (e) {
            debugPrint('Could not create category $categoryName: $e');
          }
        }

        try {
          await ApiService.createProduct({
            'name': product.name,
            'description': product.description,
            'category_id': categoryId,
            'price': product.price,
            'cost': product.cost,
            'stock': product.stock,
            'min_stock': product.minStock,
            'barcode': product.barcode,
            'color': product.color,
            'talla': product.talla,
          });
          if (mounted) setState(() { _migrationProgress++; _migrationSuccess++; });
        } catch (e) {
          debugPrint('Failed to migrate product ${product.name}: $e');
          if (mounted) setState(() => _migrationProgress++);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _migrationError = e.toString());
    } finally {
      if (mounted) setState(() { _migrating = false; _migrationDone = true; });
    }
  }

  Future<void> _exportProducts() async {
    try {
      final products = context.read<ProductProvider>().products;
      if (products.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay productos para exportar')),
        );
        return;
      }
      final path = await ExportService.exportProductsCSV(products);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exportado: $path')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _exportSales() async {
    try {
      final sales = context.read<SaleProvider>().sales;
      if (sales.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay ventas para exportar')),
        );
        return;
      }
      final path = await ExportService.exportSalesCSV(sales);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exportado: $path')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildConnectionSection(),
          const SizedBox(height: 16),
          _buildSyncSection(),
          const SizedBox(height: 16),
          _buildDataSection(),
          const SizedBox(height: 16),
          _buildExportSection(),
        ],
      ),
    );
  }

  Widget _buildConnectionSection() {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Conexión al servidor',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                _checkingConnection
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.circle, size: 14, color: _apiConnected ? Colors.green : Colors.red),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _checkingConnection
                        ? 'Verificando conexión…'
                        : _apiConnected
                            ? 'Conectado a confeccionesyaiza.es'
                            : 'Sin conexión con el servidor',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _checkApiConnection,
                  tooltip: 'Volver a comprobar',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncSection() {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sincronización',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              'Migra los productos almacenados en la base de datos local del dispositivo al servidor.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            if (_migrating) ...[
              LinearProgressIndicator(
                value: _migrationTotal > 0 ? _migrationProgress / _migrationTotal : null,
              ),
              const SizedBox(height: 8),
              Text(
                'Subiendo $_migrationProgress de $_migrationTotal productos…',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else if (_migrationDone) ...[
              if (_migrationError != null)
                _buildResultChip(Icons.error_outline, 'Error: $_migrationError', Colors.red)
              else
                _buildResultChip(
                  Icons.check_circle_outline,
                  '$_migrationSuccess de $_migrationTotal productos migrados correctamente.',
                  Colors.green,
                ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('Migrar datos locales al servidor'),
                onPressed: _migrating ? null : _migrateLocalData,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultChip(IconData icon, String message, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: TextStyle(color: color, fontSize: 13))),
      ],
    );
  }

  Widget _buildDataSection() {
    return Card(
      elevation: 1,
      child: Column(
        children: [
          // Dark mode toggle
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) => SwitchListTile(
              secondary: const Icon(Icons.dark_mode_outlined),
              title: const Text('Modo oscuro'),
              value: themeProvider.isDark,
              onChanged: (_) => themeProvider.toggle(),
            ),
          ),
          const Divider(height: 1, indent: 16),
          ListTile(
            leading: const Icon(Icons.label_outline),
            title: const Text('Categorías'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CategoriesScreen()),
            ),
          ),
          const Divider(height: 1, indent: 16),
          ListTile(
            leading: const Icon(Icons.place_outlined),
            title: const Text('Ubicaciones'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LocationsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportSection() {
    return Card(
      elevation: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('Exportar datos',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: const Text('Exportar productos CSV'),
            trailing: const Icon(Icons.download_outlined),
            onTap: _exportProducts,
          ),
          const Divider(height: 1, indent: 16),
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: const Text('Exportar ventas CSV'),
            trailing: const Icon(Icons.download_outlined),
            onTap: _exportSales,
          ),
        ],
      ),
    );
  }
}

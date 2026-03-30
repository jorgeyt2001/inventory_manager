import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../models/product.dart';
import '../../models/sale.dart';
import '../../providers/product_provider.dart';
import '../../providers/sale_provider.dart';
import '../../utils/formatters.dart';
import '../../utils/color_utils.dart';
import 'product_form_screen.dart';
import 'stock_adjustment_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late Product _product;
  bool _isGeneratingBarcode = false;

  @override
  void initState() {
    super.initState();
    _product = widget.product;
  }

  // ── Stats computed from sale history ─────────────────────────────────────────

  ({int unitsSold, double totalRevenue, List<({Sale sale, SaleItem item})> recentSales})
      _calcStats(SaleProvider saleProvider) {
    int units = 0;
    double revenue = 0;
    final recent = <({Sale sale, SaleItem item})>[];

    for (final sale in saleProvider.sales) {
      for (final item in sale.items) {
        if (item.productId == _product.id) {
          units += item.quantity;
          revenue += item.total;
          if (recent.length < 5) {
            recent.add((sale: sale, item: item));
          }
        }
      }
    }

    return (unitsSold: units, totalRevenue: revenue, recentSales: recent);
  }

  // ── Actions ──────────────────────────────────────────────────────────────────

  Future<void> _generateBarcode() async {
    setState(() => _isGeneratingBarcode = true);
    final newBarcode = const Uuid().v4().substring(0, 8).toUpperCase();
    try {
      final updated = _product.copyWith(barcode: newBarcode);
      await context.read<ProductProvider>().updateProduct(updated);
      if (mounted) {
        setState(() {
          _product = updated;
          _isGeneratingBarcode = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Código generado: $newBarcode'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isGeneratingBarcode = false);
    }
  }

  Future<void> _duplicateProduct() async {
    final provider = context.read<ProductProvider>();
    final duplicateName = 'Copia de ${_product.name}';

    await provider.addProduct(
      name: duplicateName,
      description: _product.description,
      categoryId: _product.categoryId,
      locationId: _product.locationId,
      price: _product.price,
      cost: _product.cost,
      stock: 0,
      minStock: _product.minStock,
      color: _product.color,
      talla: _product.talla,
    );

    final newProduct = provider.allProducts
        .where((p) => p.name == duplicateName)
        .lastOrNull;

    if (newProduct != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProductFormScreen(product: newProduct)),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Producto duplicado'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final saleProvider = context.watch<SaleProvider>();
    final stats = _calcStats(saleProvider);
    final hasMargin = _product.cost > 0 && _product.price > 0;
    final margin = hasMargin
        ? ((_product.price - _product.cost) / _product.price * 100)
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_product.name, overflow: TextOverflow.ellipsis),
        actions: [
          PopupMenuButton<String>(
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'edit',
                child: Row(children: [Icon(Icons.edit), SizedBox(width: 8), Text('Editar')]),
              ),
              PopupMenuItem(
                value: 'stock',
                child: Row(children: [Icon(Icons.tune), SizedBox(width: 8), Text('Ajustar stock')]),
              ),
              PopupMenuItem(
                value: 'duplicate',
                child: Row(children: [Icon(Icons.copy), SizedBox(width: 8), Text('Duplicar')]),
              ),
            ],
            onSelected: (value) {
              if (value == 'edit') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ProductFormScreen(product: _product)),
                );
              } else if (value == 'stock') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => StockAdjustmentScreen(product: _product)),
                );
              } else if (value == 'duplicate') {
                _duplicateProduct();
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── QR Code ───────────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (_product.barcode != null && _product.barcode!.isNotEmpty) ...[
                    QrImageView(
                      data: _product.barcode!,
                      version: QrVersions.auto,
                      size: 180,
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      _product.barcode!,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                    ),
                  ] else ...[
                    Icon(Icons.qr_code_2, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text('Sin código de barras', style: TextStyle(color: Colors.grey[600])),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _isGeneratingBarcode ? null : _generateBarcode,
                      icon: _isGeneratingBarcode
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add),
                      label: const Text('Generar código'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Información ───────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Información',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _infoRow('Categoría', _product.category),
                  if (_product.locationName != null)
                    _infoRow('Ubicación', _product.locationName!),
                  if (_product.description.isNotEmpty)
                    _infoRow('Descripción', _product.description),
                  if (_product.color != null)
                    _infoRowWidget(
                      'Color',
                      Row(
                        children: [
                          ColorUtils.colorDot(_product.color, size: 14),
                          Text(_product.color!),
                        ],
                      ),
                    ),
                  if (_product.talla != null)
                    _infoRow('Talla', _product.talla!),
                  _infoRow('Stock actual', '${_product.stock}'),
                  _infoRow('Stock mínimo', '${_product.minStock}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Precios & margen ──────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Precios',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _infoRow('Precio venta', AppFormatters.currency(_product.price)),
                  if (_product.cost > 0) ...[
                    _infoRow('Coste', AppFormatters.currency(_product.cost)),
                    _infoRow(
                        'Beneficio/ud', AppFormatters.currency(_product.price - _product.cost)),
                    _infoRowWidget('Margen', _buildMarginChip(margin)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Estadísticas ──────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estadísticas de ventas',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _statBox(
                          'Unidades vendidas',
                          '${stats.unitsSold}',
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _statBox(
                          'Total generado',
                          AppFormatters.currency(stats.totalRevenue),
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Últimas ventas ────────────────────────────────────────────────
          if (stats.recentSales.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Últimas ventas',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...stats.recentSales.map((rec) {
                      final sale = rec.sale;
                      final item = rec.item;
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.receipt_outlined, size: 20),
                        title: Text('${item.quantity}× — ${AppFormatters.currency(item.total)}'),
                        subtitle: Text(AppFormatters.dateTime(sale.createdAt)),
                        trailing: Text(
                          sale.paymentMethod,
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // ── Acciones ──────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ProductFormScreen(product: _product)),
                  ),
                  icon: const Icon(Icons.edit),
                  label: const Text('Editar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => StockAdjustmentScreen(product: _product)),
                  ),
                  icon: const Icon(Icons.tune),
                  label: const Text('Ajustar Stock'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _duplicateProduct,
              icon: const Icon(Icons.copy),
              label: const Text('Duplicar producto'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _infoRowWidget(String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ),
          value,
        ],
      ),
    );
  }

  Widget _buildMarginChip(double margin) {
    final color = margin >= 40
        ? Colors.green[700]!
        : margin >= 20
            ? Colors.amber[700]!
            : Colors.red[700]!;
    final bg = margin >= 40
        ? Colors.green[100]!
        : margin >= 20
            ? Colors.amber[100]!
            : Colors.red[100]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(
        '${margin.toStringAsFixed(1)}%',
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  Widget _statBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

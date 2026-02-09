import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/sale_provider.dart';
import '../../utils/formatters.dart';
import 'barcode_scanner_screen.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final _searchController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _barcodeFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    context.read<ProductProvider>().loadProducts();
    _barcodeFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _barcodeController.dispose();
    _barcodeFocusNode.dispose();
    super.dispose();
  }

  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  void _openCameraScanner() async {
    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (barcode != null && barcode.isNotEmpty && mounted) {
      _searchProductByBarcode(barcode.trim());
    }
  }

  void _searchProductByBarcode(String barcode) {
    final products = context.read<ProductProvider>().products;
    final product = products.where((p) => p.barcode == barcode).firstOrNull;

    if (product != null) {
      context.read<SaleProvider>().addToCart(product);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} agregado'),
          duration: const Duration(seconds: 1),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Producto no encontrado: $barcode'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
    }
    _barcodeFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva Venta'),
        actions: [
          Consumer<SaleProvider>(
            builder: (context, provider, _) {
              if (provider.cart.isEmpty) return const SizedBox.shrink();
              return TextButton.icon(
                onPressed: () => provider.clearCart(),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Limpiar'),
              );
            },
          ),
        ],
      ),
      floatingActionButton: _isMobile
          ? Consumer<SaleProvider>(
              builder: (context, provider, _) {
                return FloatingActionButton.extended(
                  onPressed: () => _showCartBottomSheet(),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.shopping_cart),
                  label: Text('${provider.cart.length} - ${AppFormatters.currency(provider.total)}'),
                );
              },
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (_isMobile)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: IconButton.filled(
                      onPressed: _openCameraScanner,
                      icon: const Icon(Icons.qr_code_scanner),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(48, 48),
                      ),
                    ),
                  ),
                if (!_isMobile)
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: _barcodeController,
                      focusNode: _barcodeFocusNode,
                      decoration: InputDecoration(
                        hintText: 'Escanear codigo...',
                        prefixIcon: const Icon(Icons.qr_code_scanner),
                        filled: true,
                        fillColor: Colors.green[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.green[300]!),
                        ),
                      ),
                      onSubmitted: (value) {
                        if (value.isNotEmpty) {
                          _searchProductByBarcode(value.trim());
                          _barcodeController.clear();
                        }
                        _barcodeFocusNode.requestFocus();
                      },
                    ),
                  ),
                if (!_isMobile) const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Buscar producto por nombre...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) {
                      context.read<ProductProvider>().setSearchQuery(value);
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isMobile
                ? _buildProductList()
                : Row(
                    children: [
                      Expanded(flex: 2, child: _buildProductList()),
                      Container(
                        width: 320,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          border: Border(left: BorderSide(color: Colors.grey[300]!)),
                        ),
                        child: _buildCart(),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductList() {
    return Consumer<ProductProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (provider.products.isEmpty) {
          return const Center(child: Text('No hay productos'));
        }
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _isMobile ? 2 : 3,
            childAspectRatio: 1.1,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: provider.products.length,
          itemBuilder: (context, index) {
            final product = provider.products[index];
            return Card(
              child: InkWell(
                onTap: product.stock > 0
                    ? () => context.read<SaleProvider>().addToCart(product)
                    : null,
                borderRadius: BorderRadius.circular(12),
                child: Opacity(
                  opacity: product.stock > 0 ? 1.0 : 0.5,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (product.barcode != null && product.barcode!.isNotEmpty)
                              Text(
                                product.barcode!,
                                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                              ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppFormatters.currency(product.price),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              'Stock: ${product.stock}',
                              style: TextStyle(
                                color: product.stock > 0 ? Colors.green : Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCart({ScrollController? scrollController}) {
    return Consumer<SaleProvider>(
      builder: (context, provider, _) {
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).primaryColor,
              child: Row(
                children: [
                  const Icon(Icons.shopping_cart, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'Carrito (${provider.cart.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: provider.cart.isEmpty
                  ? const Center(
                      child: Text(
                        'Carrito vacio\n\nEscanea un codigo de barras',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: provider.cart.length,
                      itemBuilder: (context, index) {
                        final item = provider.cart[index];
                        return ListTile(
                          title: Text(
                            item.product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(AppFormatters.currency(item.product.price)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () => provider.updateQuantity(
                                  item.product.id, item.quantity - 1,
                                ),
                              ),
                              Text('${item.quantity}'),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () => provider.updateQuantity(
                                  item.product.id, item.quantity + 1,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(25),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal:'),
                      Text(AppFormatters.currency(provider.subtotal)),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TOTAL:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      Text(AppFormatters.currency(provider.total),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: provider.cart.isEmpty ? null : _completeSale,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('COMPLETAR VENTA'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _showCartBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (sheetContext, scrollController) => _buildCart(scrollController: scrollController),
      ),
    );
  }

  void _completeSale() async {
    final provider = context.read<SaleProvider>();
    final productProvider = context.read<ProductProvider>();

    final sale = await provider.completeSale();

    if (sale != null && mounted) {
      await productProvider.loadProducts();
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Venta Completada'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total: ${AppFormatters.currency(sale.total)}'),
              Text('Productos: ${sale.items.length}'),
              Text('Fecha: ${AppFormatters.dateTime(sale.createdAt)}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _barcodeFocusNode.requestFocus();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }
}

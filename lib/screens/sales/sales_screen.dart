import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/sale_provider.dart';
import '../../models/sale.dart';
import '../../utils/formatters.dart';
import '../../utils/color_utils.dart';
import 'barcode_scanner_screen.dart';

class SalesScreen extends StatefulWidget {
  /// Optional callback invoked when a sale is successfully completed.
  /// Used by ReservationsScreen to auto-complete the linked reservation.
  final VoidCallback? onSaleCompleted;

  const SalesScreen({super.key, this.onSaleCompleted});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final _searchController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _barcodeFocusNode = FocusNode();
  final _searchFocusNode = FocusNode();
  final _discountController = TextEditingController();
  final _customerController = TextEditingController();
  final _notesController = TextEditingController();

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
    _searchFocusNode.dispose();
    _discountController.dispose();
    _customerController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  // ── Barcode / search ──────────────────────────────────────────────────────────

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${product.name} agregado'),
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.green,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Producto no encontrado: $barcode'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.red,
      ));
    }
    _barcodeFocusNode.requestFocus();
  }

  // ── Keyboard shortcuts ────────────────────────────────────────────────────────

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.escape) {
      _barcodeController.clear();
      _barcodeFocusNode.requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f1) {
      _barcodeFocusNode.requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f2) {
      _searchFocusNode.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ── Direct quantity dialog ────────────────────────────────────────────────────

  void _showQuantityDialog(SaleProvider provider, CartItem item) {
    final ctrl = TextEditingController(text: '${item.quantity}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Cantidad — ${item.product.name}',
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Cantidad (máx: ${item.product.stock})',
            prefixIcon: const Icon(Icons.numbers),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final qty = int.tryParse(ctrl.text);
              if (qty != null && qty >= 0 && qty <= item.product.stock) {
                provider.updateQuantity(item.product.id, qty);
                Navigator.pop(ctx);
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Nueva Venta'),
          actions: [
            Consumer<SaleProvider>(
              builder: (context, provider, _) {
                if (provider.cart.isEmpty) return const SizedBox.shrink();
                return TextButton.icon(
                  onPressed: () {
                    provider.clearCart();
                    _discountController.clear();
                    _customerController.clear();
                    _notesController.clear();
                  },
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
                    label: Text(
                        '${provider.cart.length} - ${AppFormatters.currency(provider.total)}'),
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
                          hintText: 'Escanear codigo... (F1)',
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
                      focusNode: _searchFocusNode,
                      decoration: const InputDecoration(
                        hintText: 'Buscar producto... (F2)',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) {
                        context.read<ProductProvider>().setSearchQuery(value);
                      },
                      onSubmitted: (_) {
                        // If exactly 1 product in list, add it to cart
                        final products =
                            context.read<ProductProvider>().products;
                        if (products.length == 1 && products.first.stock > 0) {
                          context
                              .read<SaleProvider>()
                              .addToCart(products.first);
                          _searchController.clear();
                          context
                              .read<ProductProvider>()
                              .setSearchQuery('');
                          _barcodeFocusNode.requestFocus();
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('${products.first.name} agregado'),
                            duration: const Duration(seconds: 1),
                            backgroundColor: Colors.green,
                          ));
                        }
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
                          width: 340,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            border: Border(
                              left: BorderSide(
                                  color: Theme.of(context).dividerColor),
                            ),
                          ),
                          child: _buildCart(),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Product list ──────────────────────────────────────────────────────────────

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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (product.color != null || product.talla != null)
                              Row(
                                children: [
                                  if (product.color != null) ...[
                                    ColorUtils.colorDot(product.color, size: 10),
                                    Flexible(
                                      child: Text(
                                        '${product.color!} ',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.purple[400]),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                  if (product.talla != null)
                                    Text('T.${product.talla!}',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.indigo[400])),
                                ],
                              ),
                            if (product.barcode != null &&
                                product.barcode!.isNotEmpty)
                              Text(
                                product.barcode!,
                                style: TextStyle(
                                    fontSize: 10, color: Colors.grey[500]),
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
                                color: product.stock > 0
                                    ? Colors.green
                                    : Colors.red,
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

  // ── Cart ──────────────────────────────────────────────────────────────────────

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
                        'Carrito vacío\n\nEscanea un código de barras',
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
                          subtitle:
                              Text(AppFormatters.currency(item.product.price)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () => provider.updateQuantity(
                                    item.product.id, item.quantity - 1),
                              ),
                              // Tappable quantity for direct input
                              GestureDetector(
                                onTap: () => _showQuantityDialog(provider, item),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey[300]!),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${item.quantity}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () => provider.updateQuantity(
                                    item.product.id, item.quantity + 1),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            // ── Bottom totals + fields ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(25),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal:'),
                      Text(AppFormatters.currency(provider.subtotal)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _discountController,
                    decoration: const InputDecoration(
                      labelText: 'Descuento',
                      prefixText: '€ ',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) {
                      provider.setDiscount(double.tryParse(value) ?? 0);
                    },
                  ),
                  if (provider.discount > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Descuento:',
                            style: TextStyle(color: Colors.red[700])),
                        Text(
                            '-${AppFormatters.currency(provider.discount)}',
                            style: TextStyle(color: Colors.red[700])),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextField(
                    controller: _customerController,
                    decoration: const InputDecoration(
                      labelText: 'Cliente (opcional)',
                      prefixIcon: Icon(Icons.person_outline, size: 18),
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    onChanged: (value) => provider.setCustomerName(value),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notas (opcional)',
                      prefixIcon: Icon(Icons.notes_outlined, size: 18),
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    onChanged: (value) => provider.setNotes(value),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: provider.paymentMethod,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: 'Método de pago',
                      prefixIcon: Icon(Icons.payment_outlined, size: 18),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'Efectivo', child: Text('Efectivo')),
                      DropdownMenuItem(
                          value: 'Tarjeta', child: Text('Tarjeta')),
                      DropdownMenuItem(
                          value: 'Bizum', child: Text('Bizum')),
                      DropdownMenuItem(
                          value: 'Transferencia',
                          child: Text('Transferencia')),
                    ],
                    onChanged: (value) {
                      if (value != null) provider.setPaymentMethod(value);
                    },
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TOTAL:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18)),
                      Text(AppFormatters.currency(provider.total),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          provider.cart.isEmpty ? null : _completeSale,
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
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (sheetContext, scrollController) =>
            _buildCart(scrollController: scrollController),
      ),
    );
  }

  // ── Complete sale ─────────────────────────────────────────────────────────────

  void _completeSale() async {
    final provider = context.read<SaleProvider>();
    final productProvider = context.read<ProductProvider>();

    final sale = await provider.completeSale();
    await productProvider.loadProducts();

    if (sale != null && mounted) {
      // Notify caller (e.g. ReservationsScreen) that a sale was completed
      widget.onSaleCompleted?.call();

      _discountController.clear();
      _customerController.clear();
      _notesController.clear();

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
              Text('Pago: ${sale.paymentMethod}'),
              if (sale.customerName != null)
                Text('Cliente: ${sale.customerName}'),
              Text('Fecha: ${AppFormatters.dateTime(sale.createdAt)}'),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                final receipt = _buildReceiptText(sale);
                Clipboard.setData(ClipboardData(text: receipt));
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Recibo copiado al portapapeles'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copiar recibo'),
            ),
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

  String _buildReceiptText(Sale sale) {
    final sb = StringBuffer();
    sb.writeln('🧾 RECIBO - Selene Lencería');
    sb.writeln('📅 ${AppFormatters.dateTime(sale.createdAt)}');
    sb.writeln('─────────────────');
    for (final item in sale.items) {
      sb.writeln(
          '${item.quantity}x ${item.productName} = ${AppFormatters.currency(item.total)}');
    }
    sb.writeln('─────────────────');
    sb.writeln('Subtotal: ${AppFormatters.currency(sale.subtotal)}');
    if (sale.discount > 0) {
      sb.writeln('Descuento: -${AppFormatters.currency(sale.discount)}');
    }
    sb.writeln('TOTAL: ${AppFormatters.currency(sale.total)}');
    sb.writeln('💳 ${sale.paymentMethod}');
    if (sale.customerName != null) sb.writeln('👤 ${sale.customerName}');
    if (sale.notes != null) sb.writeln('📝 ${sale.notes}');
    return sb.toString();
  }
}

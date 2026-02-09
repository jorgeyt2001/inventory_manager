import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/database_service.dart';
import '../../providers/return_provider.dart';
import '../../providers/sale_provider.dart';
import '../../utils/formatters.dart';
import '../sales/barcode_scanner_screen.dart';

class ReturnsScreen extends StatefulWidget {
  const ReturnsScreen({super.key});

  @override
  State<ReturnsScreen> createState() => _ReturnsScreenState();
}

class _ReturnsScreenState extends State<ReturnsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ReturnProvider>().loadReturns();
    context.read<SaleProvider>().loadSales();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Devoluciones')),
      body: Consumer<ReturnProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.returns.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_return, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No hay devoluciones', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.returns.length,
            itemBuilder: (context, index) {
              final returnItem = provider.returns[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange[100],
                    child: const Icon(Icons.assignment_return, color: Colors.orange),
                  ),
                  title: Text(returnItem.productName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cantidad: ${returnItem.quantity}'),
                      Text('Razon: ${returnItem.reason}'),
                      Text(AppFormatters.dateTime(returnItem.createdAt)),
                    ],
                  ),
                  trailing: Text(
                    AppFormatters.currency(returnItem.amount),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showReturnOptions(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showReturnOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Crear Devolucion',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.qr_code, color: Colors.green),
              title: const Text('Buscar por EAN / Codigo de barras'),
              subtitle: const Text('Escanear o escribir el codigo'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showEanSearch(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long, color: Colors.blue),
              title: const Text('Seleccionar desde ventas'),
              subtitle: const Text('Buscar en el historial de ventas'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showCreateReturnDialog(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showEanSearch(BuildContext context) {
    final eanController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Buscar por EAN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: eanController,
                    decoration: const InputDecoration(
                      labelText: 'Codigo de barras',
                      prefixIcon: Icon(Icons.qr_code),
                    ),
                    autofocus: true,
                  ),
                ),
                if (Platform.isAndroid || Platform.isIOS)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: IconButton.filled(
                      onPressed: () async {
                        final barcode = await Navigator.push<String>(
                          dialogContext,
                          MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
                        );
                        if (barcode != null && barcode.isNotEmpty) {
                          eanController.text = barcode.trim();
                        }
                      },
                      icon: const Icon(Icons.qr_code_scanner),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final barcode = eanController.text.trim();
              if (barcode.isEmpty) return;

              final navigator = Navigator.of(dialogContext);
              final allSales = context.read<SaleProvider>().sales;
              final product = await DatabaseService.instance.getProductByBarcode(barcode);

              if (product == null) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Producto no encontrado con ese codigo')),
                );
                return;
              }

              // Find sales containing this product
              final salesWithProduct = allSales.where((sale) =>
                sale.items.any((item) => item.productId == product.id)
              ).toList();

              if (salesWithProduct.isEmpty) {
                messenger.showSnackBar(
                  SnackBar(content: Text('No hay ventas del producto "${product.name}"')),
                );
                return;
              }

              navigator.pop();
              // Use the most recent sale and auto-select the product item
              final sale = salesWithProduct.first;
              final saleItem = sale.items.firstWhere((item) => item.productId == product.id);
              _showReturnFormForProduct(sale, saleItem);
            },
            child: const Text('Buscar'),
          ),
        ],
      ),
    );
  }

  void _showReturnFormForProduct(dynamic sale, dynamic saleItem) {
    final reasonController = TextEditingController();
    final quantityController = TextEditingController(text: '1');
    final returnProvider = context.read<ReturnProvider>();
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Crear Devolucion'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.inventory_2, color: Colors.blue),
                title: Text(saleItem.productName),
                subtitle: Text('Precio: ${AppFormatters.currency(saleItem.unitPrice)}'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: quantityController,
                decoration: const InputDecoration(labelText: 'Cantidad'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: reasonController,
                decoration: const InputDecoration(labelText: 'Razon'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(dialogContext);
              final quantity = int.tryParse(quantityController.text) ?? 1;
              final amount = saleItem.unitPrice * quantity;

              await returnProvider.createReturn(
                saleId: sale.id,
                productId: saleItem.productId,
                productName: saleItem.productName,
                quantity: quantity,
                amount: amount,
                reason: reasonController.text.isEmpty ? 'No especificado' : reasonController.text,
              );

              navigator.pop();
              messenger.showSnackBar(
                const SnackBar(content: Text('Devolucion creada')),
              );
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  void _showCreateReturnDialog(BuildContext context) {
    final sales = context.read<SaleProvider>().sales;
    if (sales.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay ventas para devolver')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: const Text('Selecciona una venta',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: sales.length,
                itemBuilder: (_, index) {
                  final sale = sales[index];
                  return ListTile(
                    title: Text(AppFormatters.currency(sale.total)),
                    subtitle: Text(AppFormatters.dateTime(sale.createdAt)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _selectProductForReturn(sale);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectProductForReturn(dynamic sale) {
    final reasonController = TextEditingController();
    final quantityController = TextEditingController(text: '1');
    dynamic selectedItem = sale.items.first;
    final returnProvider = context.read<ReturnProvider>();
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('Crear Devolucion'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<dynamic>(
                  initialValue: selectedItem,
                  decoration: const InputDecoration(labelText: 'Producto'),
                  items: sale.items.map<DropdownMenuItem<dynamic>>((item) {
                    return DropdownMenuItem<dynamic>(
                      value: item,
                      child: Text('${item.productName} (${item.quantity})'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => selectedItem = value);
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: quantityController,
                  decoration: const InputDecoration(labelText: 'Cantidad'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: reasonController,
                  decoration: const InputDecoration(labelText: 'Razon'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final navigator = Navigator.of(dialogContext);
                final quantity = int.tryParse(quantityController.text) ?? 1;
                final amount = selectedItem.unitPrice * quantity;

                await returnProvider.createReturn(
                  saleId: sale.id,
                  productId: selectedItem.productId,
                  productName: selectedItem.productName,
                  quantity: quantity,
                  amount: amount,
                  reason: reasonController.text.isEmpty ? 'No especificado' : reasonController.text,
                );

                navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Devolucion creada')),
                );
              },
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/return_provider.dart';
import '../../providers/sale_provider.dart';
import '../../utils/formatters.dart';

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
        onPressed: () => _showCreateReturnDialog(context),
        child: const Icon(Icons.add),
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

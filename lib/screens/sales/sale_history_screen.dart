import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/sale.dart';
import '../../providers/sale_provider.dart';
import '../../utils/formatters.dart';

class SaleHistoryScreen extends StatefulWidget {
  const SaleHistoryScreen({super.key});

  @override
  State<SaleHistoryScreen> createState() => _SaleHistoryScreenState();
}

class _SaleHistoryScreenState extends State<SaleHistoryScreen> {
  DateTimeRange? _dateRange;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    context.read<SaleProvider>().loadSales();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Sale> _filteredSales(List<Sale> all) {
    var list = all;

    if (_dateRange != null) {
      final start = _dateRange!.start;
      final end = _dateRange!.end.add(const Duration(days: 1));
      list = list.where((s) => s.createdAt.isAfter(start) && s.createdAt.isBefore(end)).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((s) {
        final inProducts = s.items.any((i) => i.productName.toLowerCase().contains(q));
        final inCustomer = s.customerName?.toLowerCase().contains(q) ?? false;
        return inProducts || inCustomer;
      }).toList();
    }

    return list;
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: _dateRange,
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Ventas'),
        actions: [
          IconButton(
            icon: Icon(
              Icons.date_range,
              color: _dateRange != null ? Theme.of(context).colorScheme.primary : null,
            ),
            tooltip: 'Filtrar por fechas',
            onPressed: _pickDateRange,
          ),
          if (_dateRange != null)
            IconButton(
              icon: const Icon(Icons.filter_alt_off),
              tooltip: 'Limpiar filtro de fechas',
              onPressed: () => setState(() => _dateRange = null),
            ),
        ],
      ),
      body: Consumer<SaleProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.sales.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No hay ventas registradas',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          final filtered = _filteredSales(provider.sales);
          final totalAmount = filtered.fold<double>(0, (sum, s) => sum + s.total);
          final avgTicket = filtered.isEmpty ? 0.0 : totalAmount / filtered.length;

          return Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar por producto o cliente...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
              // Date range indicator
              if (_dateRange != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: Row(
                    children: [
                      Icon(Icons.date_range, size: 16, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        '${AppFormatters.date(_dateRange!.start)} — ${AppFormatters.date(_dateRange!.end)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              // Totals card
              if (filtered.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Card(
                    elevation: 1,
                    color: Theme.of(context).colorScheme.primaryContainer.withAlpha(60),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _totalChip('Total período', AppFormatters.currency(totalAmount), Colors.green),
                          _totalChip('Transacciones', '${filtered.length}', Colors.blue),
                          _totalChip('Ticket medio', AppFormatters.currency(avgTicket), Colors.purple),
                        ],
                      ),
                    ),
                  ),
                ),
              // Sales list
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No hay ventas en el período seleccionado',
                          style: TextStyle(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final sale = filtered[index];
                          return _buildSaleCard(sale);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _totalChip(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 15,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildSaleCard(Sale sale) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green[100],
          child: const Icon(Icons.receipt, color: Colors.green),
        ),
        title: Text(AppFormatters.currency(sale.total)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppFormatters.dateTime(sale.createdAt)),
            if (sale.customerName != null)
              Text('👤 ${sale.customerName!}', style: const TextStyle(fontSize: 12)),
          ],
        ),
        trailing: Chip(
          label: Text(sale.paymentMethod),
          backgroundColor: Colors.blue[50],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Productos:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...sale.items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${item.quantity}x ${item.productName}'),
                      Text(AppFormatters.currency(item.total)),
                    ],
                  ),
                )),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal:'),
                    Text(AppFormatters.currency(sale.subtotal)),
                  ],
                ),
                if (sale.discount > 0)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Descuento:'),
                      Text('-${AppFormatters.currency(sale.discount)}'),
                    ],
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(AppFormatters.currency(sale.total),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                if (sale.notes != null) ...[
                  const SizedBox(height: 6),
                  Text('📝 ${sale.notes}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

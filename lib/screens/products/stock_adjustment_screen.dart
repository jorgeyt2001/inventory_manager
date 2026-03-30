import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../providers/product_provider.dart';
import '../../utils/formatters.dart';

class StockAdjustmentScreen extends StatefulWidget {
  final Product product;

  const StockAdjustmentScreen({super.key, required this.product});

  @override
  State<StockAdjustmentScreen> createState() => _StockAdjustmentScreenState();
}

class _StockAdjustmentScreenState extends State<StockAdjustmentScreen> {
  final _quantityController = TextEditingController(text: '1');
  final _absoluteController = TextEditingController();
  String _mode = 'entrada'; // 'entrada', 'salida', 'manual'
  String _reason = 'Compra proveedor';
  bool _isSaving = false;

  static const _reasons = [
    'Compra proveedor',
    'Devolución',
    'Ajuste',
    'Pérdida',
    'Inventario',
    'Otro',
  ];

  @override
  void dispose() {
    _quantityController.dispose();
    _absoluteController.dispose();
    super.dispose();
  }

  int get _currentStock => widget.product.stock;

  int get _newStock {
    if (_mode == 'manual') {
      return int.tryParse(_absoluteController.text) ?? _currentStock;
    }
    final qty = int.tryParse(_quantityController.text) ?? 0;
    if (_mode == 'entrada') return _currentStock + qty;
    return (_currentStock - qty).clamp(0, 999999);
  }

  int get _delta => _newStock - _currentStock;

  Future<void> _confirm() async {
    final delta = _delta;
    if (delta == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay cambios en el stock')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await context.read<ProductProvider>().updateStock(widget.product.id, delta);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Stock actualizado: ${widget.product.stock} → $_newStock'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustar Stock')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Product info card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  if (product.color != null || product.talla != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          if (product.color != null)
                            Chip(
                              label: Text(product.color!),
                              backgroundColor: Colors.purple[50],
                              labelStyle: TextStyle(color: Colors.purple[700], fontSize: 12),
                              visualDensity: VisualDensity.compact,
                            ),
                          if (product.talla != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Chip(
                                label: Text('Talla ${product.talla!}'),
                                backgroundColor: Colors.indigo[50],
                                labelStyle: TextStyle(color: Colors.indigo[700], fontSize: 12),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _infoChip('Stock actual', '${product.stock}', Colors.blue),
                      const SizedBox(width: 12),
                      _infoChip('Stock mínimo', '${product.minStock}', Colors.orange),
                      const SizedBox(width: 12),
                      _infoChip('Precio', AppFormatters.currency(product.price), Colors.green),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Mode selection
          Row(
            children: [
              Expanded(
                child: _ModeButton(
                  label: 'Entrada',
                  icon: Icons.add_circle_outline,
                  color: Colors.green,
                  selected: _mode == 'entrada',
                  onTap: () => setState(() => _mode = 'entrada'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ModeButton(
                  label: 'Salida',
                  icon: Icons.remove_circle_outline,
                  color: Colors.red,
                  selected: _mode == 'salida',
                  onTap: () => setState(() => _mode = 'salida'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ModeButton(
                  label: 'Manual',
                  icon: Icons.edit_outlined,
                  color: Colors.purple,
                  selected: _mode == 'manual',
                  onTap: () => setState(() => _mode = 'manual'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Quantity / absolute input
          if (_mode == 'manual')
            TextFormField(
              controller: _absoluteController,
              decoration: const InputDecoration(
                labelText: 'Stock absoluto',
                prefixIcon: Icon(Icons.inventory),
                hintText: 'Introduce el nuevo stock total',
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            )
          else
            TextFormField(
              controller: _quantityController,
              decoration: InputDecoration(
                labelText: _mode == 'entrada' ? 'Cantidad a añadir' : 'Cantidad a retirar',
                prefixIcon: Icon(_mode == 'entrada' ? Icons.add : Icons.remove),
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),
          const SizedBox(height: 16),
          // Reason dropdown
          DropdownButtonFormField<String>(
            value: _reason,
            decoration: const InputDecoration(
              labelText: 'Motivo',
              prefixIcon: Icon(Icons.assignment_outlined),
            ),
            items: _reasons
                .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _reason = v);
            },
          ),
          const SizedBox(height: 24),
          // Preview
          Card(
            color: Theme.of(context).colorScheme.primaryContainer.withAlpha(80),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text('Actual', style: Theme.of(context).textTheme.bodySmall),
                      Text('$_currentStock',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Icon(
                    _delta > 0 ? Icons.arrow_forward : Icons.arrow_forward,
                    size: 28,
                    color: _delta > 0 ? Colors.green : _delta < 0 ? Colors.red : Colors.grey,
                  ),
                  Column(
                    children: [
                      Text('Nuevo', style: Theme.of(context).textTheme.bodySmall),
                      Text(
                        '$_newStock',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _delta > 0
                                  ? Colors.green
                                  : _delta < 0
                                      ? Colors.red
                                      : null,
                            ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text('Diferencia', style: Theme.of(context).textTheme.bodySmall),
                      Text(
                        '${_delta >= 0 ? '+' : ''}$_delta',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _delta > 0
                                  ? Colors.green
                                  : _delta < 0
                                      ? Colors.red
                                      : Colors.grey,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isSaving ? null : _confirm,
              icon: _isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check),
              label: const Text('Confirmar ajuste'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? color.withAlpha(40) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : Colors.grey.withAlpha(80),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? color : Colors.grey, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? color : Colors.grey,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

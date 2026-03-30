import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/product.dart';
import '../../models/category.dart';
import '../../models/location.dart';
import '../../providers/product_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/location_provider.dart';
import '../../services/api_service.dart';
import '../../services/barcode_server_service.dart';
import '../sales/barcode_scanner_screen.dart';

class ProductFormScreen extends StatefulWidget {
  final Product? product;

  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _costController;
  late TextEditingController _stockController;
  late TextEditingController _minStockController;
  late TextEditingController _barcodeController;
  String? _selectedColor;
  String? _selectedTalla;
  int? _selectedCategoryId;
  int? _selectedLocationId;
  Timer? _barcodeDebounce;

  bool get isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _descriptionController = TextEditingController(text: widget.product?.description ?? '');
    _priceController = TextEditingController(text: widget.product?.price.toString() ?? '');
    _costController = TextEditingController(text: widget.product?.cost.toString() ?? '0');
    _stockController = TextEditingController(text: widget.product?.stock.toString() ?? '0');
    _minStockController = TextEditingController(text: widget.product?.minStock.toString() ?? '5');
    _barcodeController = TextEditingController(text: widget.product?.barcode ?? '');
    _selectedColor = widget.product?.color;
    _selectedTalla = widget.product?.talla;
    _selectedCategoryId = widget.product?.categoryId;
    _selectedLocationId = widget.product?.locationId;

    _barcodeController.addListener(_onBarcodeChanged);

    // Load categories and locations if not loaded yet
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CategoryProvider>().loadCategories();
      context.read<LocationProvider>().loadLocations();
    });
  }

  @override
  void dispose() {
    _barcodeDebounce?.cancel();
    _barcodeController.removeListener(_onBarcodeChanged);
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  // ── Auto-fill on barcode change ──────────────────────────────────────────────

  void _onBarcodeChanged() {
    _barcodeDebounce?.cancel();
    final barcode = _barcodeController.text.trim();
    if (barcode.length >= 4) {
      _barcodeDebounce = Timer(const Duration(milliseconds: 600), () {
        _autoFillFromBarcode(barcode);
      });
    }
  }

  Future<void> _autoFillFromBarcode(String barcode) async {
    final data = await ApiService.getProductByBarcode(barcode);
    if (data != null && mounted) {
      setState(() {
        _nameController.text = data['name'] ?? '';
        _descriptionController.text = data['description'] ?? '';
        _priceController.text = (data['price'] ?? 0).toString();
        _costController.text = (data['cost'] ?? 0).toString();
        _selectedColor = data['color'];
        _selectedTalla = data['talla'];
        _selectedCategoryId = data['category_id'];
        _selectedLocationId = data['location_id'];
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Producto encontrado: ${data['name']}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // Not in own API — try external barcode databases
    final external = await ApiService.lookupExternalBarcode(barcode);
    if (external != null && mounted) {
      setState(() {
        _nameController.text = external['name'] ?? '';
        if ((external['description'] ?? '').isNotEmpty) {
          _descriptionController.text = external['description']!;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Producto encontrado en base de datos externa: ${external['name']}'),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // ── Scanner (nativo en móvil, web companion en desktop) ─────────────────────

  bool get _isMobile =>
      !const bool.fromEnvironment('dart.library.html') &&
      (Platform.isIOS || Platform.isAndroid);

  void _scanBarcode() async {
    String? scannedBarcode;

    if (_isMobile) {
      // iOS / Android → cámara nativa
      scannedBarcode = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
      );
    } else {
      // Desktop → servidor web + QR
      final service = BarcodeServerService.instance;
      final url = service.serverUrl;

      if (url == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Servidor no disponible. Verifica la conexión WiFi.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => _WebScannerDialog(
          url: url,
          onBarcodeReceived: (barcode) {
            scannedBarcode = barcode;
            Navigator.of(dialogContext).pop();
          },
        ),
      );
    }

    if (scannedBarcode != null && scannedBarcode!.isNotEmpty && mounted) {
      _barcodeController.removeListener(_onBarcodeChanged);
      setState(() => _barcodeController.text = scannedBarcode!);
      _barcodeController.addListener(_onBarcodeChanged);
      _autoFillFromBarcode(scannedBarcode!);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Producto' : 'Nuevo Producto'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre *',
                prefixIcon: Icon(Icons.inventory_2),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'El nombre es requerido';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descripcion',
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            // ── Category dropdown ──────────────────────────────────────────
            Consumer<CategoryProvider>(
              builder: (context, catProvider, _) {
                return DropdownButtonFormField<int>(
                  value: _selectedCategoryId,
                  decoration: const InputDecoration(
                    labelText: 'Categoria',
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: [
                    const DropdownMenuItem<int>(value: null, child: Text('Sin categoria')),
                    ...catProvider.categories.map<DropdownMenuItem<int>>((AppCategory cat) =>
                      DropdownMenuItem<int>(value: cat.id, child: Text(cat.name)),
                    ),
                  ],
                  onChanged: (value) => setState(() => _selectedCategoryId = value),
                );
              },
            ),
            const SizedBox(height: 16),
            // ── Location dropdown ──────────────────────────────────────────
            Consumer<LocationProvider>(
              builder: (context, locProvider, _) {
                return DropdownButtonFormField<int>(
                  value: _selectedLocationId,
                  decoration: const InputDecoration(
                    labelText: 'Ubicacion',
                    prefixIcon: Icon(Icons.place),
                  ),
                  items: [
                    const DropdownMenuItem<int>(value: null, child: Text('Sin ubicacion')),
                    ...locProvider.locations.map<DropdownMenuItem<int>>((AppLocation loc) =>
                      DropdownMenuItem<int>(value: loc.id, child: Text(loc.name)),
                    ),
                  ],
                  onChanged: (value) => setState(() => _selectedLocationId = value),
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    decoration: const InputDecoration(
                      labelText: 'Precio *',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Requerido';
                      if (double.tryParse(value) == null) return 'Numero invalido';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _costController,
                    decoration: const InputDecoration(
                      labelText: 'Costo',
                      prefixIcon: Icon(Icons.money_off),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            Builder(builder: (context) {
              final price = double.tryParse(_priceController.text) ?? 0;
              final cost = double.tryParse(_costController.text) ?? 0;
              if (price <= 0 || cost <= 0) return const SizedBox.shrink();
              final margin = (price - cost) / price * 100;
              final color = margin >= 40 ? Colors.green : margin >= 20 ? Colors.amber[700]! : Colors.red;
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Icon(Icons.trending_up, size: 16, color: color),
                    const SizedBox(width: 4),
                    Text(
                      'Margen: ${margin.toStringAsFixed(1)}%',
                      style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(beneficio ${(price - cost).toStringAsFixed(2)} € por unidad)',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedColor,
                    decoration: const InputDecoration(
                      labelText: 'Color',
                      prefixIcon: Icon(Icons.palette),
                    ),
                    items: [
                      const DropdownMenuItem<String>(value: null, child: Text('Sin color')),
                      ...Product.coloresSelene.map((color) =>
                        DropdownMenuItem(value: color, child: Text(color)),
                      ),
                    ],
                    onChanged: (value) => setState(() => _selectedColor = value),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedTalla,
                    decoration: const InputDecoration(
                      labelText: 'Talla',
                      prefixIcon: Icon(Icons.straighten),
                    ),
                    items: [
                      const DropdownMenuItem<String>(value: null, child: Text('Sin talla')),
                      ...Product.tallasSelene.map((talla) =>
                        DropdownMenuItem(value: talla, child: Text(talla)),
                      ),
                    ],
                    onChanged: (value) => setState(() => _selectedTalla = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _stockController,
                    decoration: const InputDecoration(
                      labelText: 'Stock',
                      prefixIcon: Icon(Icons.inventory),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _minStockController,
                    decoration: const InputDecoration(
                      labelText: 'Stock Minimo',
                      prefixIcon: Icon(Icons.warning),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _barcodeController,
                    decoration: const InputDecoration(
                      labelText: 'Codigo de Barras',
                      prefixIcon: Icon(Icons.qr_code),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: IconButton.filled(
                    onPressed: _scanBarcode,
                    icon: const Icon(Icons.qr_code_scanner),
                    tooltip: 'Escanear con iPhone',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(48, 48),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saveProduct,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(isEditing ? 'Actualizar' : 'Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<ProductProvider>();

    if (isEditing) {
      final updated = widget.product!.copyWith(
        name: _nameController.text,
        description: _descriptionController.text,
        categoryId: _selectedCategoryId,
        locationId: _selectedLocationId,
        price: double.tryParse(_priceController.text) ?? 0,
        cost: double.tryParse(_costController.text) ?? 0,
        stock: int.tryParse(_stockController.text) ?? 0,
        minStock: int.tryParse(_minStockController.text) ?? 5,
        barcode: _barcodeController.text.isEmpty ? null : _barcodeController.text,
        color: _selectedColor,
        talla: _selectedTalla,
      );
      await provider.updateProduct(updated);
    } else {
      await provider.addProduct(
        name: _nameController.text,
        description: _descriptionController.text,
        categoryId: _selectedCategoryId,
        locationId: _selectedLocationId,
        price: double.tryParse(_priceController.text) ?? 0,
        cost: double.tryParse(_costController.text) ?? 0,
        stock: int.tryParse(_stockController.text) ?? 0,
        minStock: int.tryParse(_minStockController.text) ?? 5,
        barcode: _barcodeController.text.isEmpty ? null : _barcodeController.text,
        color: _selectedColor,
        talla: _selectedTalla,
      );
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEditing ? 'Producto actualizado' : 'Producto creado')),
      );
    }
  }
}

// ── Web Scanner Dialog ─────────────────────────────────────────────────────────

class _WebScannerDialog extends StatefulWidget {
  final String url;
  final void Function(String barcode) onBarcodeReceived;

  const _WebScannerDialog({required this.url, required this.onBarcodeReceived});

  @override
  State<_WebScannerDialog> createState() => _WebScannerDialogState();
}

class _WebScannerDialogState extends State<_WebScannerDialog> {
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = BarcodeServerService.instance.barcodeStream.listen((barcode) {
      if (mounted) widget.onBarcodeReceived(barcode);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.qr_code_scanner, color: Colors.green),
          SizedBox(width: 8),
          Text('Escanear desde iPhone'),
        ],
      ),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Abre esta URL en Safari de tu iPhone:',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            SelectableText(
              widget.url,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue,
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: QrImageView(
                data: widget.url,
                version: QrVersions.auto,
                size: 180,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text(
                  'Esperando escaneo...',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}

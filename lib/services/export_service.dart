import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../utils/formatters.dart';

class ExportService {
  static String _escapeCsv(String? value) {
    if (value == null) return '';
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  static Future<String> exportSalesCSV(List<Sale> sales) async {
    final sb = StringBuffer();
    // Header
    sb.writeln('Fecha,Cliente,Productos,Subtotal,Descuento,Total,Método de pago,Notas');

    for (final sale in sales) {
      final products = sale.items
          .map((i) => '${i.quantity}x ${i.productName}')
          .join(' | ');

      sb.writeln([
        _escapeCsv(AppFormatters.dateTime(sale.createdAt)),
        _escapeCsv(sale.customerName),
        _escapeCsv(products),
        sale.subtotal.toStringAsFixed(2),
        sale.discount.toStringAsFixed(2),
        sale.total.toStringAsFixed(2),
        _escapeCsv(sale.paymentMethod),
        _escapeCsv(sale.notes),
      ].join(','));
    }

    return _saveFile('ventas_${_timestamp()}.csv', sb.toString());
  }

  static Future<String> exportProductsCSV(List<Product> products) async {
    final sb = StringBuffer();
    // Header
    sb.writeln('Nombre,Categoría,Código de barras,Color,Talla,Precio,Coste,Stock,Stock mínimo,Margen %');

    for (final p in products) {
      final margin = (p.price > 0 && p.cost > 0)
          ? ((p.price - p.cost) / p.price * 100).toStringAsFixed(1)
          : '';

      sb.writeln([
        _escapeCsv(p.name),
        _escapeCsv(p.category),
        _escapeCsv(p.barcode),
        _escapeCsv(p.color),
        _escapeCsv(p.talla),
        p.price.toStringAsFixed(2),
        p.cost.toStringAsFixed(2),
        '${p.stock}',
        '${p.minStock}',
        margin,
      ].join(','));
    }

    return _saveFile('productos_${_timestamp()}.csv', sb.toString());
  }

  static String _timestamp() {
    final now = DateTime.now();
    return '${now.year}${_pad(now.month)}${_pad(now.day)}_${_pad(now.hour)}${_pad(now.minute)}';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');

  static Future<String> _saveFile(String filename, String content) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(content, flush: true);
    return file.path;
  }
}

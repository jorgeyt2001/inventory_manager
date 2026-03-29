import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://confeccionesyaiza.es/api';

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  // ── Generic helpers ────────────────────────────────────────────────────────

  static Future<dynamic> _get(String path) async {
    final res = await http.get(Uri.parse('$baseUrl$path'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('GET $path failed: ${res.statusCode}');
  }

  static Future<bool> checkConnection() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/health'), headers: _headers)
          .timeout(const Duration(seconds: 8));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (res.statusCode == 200 || res.statusCode == 201) return jsonDecode(res.body);
    throw Exception('POST $path failed: ${res.statusCode} ${res.body}');
  }

  static Future<dynamic> _put(String path, Map<String, dynamic> body) async {
    final res = await http.put(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('PUT $path failed: ${res.statusCode} ${res.body}');
  }

  static Future<void> _delete(String path) async {
    final res = await http.delete(Uri.parse('$baseUrl$path'), headers: _headers);
    if (res.statusCode != 204 && res.statusCode != 200) {
      throw Exception('DELETE $path failed: ${res.statusCode}');
    }
  }

  // ── Categories ─────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getCategories() async => await _get('/categories');
  static Future<dynamic> createCategory(String name, {String description = ''}) async =>
      _post('/categories', {'name': name, 'description': description});

  // ── Locations ──────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getLocations() async => await _get('/locations');
  static Future<dynamic> createLocation(String name, {String description = ''}) async =>
      _post('/locations', {'name': name, 'description': description});

  // ── Products ───────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getProducts() async => await _get('/products');

  static Future<dynamic> createProduct(Map<String, dynamic> data) async =>
      _post('/products', data);

  static Future<dynamic> updateProduct(int id, Map<String, dynamic> data) async =>
      _put('/products/$id', data);

  static Future<void> deleteProduct(int id) async => _delete('/products/$id');

  static Future<dynamic> getProductByBarcode(String barcode) async {
    try {
      return await _get('/products/barcode/$barcode');
    } catch (_) {
      return null;
    }
  }

  // ── External barcode lookup ─────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> lookupExternalBarcode(String barcode) async {
    // 1. Try Open Food Facts
    try {
      final res = await http.get(
        Uri.parse('https://world.openfoodfacts.org/api/v0/product/$barcode.json'),
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['status'] == 1 && data['product'] != null) {
          final p = data['product'] as Map<String, dynamic>;
          final name = (p['product_name'] ?? p['product_name_es'] ?? '').toString().trim();
          if (name.isNotEmpty) {
            final description = (p['categories'] ?? p['generic_name'] ?? '').toString().trim();
            return {'name': name, 'description': description};
          }
        }
      }
    } catch (_) {}

    // 2. Try UPCitemdb
    try {
      final res = await http.get(
        Uri.parse('https://api.upcitemdb.com/prod/trial/lookup?upc=$barcode'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final items = data['items'] as List?;
        if (items != null && items.isNotEmpty) {
          final item = items[0] as Map<String, dynamic>;
          final name = (item['title'] ?? '').toString().trim();
          if (name.isNotEmpty) {
            final description = (item['description'] ?? item['category'] ?? '').toString().trim();
            return {'name': name, 'description': description};
          }
        }
      }
    } catch (_) {}

    return null;
  }

  // ── Sales ──────────────────────────────────────────────────────────────────

  static Future<dynamic> createSale({
    required int productId,
    required int quantity,
    required double price,
    required double total,
  }) async =>
      _post('/sales', {
        'product_id': productId,
        'quantity': quantity,
        'price': price,
        'total': total,
      });

  // ── Dashboard ──────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getDashboardStats() async {
    final data = await _get('/dashboard/stats');
    return Map<String, dynamic>.from(data);
  }
}

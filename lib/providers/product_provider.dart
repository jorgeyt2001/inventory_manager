import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../services/api_service.dart';

class ProductProvider with ChangeNotifier {
  List<Product> _products = [];
  bool _isLoading = false;
  String _searchQuery = '';
  int? _filterCategoryId;
  int? _filterLocationId;

  List<Product> get products {
    var list = _products;
    if (_filterCategoryId != null) {
      list = list.where((p) => p.categoryId == _filterCategoryId).toList();
    }
    if (_filterLocationId != null) {
      list = list.where((p) => p.locationId == _filterLocationId).toList();
    }
    if (_searchQuery.isNotEmpty) {
      list = list.where((p) =>
        p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        p.category.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        (p.barcode?.contains(_searchQuery) ?? false) ||
        (p.color?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
        (p.talla?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
      ).toList();
    }
    return list;
  }

  bool get isLoading => _isLoading;
  int? get filterCategoryId => _filterCategoryId;
  int? get filterLocationId => _filterLocationId;

  List<Product> get lowStockProducts =>
      _products.where((p) => p.stock <= p.minStock).toList();

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setFilterCategory(int? categoryId) {
    _filterCategoryId = categoryId;
    notifyListeners();
  }

  void setFilterLocation(int? locationId) {
    _filterLocationId = locationId;
    notifyListeners();
  }

  Future<void> loadProducts() async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await ApiService.getProducts();
      _products = (data as List).map((e) => Product.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error loading products: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addProduct({
    required String name,
    String description = '',
    int? categoryId,
    int? locationId,
    required double price,
    double cost = 0,
    int stock = 0,
    int minStock = 5,
    String? barcode,
    String? color,
    String? talla,
  }) async {
    await ApiService.createProduct({
      'name': name,
      'description': description,
      'category_id': categoryId,
      'location_id': locationId,
      'price': price,
      'cost': cost,
      'stock': stock,
      'min_stock': minStock,
      'barcode': barcode,
      'color': color,
      'talla': talla,
    });
    await loadProducts();
  }

  Future<void> updateProduct(Product product) async {
    await ApiService.updateProduct(int.parse(product.id), product.toJson());
    await loadProducts();
  }

  Future<void> deleteProduct(String id) async {
    await ApiService.deleteProduct(int.parse(id));
    await loadProducts();
  }

  Future<void> updateStock(String productId, int quantity) async {
    final product = _products.where((p) => p.id == productId).firstOrNull;
    if (product == null) return;
    final newStock = (product.stock + quantity).clamp(0, 999999);
    await ApiService.updateProduct(int.parse(productId), {
      ...product.toJson(),
      'stock': newStock,
    });
    await loadProducts();
  }
}

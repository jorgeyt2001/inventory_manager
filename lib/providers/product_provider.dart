import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/product.dart';
import '../database/database_service.dart';

class ProductProvider with ChangeNotifier {
  List<Product> _products = [];
  bool _isLoading = false;
  String _searchQuery = '';

  List<Product> get products {
    if (_searchQuery.isEmpty) return _products;
    return _products.where((p) => 
      p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      p.category.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      (p.barcode?.contains(_searchQuery) ?? false)
    ).toList();
  }

  bool get isLoading => _isLoading;
  
  List<Product> get lowStockProducts => 
    _products.where((p) => p.stock <= p.minStock).toList();

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> loadProducts() async {
    _isLoading = true;
    notifyListeners();

    try {
      _products = await DatabaseService.instance.getAllProducts();
    } catch (e) {
      debugPrint('Error loading products: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addProduct({
    required String name,
    String description = '',
    String category = 'General',
    required double price,
    double cost = 0,
    int stock = 0,
    int minStock = 5,
    String? barcode,
  }) async {
    final product = Product(
      id: const Uuid().v4(),
      name: name,
      description: description,
      category: category,
      price: price,
      cost: cost,
      stock: stock,
      minStock: minStock,
      barcode: barcode,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await DatabaseService.instance.insertProduct(product);
    await loadProducts();
  }

  Future<void> updateProduct(Product product) async {
    final updated = product.copyWith(updatedAt: DateTime.now());
    await DatabaseService.instance.updateProduct(updated);
    await loadProducts();
  }

  Future<void> deleteProduct(String id) async {
    await DatabaseService.instance.deleteProduct(id);
    await loadProducts();
  }

  Future<void> updateStock(String productId, int quantity) async {
    await DatabaseService.instance.updateStock(productId, quantity);
    await loadProducts();
  }
}

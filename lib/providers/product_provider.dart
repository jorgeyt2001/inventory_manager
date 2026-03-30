import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import '../services/api_service.dart';

class ProductProvider with ChangeNotifier {
  List<Product> _products = [];
  bool _isLoading = false;
  String _searchQuery = '';
  int? _filterCategoryId;
  int? _filterLocationId;
  String? _filterColor;
  String? _filterTalla;
  String _sortBy = 'name';

  ProductProvider() {
    _loadFilters();
  }

  // ── Getters ──────────────────────────────────────────────────────────────────

  List<Product> get allProducts => _products;

  List<Product> get products {
    var list = _products.toList();

    if (_filterCategoryId != null) {
      list = list.where((p) => p.categoryId == _filterCategoryId).toList();
    }
    if (_filterLocationId != null) {
      list = list.where((p) => p.locationId == _filterLocationId).toList();
    }
    if (_filterColor != null) {
      list = list.where((p) => p.color == _filterColor).toList();
    }
    if (_filterTalla != null) {
      list = list.where((p) => p.talla == _filterTalla).toList();
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

    switch (_sortBy) {
      case 'price_asc':
        list.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'price_desc':
        list.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'stock_asc':
        list.sort((a, b) => a.stock.compareTo(b.stock));
        break;
      case 'stock_desc':
        list.sort((a, b) => b.stock.compareTo(a.stock));
        break;
      default:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }

    return list;
  }

  bool get isLoading => _isLoading;
  int? get filterCategoryId => _filterCategoryId;
  int? get filterLocationId => _filterLocationId;
  String? get filterColor => _filterColor;
  String? get filterTalla => _filterTalla;
  String get sortBy => _sortBy;

  List<Product> get lowStockProducts =>
      _products.where((p) => p.stock <= p.minStock).toList();

  // ── SharedPreferences persistence ────────────────────────────────────────────

  Future<void> _loadFilters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _filterColor = prefs.getString('pp_filter_color');
      _filterTalla = prefs.getString('pp_filter_talla');
      _sortBy = prefs.getString('pp_sort_by') ?? 'name';
      final catId = prefs.getInt('pp_filter_category');
      _filterCategoryId = (catId == null || catId == -1) ? null : catId;
      final locId = prefs.getInt('pp_filter_location');
      _filterLocationId = (locId == null || locId == -1) ? null : locId;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading filters: $e');
    }
  }

  Future<void> _saveFilters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_filterColor != null) {
        await prefs.setString('pp_filter_color', _filterColor!);
      } else {
        await prefs.remove('pp_filter_color');
      }
      if (_filterTalla != null) {
        await prefs.setString('pp_filter_talla', _filterTalla!);
      } else {
        await prefs.remove('pp_filter_talla');
      }
      await prefs.setString('pp_sort_by', _sortBy);
      await prefs.setInt('pp_filter_category', _filterCategoryId ?? -1);
      await prefs.setInt('pp_filter_location', _filterLocationId ?? -1);
    } catch (e) {
      debugPrint('Error saving filters: $e');
    }
  }

  // ── Setters ──────────────────────────────────────────────────────────────────

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setFilterCategory(int? categoryId) {
    _filterCategoryId = categoryId;
    notifyListeners();
    _saveFilters();
  }

  void setFilterLocation(int? locationId) {
    _filterLocationId = locationId;
    notifyListeners();
    _saveFilters();
  }

  void setFilterColor(String? color) {
    _filterColor = color;
    notifyListeners();
    _saveFilters();
  }

  void setFilterTalla(String? talla) {
    _filterTalla = talla;
    notifyListeners();
    _saveFilters();
  }

  void setSortBy(String sort) {
    _sortBy = sort;
    notifyListeners();
    _saveFilters();
  }

  void clearAllFilters() {
    _filterCategoryId = null;
    _filterLocationId = null;
    _filterColor = null;
    _filterTalla = null;
    _searchQuery = '';
    _sortBy = 'name';
    notifyListeners();
    _saveFilters();
  }

  // ── API operations ────────────────────────────────────────────────────────────

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

  Future<void> updateStock(String productId, int delta) async {
    final product = _products.where((p) => p.id == productId).firstOrNull;
    if (product == null) return;
    final newStock = (product.stock + delta).clamp(0, 999999);
    await ApiService.updateProduct(int.parse(productId), {
      ...product.toJson(),
      'stock': newStock,
    });
    await loadProducts();
  }
}

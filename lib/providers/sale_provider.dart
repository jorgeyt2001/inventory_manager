import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../database/database_service.dart';

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  double get total => product.price * quantity;
}

class SaleProvider with ChangeNotifier {
  List<Sale> _sales = [];
  final List<CartItem> _cart = [];
  bool _isLoading = false;
  double _discount = 0;
  String _paymentMethod = 'Efectivo';
  String? _customerName;

  List<Sale> get sales => _sales;
  List<CartItem> get cart => _cart;
  bool get isLoading => _isLoading;
  double get discount => _discount;
  String get paymentMethod => _paymentMethod;

  double get subtotal => _cart.fold(0, (sum, item) => sum + item.total);
  double get tax => subtotal * 0.0;
  double get total => subtotal + tax - _discount;

  Future<void> loadSales() async {
    _isLoading = true;
    notifyListeners();

    try {
      _sales = await DatabaseService.instance.getAllSales();
    } catch (e) {
      debugPrint('Error loading sales: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  void addToCart(Product product) {
    final existingIndex = _cart.indexWhere((item) => item.product.id == product.id);
    
    if (existingIndex >= 0) {
      if (_cart[existingIndex].quantity < product.stock) {
        _cart[existingIndex].quantity++;
      }
    } else {
      if (product.stock > 0) {
        _cart.add(CartItem(product: product));
      }
    }
    notifyListeners();
  }

  void removeFromCart(String productId) {
    _cart.removeWhere((item) => item.product.id == productId);
    notifyListeners();
  }

  void updateQuantity(String productId, int quantity) {
    final index = _cart.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      if (quantity <= 0) {
        _cart.removeAt(index);
      } else if (quantity <= _cart[index].product.stock) {
        _cart[index].quantity = quantity;
      }
    }
    notifyListeners();
  }

  void setDiscount(double value) {
    _discount = value;
    notifyListeners();
  }

  void setPaymentMethod(String method) {
    _paymentMethod = method;
    notifyListeners();
  }

  void setCustomerName(String? name) {
    _customerName = name;
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    _discount = 0;
    _customerName = null;
    notifyListeners();
  }

  Future<Sale?> completeSale() async {
    if (_cart.isEmpty) return null;

    final sale = Sale(
      id: const Uuid().v4(),
      items: _cart.map((item) => SaleItem(
        productId: item.product.id,
        productName: item.product.name,
        quantity: item.quantity,
        unitPrice: item.product.price,
        total: item.total,
      )).toList(),
      subtotal: subtotal,
      tax: tax,
      discount: _discount,
      total: total,
      paymentMethod: _paymentMethod,
      customerName: _customerName,
      createdAt: DateTime.now(),
    );

    await DatabaseService.instance.insertSale(sale);
    clearCart();
    await loadSales();
    
    return sale;
  }

  List<Sale> getSalesByDateRange(DateTime start, DateTime end) {
    return _sales.where((sale) => 
      sale.createdAt.isAfter(start) && sale.createdAt.isBefore(end)
    ).toList();
  }

  double getTotalByDateRange(DateTime start, DateTime end) {
    return getSalesByDateRange(start, end).fold(0, (sum, sale) => sum + sale.total);
  }
}

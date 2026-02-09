import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/product_return.dart';
import '../database/database_service.dart';

class ReturnProvider with ChangeNotifier {
  List<ProductReturn> _returns = [];
  bool _isLoading = false;

  List<ProductReturn> get returns => _returns;
  bool get isLoading => _isLoading;

  Future<void> loadReturns() async {
    _isLoading = true;
    notifyListeners();

    try {
      _returns = await DatabaseService.instance.getAllReturns();
    } catch (e) {
      debugPrint('Error loading returns: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> createReturn({
    required String saleId,
    required String productId,
    required String productName,
    required int quantity,
    required double amount,
    required String reason,
    String? notes,
  }) async {
    final productReturn = ProductReturn(
      id: const Uuid().v4(),
      saleId: saleId,
      productId: productId,
      productName: productName,
      quantity: quantity,
      amount: amount,
      reason: reason,
      notes: notes,
      createdAt: DateTime.now(),
    );

    await DatabaseService.instance.insertReturn(productReturn);
    await loadReturns();
  }
}

import 'package:flutter/foundation.dart';
import '../models/category.dart';
import '../services/api_service.dart';

class CategoryProvider with ChangeNotifier {
  List<AppCategory> _categories = [];
  bool _isLoading = false;

  List<AppCategory> get categories => _categories;
  bool get isLoading => _isLoading;

  Future<void> loadCategories() async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await ApiService.getCategories();
      _categories = (data as List).map((e) => AppCategory.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
    _isLoading = false;
    notifyListeners();
  }
}

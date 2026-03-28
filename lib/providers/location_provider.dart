import 'package:flutter/foundation.dart';
import '../models/location.dart';
import '../services/api_service.dart';

class LocationProvider with ChangeNotifier {
  List<AppLocation> _locations = [];
  bool _isLoading = false;

  List<AppLocation> get locations => _locations;
  bool get isLoading => _isLoading;

  Future<void> loadLocations() async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await ApiService.getLocations();
      _locations = (data as List).map((e) => AppLocation.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error loading locations: $e');
    }
    _isLoading = false;
    notifyListeners();
  }
}

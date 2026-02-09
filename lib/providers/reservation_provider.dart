import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/reservation.dart';
import '../database/database_service.dart';

class ReservationProvider with ChangeNotifier {
  List<Reservation> _reservations = [];
  bool _isLoading = false;

  List<Reservation> get reservations => _reservations;
  List<Reservation> get pendingReservations =>
      _reservations.where((r) => r.status == 'pendiente').toList();
  bool get isLoading => _isLoading;

  Future<void> loadReservations() async {
    _isLoading = true;
    notifyListeners();

    try {
      final maps = await DatabaseService.instance.getAllReservations();
      _reservations = maps.map((map) => Reservation.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error loading reservations: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addReservation({
    required String productName,
    String? description,
    String? color,
    String? talla,
    int quantity = 1,
    required String customerName,
    String? customerPhone,
    String? notes,
  }) async {
    final reservation = Reservation(
      id: const Uuid().v4(),
      productName: productName,
      description: description,
      color: color,
      talla: talla,
      quantity: quantity,
      customerName: customerName,
      customerPhone: customerPhone,
      notes: notes,
      createdAt: DateTime.now(),
    );

    await DatabaseService.instance.insertReservation(reservation.toMap());
    await loadReservations();
  }

  Future<void> updateStatus(String id, String status) async {
    await DatabaseService.instance.updateReservationStatus(id, status);
    await loadReservations();
  }

  Future<void> deleteReservation(String id) async {
    await DatabaseService.instance.deleteReservation(id);
    await loadReservations();
  }
}

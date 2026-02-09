class Reservation {
  final String id;
  final String productName;
  final String? description;
  final String? color;
  final String? talla;
  final int quantity;
  final String customerName;
  final String? customerPhone;
  final String? notes;
  final String status; // pendiente, completada, cancelada
  final DateTime createdAt;

  Reservation({
    required this.id,
    required this.productName,
    this.description,
    this.color,
    this.talla,
    this.quantity = 1,
    required this.customerName,
    this.customerPhone,
    this.notes,
    this.status = 'pendiente',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productName': productName,
      'description': description,
      'color': color,
      'talla': talla,
      'quantity': quantity,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'notes': notes,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Reservation.fromMap(Map<String, dynamic> map) {
    return Reservation(
      id: map['id'],
      productName: map['productName'],
      description: map['description'],
      color: map['color'],
      talla: map['talla'],
      quantity: map['quantity'] ?? 1,
      customerName: map['customerName'],
      customerPhone: map['customerPhone'],
      notes: map['notes'],
      status: map['status'] ?? 'pendiente',
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}

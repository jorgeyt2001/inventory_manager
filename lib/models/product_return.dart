class ProductReturn {
  final String id;
  final String saleId;
  final String productId;
  final String productName;
  final int quantity;
  final double amount;
  final String reason;
  final String? notes;
  final DateTime createdAt;

  ProductReturn({
    required this.id,
    required this.saleId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.amount,
    required this.reason,
    this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'saleId': saleId,
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'amount': amount,
      'reason': reason,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ProductReturn.fromMap(Map<String, dynamic> map) {
    return ProductReturn(
      id: map['id'],
      saleId: map['saleId'],
      productId: map['productId'],
      productName: map['productName'],
      quantity: map['quantity'],
      amount: map['amount']?.toDouble() ?? 0.0,
      reason: map['reason'],
      notes: map['notes'],
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}

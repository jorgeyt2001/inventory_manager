class Product {
  final String id;
  final String name;
  final String description;
  final String category;
  final double price;
  final double cost;
  final int stock;
  final int minStock;
  final String? barcode;
  final String? color;
  final String? talla;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Colores predefinidos de Selene
  static const List<String> coloresSelene = [
    'Marfil',
    'Rose',
    'Negro',
    'Blanco',
    'Nude',
    'Tierra',
    'Beige',
    'Rosa',
    'Rojo',
    'Vino',
    'Coral',
    'Cafe',
    'Chocolate',
    'Gris',
    'Azul',
    'Marino',
    'Celeste',
    'Verde',
    'Morado',
    'Hueso',
  ];

  // Tallas predefinidas de Selene
  static const List<String> tallasSelene = [
    '80',
    '85',
    '90',
    '95',
    '100',
    '105',
    '110',
    '115',
    '120',
  ];

  Product({
    required this.id,
    required this.name,
    this.description = '',
    this.category = 'General',
    required this.price,
    this.cost = 0,
    this.stock = 0,
    this.minStock = 5,
    this.barcode,
    this.color,
    this.talla,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'price': price,
      'cost': cost,
      'stock': stock,
      'minStock': minStock,
      'barcode': barcode,
      'color': color,
      'talla': talla,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      name: map['name'],
      description: map['description'] ?? '',
      category: map['category'] ?? 'General',
      price: map['price']?.toDouble() ?? 0.0,
      cost: map['cost']?.toDouble() ?? 0.0,
      stock: map['stock']?.toInt() ?? 0,
      minStock: map['minStock']?.toInt() ?? 5,
      barcode: map['barcode'],
      color: map['color'],
      talla: map['talla'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }

  Product copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    double? price,
    double? cost,
    int? stock,
    int? minStock,
    String? barcode,
    String? color,
    String? talla,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      stock: stock ?? this.stock,
      minStock: minStock ?? this.minStock,
      barcode: barcode ?? this.barcode,
      color: color ?? this.color,
      talla: talla ?? this.talla,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

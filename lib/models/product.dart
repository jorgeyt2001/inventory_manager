class Product {
  final String id; // API integer id stored as String
  final String name;
  final String description;
  final String category; // display name (populated from category_name)
  final int? categoryId;
  final int? locationId;
  final String? locationName;
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
    'Blanco',
    'Marfil',
    'Hueso',
    'Nude',
    'Beige',
    'Camel',
    'Tierra',
    'Cafe',
    'Chocolate',
    'Gris',
    'Plata',
    'Negro',
    'Dorado',
    'Rose',
    'Rosa',
    'Rojo',
    'Coral',
    'Salmón',
    'Fucsia',
    'Vino',
    'Burdeos',
    'Granate',
    'Mostaza',
    'Naranja',
    'Amarillo',
    'Azul',
    'Marino',
    'Celeste',
    'Turquesa',
    'Verde',
    'Morado',
    'Lavanda',
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
    this.categoryId,
    this.locationId,
    this.locationName,
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

  // ── API JSON ────────────────────────────────────────────────────────────────

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'].toString(),
      name: json['name'],
      description: json['description'] ?? '',
      category: json['category_name'] ?? 'General',
      categoryId: json['category_id'],
      locationId: json['location_id'],
      locationName: json['location_name'],
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      cost: (json['cost'] as num?)?.toDouble() ?? 0.0,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      minStock: (json['min_stock'] as num?)?.toInt() ?? 5,
      barcode: json['barcode'],
      color: json['color'],
      talla: json['talla'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
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
    };
  }

  // ── Legacy SQLite map (kept for sale history compatibility) ─────────────────

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
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      cost: (map['cost'] as num?)?.toDouble() ?? 0.0,
      stock: (map['stock'] as num?)?.toInt() ?? 0,
      minStock: (map['minStock'] as num?)?.toInt() ?? 5,
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
    int? categoryId,
    int? locationId,
    String? locationName,
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
      categoryId: categoryId ?? this.categoryId,
      locationId: locationId ?? this.locationId,
      locationName: locationName ?? this.locationName,
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

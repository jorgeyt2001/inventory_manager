import 'dart:convert';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/product_return.dart';

class DatabaseService {
  static Database? _database;
  static final DatabaseService instance = DatabaseService._init();

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('inventory.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, filePath);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        category TEXT,
        price REAL NOT NULL,
        cost REAL,
        stock INTEGER DEFAULT 0,
        minStock INTEGER DEFAULT 5,
        barcode TEXT,
        color TEXT,
        talla TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sales (
        id TEXT PRIMARY KEY,
        items TEXT NOT NULL,
        subtotal REAL NOT NULL,
        tax REAL,
        discount REAL,
        total REAL NOT NULL,
        paymentMethod TEXT,
        customerName TEXT,
        notes TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE returns (
        id TEXT PRIMARY KEY,
        saleId TEXT NOT NULL,
        productId TEXT NOT NULL,
        productName TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        amount REAL NOT NULL,
        reason TEXT NOT NULL,
        notes TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE reservations (
        id TEXT PRIMARY KEY,
        productName TEXT NOT NULL,
        description TEXT,
        color TEXT,
        talla TEXT,
        quantity INTEGER NOT NULL DEFAULT 1,
        customerName TEXT NOT NULL,
        customerPhone TEXT,
        notes TEXT,
        status TEXT NOT NULL DEFAULT 'pendiente',
        createdAt TEXT NOT NULL
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE products ADD COLUMN color TEXT');
      await db.execute('ALTER TABLE products ADD COLUMN talla TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS reservations (
          id TEXT PRIMARY KEY,
          productName TEXT NOT NULL,
          description TEXT,
          color TEXT,
          talla TEXT,
          quantity INTEGER NOT NULL DEFAULT 1,
          customerName TEXT NOT NULL,
          customerPhone TEXT,
          notes TEXT,
          status TEXT NOT NULL DEFAULT 'pendiente',
          createdAt TEXT NOT NULL
        )
      ''');
    }
  }

  Future<List<Product>> getAllProducts() async {
    final db = await database;
    final result = await db.query('products', orderBy: 'name ASC');
    return result.map((map) => Product.fromMap(map)).toList();
  }

  Future<void> insertProduct(Product product) async {
    final db = await database;
    await db.insert('products', product.toMap());
  }

  Future<void> updateProduct(Product product) async {
    final db = await database;
    await db.update('products', product.toMap(), where: 'id = ?', whereArgs: [product.id]);
  }

  Future<void> deleteProduct(String id) async {
    final db = await database;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateStock(String productId, int quantity) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE products SET stock = stock + ?, updatedAt = ? WHERE id = ?',
      [quantity, DateTime.now().toIso8601String(), productId],
    );
  }

  Future<List<Sale>> getAllSales() async {
    final db = await database;
    final result = await db.query('sales', orderBy: 'createdAt DESC');
    return result.map((map) {
      final items = jsonDecode(map['items'] as String) as List;
      return Sale(
        id: map['id'] as String,
        items: items.map((e) => SaleItem.fromMap(e)).toList(),
        subtotal: (map['subtotal'] as num).toDouble(),
        tax: (map['tax'] as num?)?.toDouble() ?? 0,
        discount: (map['discount'] as num?)?.toDouble() ?? 0,
        total: (map['total'] as num).toDouble(),
        paymentMethod: map['paymentMethod'] as String? ?? 'Efectivo',
        customerName: map['customerName'] as String?,
        notes: map['notes'] as String?,
        createdAt: DateTime.parse(map['createdAt'] as String),
      );
    }).toList();
  }

  Future<void> insertSale(Sale sale) async {
    final db = await database;
    final map = sale.toMap();
    map['items'] = jsonEncode(sale.items.map((e) => e.toMap()).toList());
    await db.insert('sales', map);
    
    for (var item in sale.items) {
      await updateStock(item.productId, -item.quantity);
    }
  }

  Future<List<ProductReturn>> getAllReturns() async {
    final db = await database;
    final result = await db.query('returns', orderBy: 'createdAt DESC');
    return result.map((map) => ProductReturn.fromMap(map)).toList();
  }

  Future<void> insertReturn(ProductReturn productReturn) async {
    final db = await database;
    await db.insert('returns', productReturn.toMap());
    await updateStock(productReturn.productId, productReturn.quantity);
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final db = await database;
    final result = await db.query('products', where: 'barcode = ?', whereArgs: [barcode]);
    if (result.isEmpty) return null;
    return Product.fromMap(result.first);
  }

  // Reservations
  Future<List<Map<String, dynamic>>> getAllReservations() async {
    final db = await database;
    return await db.query('reservations', orderBy: 'createdAt DESC');
  }

  Future<void> insertReservation(Map<String, dynamic> reservation) async {
    final db = await database;
    await db.insert('reservations', reservation);
  }

  Future<void> updateReservationStatus(String id, String status) async {
    final db = await database;
    await db.update('reservations', {'status': status}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteReservation(String id) async {
    final db = await database;
    await db.delete('reservations', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>> getStats() async {
    final db = await database;
    
    final productsResult = await db.rawQuery('SELECT COUNT(*) as count FROM products');
    final productsCount = (productsResult.first['count'] as int?) ?? 0;
    
    final lowStockResult = await db.rawQuery('SELECT COUNT(*) as count FROM products WHERE stock <= minStock');
    final lowStockCount = (lowStockResult.first['count'] as int?) ?? 0;
    
    final todaySales = await db.rawQuery(
      "SELECT SUM(total) as total FROM sales WHERE date(createdAt) = date('now')"
    );
    final todayTotal = (todaySales.first['total'] as num?)?.toDouble() ?? 0.0;
    
    final totalSales = await db.rawQuery('SELECT SUM(total) as total FROM sales');
    final allTimeTotal = (totalSales.first['total'] as num?)?.toDouble() ?? 0.0;
    
    return {
      'productsCount': productsCount,
      'lowStockCount': lowStockCount,
      'todaySales': todayTotal,
      'totalSales': allTimeTotal,
    };
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/models/product.dart';
import '../../../core/models/stock_movement.dart';
import '../../../core/models/stock_receipt.dart';

class ProductFilterState {
  final String categoryId;
  final String searchQuery;
  final String stockFilter; // 'all', 'in_stock', 'low_stock'

  ProductFilterState({
    this.categoryId = 'all',
    this.searchQuery = '',
    this.stockFilter = 'all',
  });

  ProductFilterState copyWith({
    String? categoryId,
    String? searchQuery,
    String? stockFilter,
  }) {
    return ProductFilterState(
      categoryId: categoryId ?? this.categoryId,
      searchQuery: searchQuery ?? this.searchQuery,
      stockFilter: stockFilter ?? this.stockFilter,
    );
  }
}

final productFilterProvider = StateProvider<ProductFilterState>(
  (ref) => ProductFilterState(),
);

final catalogProductsProvider = FutureProvider<List<Product>>((ref) async {
  final db = await DatabaseHelper.instance.database;
  final filter = ref.watch(productFilterProvider);

  String sql = '''
    SELECT p.*, c.name as category_name
    FROM products p
    LEFT JOIN categories c ON p.category_id = c.category_id
    WHERE p.is_active = 1
  ''';
  List<dynamic> args = [];

  if (filter.categoryId != 'all') {
    sql += ' AND p.category_id = ?';
    args.add(filter.categoryId);
  }
  if (filter.searchQuery.isNotEmpty) {
    sql += ' AND (p.name LIKE ? OR p.sku LIKE ? OR p.brand LIKE ?)';
    final q = '%${filter.searchQuery}%';
    args.addAll([q, q, q]);
  }
  if (filter.stockFilter == 'in_stock') {
    sql += ' AND p.stock > 0';
  } else if (filter.stockFilter == 'low_stock') {
    sql += ' AND p.stock <= p.alert_threshold';
  }

  sql += ' ORDER BY p.name ASC';
  final maps = await db.rawQuery(sql, args);
  return maps.map((m) => Product.fromMap(m)).toList();
});

final catalogReceiptsProvider = FutureProvider<List<StockReceipt>>((ref) async {
  final db = await DatabaseHelper.instance.database;
  final rMaps = await db.rawQuery('''
    SELECT r.*, s.name as supplier_name, u.full_name as creator_name
    FROM stock_receipts r
    LEFT JOIN suppliers s ON r.supplier_id = s.supplier_id
    LEFT JOIN app_users u ON r.created_by = u.user_id
    ORDER BY r.received_at DESC
  ''');

  List<StockReceipt> receipts = [];
  for (var rMap in rMaps) {
    final receiptId = rMap['receipt_id'] as String;
    final itemMaps = await db.rawQuery(
      '''
      SELECT i.*, p.name as product_name, p.sku
      FROM stock_receipt_items i
      JOIN products p ON i.product_id = p.product_id
      WHERE i.receipt_id = ?
    ''',
      [receiptId],
    );

    final items = itemMaps.map((m) => StockReceiptItem.fromMap(m)).toList();
    receipts.add(StockReceipt.fromMap(rMap, items: items));
  }
  return receipts;
});

final catalogMovementsProvider = FutureProvider<List<StockMovement>>((
  ref,
) async {
  final db = await DatabaseHelper.instance.database;
  final maps = await db.rawQuery('''
    SELECT m.*, p.name as product_name, p.sku, u.full_name as creator_name
    FROM stock_movements m
    JOIN products p ON m.product_id = p.product_id
    LEFT JOIN app_users u ON m.created_by = u.user_id
    ORDER BY m.created_at DESC
  ''');
  return maps.map((m) => StockMovement.fromMap(m)).toList();
});

final catalogLowStockAlertsProvider = FutureProvider<List<Product>>((
  ref,
) async {
  final db = await DatabaseHelper.instance.database;
  final maps = await db.rawQuery('''
    SELECT p.*, c.name as category_name
    FROM products p
    LEFT JOIN categories c ON p.category_id = c.category_id
    WHERE p.stock <= p.alert_threshold AND p.is_active = 1
    ORDER BY p.stock ASC
  ''');
  return maps.map((m) => Product.fromMap(m)).toList();
});

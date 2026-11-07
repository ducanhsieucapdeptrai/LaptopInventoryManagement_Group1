import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/models/category.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/sales_order.dart';
import '../../../core/models/supplier.dart';

final categorySearchQueryProvider = StateProvider<String>((ref) => '');
final supplierSearchQueryProvider = StateProvider<String>((ref) => '');
final customerSearchQueryProvider = StateProvider<String>((ref) => '');

final masterCategoriesProvider = FutureProvider<List<Category>>((ref) async {
  final db = await DatabaseHelper.instance.database;
  final query = ref.watch(categorySearchQueryProvider);
  String sql = 'SELECT * FROM categories WHERE is_active = 1';
  List<dynamic> args = [];
  if (query.isNotEmpty) {
    sql += ' AND name LIKE ?';
    args.add('%$query%');
  }
  sql += ' ORDER BY name ASC';
  final maps = await db.rawQuery(sql, args);
  return maps.map((m) => Category.fromMap(m)).toList();
});

final masterSuppliersProvider = FutureProvider<List<Supplier>>((ref) async {
  final db = await DatabaseHelper.instance.database;
  final query = ref.watch(supplierSearchQueryProvider);
  String sql = 'SELECT * FROM suppliers WHERE is_active = 1';
  List<dynamic> args = [];
  if (query.isNotEmpty) {
    sql += ' AND (name LIKE ? OR phone LIKE ?)';
    args.addAll(['%$query%', '%$query%']);
  }
  sql += ' ORDER BY name ASC';
  final maps = await db.rawQuery(sql, args);
  return maps.map((m) => Supplier.fromMap(m)).toList();
});

final masterCustomersProvider = FutureProvider<List<Customer>>((ref) async {
  final db = await DatabaseHelper.instance.database;
  final query = ref.watch(customerSearchQueryProvider);
  String sql = 'SELECT * FROM customers WHERE 1=1';
  List<dynamic> args = [];
  if (query.isNotEmpty) {
    sql += ' AND (name LIKE ? OR phone LIKE ?)';
    args.addAll(['%$query%', '%$query%']);
  }
  sql += ' ORDER BY total_spent DESC, name ASC';
  final maps = await db.rawQuery(sql, args);
  return maps.map((m) => Customer.fromMap(m)).toList();
});

final customerOrdersHistoryProvider =
    FutureProvider.family<List<SalesOrder>, String>((ref, customerId) async {
      final db = await DatabaseHelper.instance.database;
      final maps = await db.query(
        'sales_orders',
        where: 'customer_id = ?',
        whereArgs: [customerId],
        orderBy: 'created_at DESC',
      );
      return maps.map((m) => SalesOrder.fromMap(m)).toList();
    });

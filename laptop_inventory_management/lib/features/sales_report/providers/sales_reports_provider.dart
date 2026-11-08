import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/models/payment.dart';
import '../../../core/models/sales_order.dart';
import '../../../core/models/sales_return.dart';

class OrderListFilterState {
  final String status;
  final String searchQuery;

  OrderListFilterState({this.status = 'all', this.searchQuery = ''});

  OrderListFilterState copyWith({String? status, String? searchQuery}) {
    return OrderListFilterState(
      status: status ?? this.status,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

final orderListFilterProvider = StateProvider<OrderListFilterState>(
  (ref) => OrderListFilterState(),
);

final salesOrderListProvider = FutureProvider<List<SalesOrder>>((ref) async {
  final db = await DatabaseHelper.instance.database;
  final filter = ref.watch(orderListFilterProvider);

  String sql = '''
    SELECT o.*, c.name as customer_name, c.phone as customer_phone, u.full_name as creator_name
    FROM sales_orders o
    LEFT JOIN customers c ON o.customer_id = c.customer_id
    LEFT JOIN app_users u ON o.created_by = u.user_id
    WHERE 1=1
  ''';
  List<dynamic> args = [];

  if (filter.status != 'all') {
    sql += ' AND o.status = ?';
    args.add(filter.status);
  }
  if (filter.searchQuery.isNotEmpty) {
    sql += ' AND (o.order_id LIKE ? OR c.name LIKE ? OR c.phone LIKE ?)';
    final q = '%${filter.searchQuery}%';
    args.addAll([q, q, q]);
  }
  sql += ' ORDER BY o.created_at DESC';

  final orderMaps = await db.rawQuery(sql, args);
  List<SalesOrder> orders = [];

  for (var oMap in orderMaps) {
    final orderId = oMap['order_id'] as String;
    final itemMaps = await db.rawQuery(
      '''
      SELECT i.*, p.name as product_name, p.sku
      FROM sales_order_items i
      JOIN products p ON i.product_id = p.product_id
      WHERE i.order_id = ?
    ''',
      [orderId],
    );

    final items = itemMaps.map((m) => SalesOrderItem.fromMap(m)).toList();
    orders.add(SalesOrder.fromMap(oMap, items: items));
  }
  return orders;
});

final salesReturnsListProvider = FutureProvider<List<SalesReturn>>((ref) async {
  final db = await DatabaseHelper.instance.database;
  final rMaps = await db.rawQuery('''
    SELECT r.*, u.full_name as approver_name
    FROM sales_returns r
    LEFT JOIN app_users u ON r.approved_by = u.user_id
    ORDER BY r.created_at DESC
  ''');

  List<SalesReturn> returns = [];
  for (var rMap in rMaps) {
    final returnId = rMap['return_id'] as String;
    final itemMaps = await db.rawQuery(
      '''
      SELECT ri.*, p.name as product_name, p.sku
      FROM sales_return_items ri
      JOIN sales_order_items oi ON ri.order_item_id = oi.order_item_id
      JOIN products p ON oi.product_id = p.product_id
      WHERE ri.return_id = ?
    ''',
      [returnId],
    );

    final items = itemMaps.map((m) => SalesReturnItem.fromMap(m)).toList();
    returns.add(SalesReturn.fromMap(rMap, items: items));
  }
  return returns;
});

final salesOrderPaymentsProvider = FutureProvider.family<List<Payment>, String>(
  (ref, orderId) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'payments',
      where: 'order_id = ?',
      whereArgs: [orderId],
    );
    return maps.map((m) => Payment.fromMap(m)).toList();
  },
);

final salesAnalyticsDataProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  final db = await DatabaseHelper.instance.database;

  final salesRes = await db.rawQuery(
    'SELECT COUNT(*) as c, IFNULL(SUM(total), 0) as s FROM sales_orders WHERE status = "completed"',
  );
  final grossRevenue = (salesRes.first['s'] as num).toDouble();
  final completedOrders = (salesRes.first['c'] as num).toInt();

  final refundRes = await db.rawQuery(
    'SELECT COUNT(*) as c, IFNULL(SUM(refund_total), 0) as s FROM sales_returns WHERE status = "approved"',
  );
  final totalRefunds = (refundRes.first['s'] as num).toDouble();
  final returnCount = (refundRes.first['c'] as num).toInt();

  // BR-13: Net Revenue = Gross - Refunds
  final netRevenue = grossRevenue - totalRefunds;

  final costRes = await db.rawQuery('''
    SELECT IFNULL(SUM(i.cost_snapshot * i.qty), 0) as total_cost
    FROM sales_order_items i
    JOIN sales_orders o ON i.order_id = o.order_id
    WHERE o.status = 'completed'
  ''');
  final totalCost = (costRes.first['total_cost'] as num).toDouble();
  final grossMargin = netRevenue - totalCost;

  final topProducts = await db.rawQuery('''
    SELECT p.name, p.sku, IFNULL(SUM(i.qty), 0) as sold_qty, IFNULL(SUM(i.qty * i.price_snapshot), 0) as sales_val
    FROM sales_order_items i
    JOIN products p ON i.product_id = p.product_id
    JOIN sales_orders o ON i.order_id = o.order_id
    WHERE o.status = 'completed'
    GROUP BY p.product_id
    ORDER BY sold_qty DESC
    LIMIT 5
  ''');

  return {
    'gross_revenue': grossRevenue,
    'completed_orders': completedOrders,
    'total_refunds': totalRefunds,
    'return_count': returnCount,
    'net_revenue': netRevenue,
    'gross_margin': grossMargin,
    'top_products': topProducts,
  };
});

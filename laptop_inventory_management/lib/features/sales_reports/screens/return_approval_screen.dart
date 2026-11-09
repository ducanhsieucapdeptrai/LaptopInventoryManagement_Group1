import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/models/sales_return.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/drawer_menu_button.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/logout_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../providers/sales_reports_provider.dart';
import 'sales_return_request_screen.dart';

class ReturnApprovalScreen extends ConsumerWidget {
  const ReturnApprovalScreen({super.key});

  Future<void> _approveReturn(
    BuildContext context,
    WidgetRef ref,
    SalesReturn ret,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Phê Duyệt Đổi Trả (Admin FR-26)'),
        content: Text(
          'Xác nhận duyệt hoàn tiền ${Formatters.formatCurrency(ret.refundTotal)} cho đơn #${ret.orderId}? Hàng còn bán được sẽ tự động cộng lại tồn kho.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.emeraldGreen,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Duyệt & Hoàn tiền'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final db = await DatabaseHelper.instance.database;

      await db.transaction((txn) async {
        final now = DateTime.now().toIso8601String();

        for (var it in ret.items) {
          if (it.restockable) {
            final lineInfo = await txn.query(
              'sales_order_items',
              where: 'order_item_id = ?',
              whereArgs: [it.orderItemId],
            );
            if (lineInfo.isNotEmpty) {
              final pId = lineInfo.first['product_id'] as String;
              await txn.rawUpdate(
                'UPDATE products SET stock = stock + ? WHERE product_id = ?',
                [it.qty, pId],
              );
              await txn.insert('stock_movements', {
                'movement_id':
                    'mov_ret_${DateTime.now().millisecondsSinceEpoch}_$pId',
                'product_id': pId,
                'created_by': 'u_admin',
                'type': 'return',
                'qty_delta': it.qty,
                'ref': 'Khách trả hàng #${ret.returnId} (Đơn #${ret.orderId})',
                'created_at': now,
              });
            }
          }
        }

        await txn.update(
          'sales_returns',
          {'status': 'approved', 'approved_by': 'u_admin'},
          where: 'return_id = ?',
          whereArgs: [ret.returnId],
        );

        await txn.insert('audit_logs', {
          'audit_id': const Uuid().v4(),
          'user_id': 'u_admin',
          'action': 'RETURN_APPROVED',
          'entity': 'SalesReturn',
          'details':
              'Duyệt phiếu trả #${ret.returnId} - Hoàn tiền: ${ret.refundTotal} đ',
          'created_at': now,
        });
      });

      ref.invalidate(salesReturnsListProvider);
      ref.invalidate(salesAnalyticsDataProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phê duyệt thành công! Đã ghi nhận hoàn tiền.'),
            backgroundColor: AppTheme.emeraldGreen,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final returnsAsync = ref.watch(salesReturnsListProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('Phê Duyệt Đổi Trả (Trương)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(salesReturnsListProvider),
          ),
          const LogoutIconButton(),
        ],
      ),
      body: returnsAsync.when(
        data: (returns) {
          if (returns.isEmpty) {
            return const EmptyStateView(
              icon: Icons.assignment_return_outlined,
              title: 'Chưa có phiếu trả hàng nào',
              message: 'Hệ thống chưa ghi nhận yêu cầu đổi trả sau bán nào.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: returns.length,
            itemBuilder: (ctx, i) {
              final ret = returns[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            ret.returnId,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.red,
                            ),
                          ),
                          StatusBadge(status: ret.status),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Đơn hàng gốc: #${ret.orderId}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Lý do: ${ret.reason}',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const Divider(height: 16),
                      ...ret.items.map((it) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '• ${it.productName ?? "Sản phẩm"} (x${it.qty}) - ${it.restockable ? "Cộng lại kho" : "Hàng lỗi"}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              Text(
                                Formatters.formatCurrency(it.refundAmount),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Thời gian: ${Formatters.formatIsoDate(ret.createdAt)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            'Hoàn tiền: ${Formatters.formatCurrency(ret.refundTotal)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      if (ret.status == 'pending') ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.emeraldGreen,
                            ),
                            onPressed: () => _approveReturn(context, ref, ret),
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text(
                              'Admin Duyệt & Hoàn Tiền (FR-26)',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Lỗi: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.assignment_return),
        label: const Text('Tạo Yêu Cầu Trả (FR-24)'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SalesReturnRequestScreen()),
          );
        },
      ),
    );
  }
}

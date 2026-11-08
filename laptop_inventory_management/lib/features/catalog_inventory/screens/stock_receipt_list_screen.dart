import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/models/stock_receipt.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/drawer_menu_button.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/logout_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../providers/catalog_inventory_provider.dart';
import 'create_stock_receipt_screen.dart';

class StockReceiptListScreen extends ConsumerWidget {
  const StockReceiptListScreen({super.key});

  Future<void> _postReceipt(
    BuildContext context,
    WidgetRef ref,
    StockReceipt receipt,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận ghi sổ nhập kho?'),
        content: const Text(
          'Sau khi ghi sổ, số lượng tồn kho sẽ được cộng tăng tự động và ghi log biến động (FR-11, BR-05).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận nhập'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final db = await DatabaseHelper.instance.database;

      await db.transaction((txn) async {
        final rRows = await txn.query(
          'stock_receipts',
          where: 'receipt_id = ?',
          whereArgs: [receipt.receiptId],
        );
        if (rRows.isEmpty) throw Exception('Phiếu không tồn tại');
        if (rRows.first['status'] == 'posted') {
          throw Exception('Phiếu đã được ghi sổ trước đó! (BR-05)');
        }

        final itemRows = await txn.query(
          'stock_receipt_items',
          where: 'receipt_id = ?',
          whereArgs: [receipt.receiptId],
        );
        final now = DateTime.now().toIso8601String();

        for (var it in itemRows) {
          final pId = it['product_id'] as String;
          final qty = (it['qty'] as num).toInt();
          final cost = (it['unit_cost'] as num).toDouble();

          await txn.rawUpdate(
            'UPDATE products SET stock = stock + ?, cost = ? WHERE product_id = ?',
            [qty, cost, pId],
          );
          await txn.insert('stock_movements', {
            'movement_id': 'mov_${DateTime.now().millisecondsSinceEpoch}_$pId',
            'product_id': pId,
            'created_by': 'u_truong',
            'type': 'receipt',
            'qty_delta': qty,
            'ref': 'Phiếu nhập kho #${receipt.receiptId}',
            'created_at': now,
          });
        }

        await txn.update(
          'stock_receipts',
          {'status': 'posted'},
          where: 'receipt_id = ?',
          whereArgs: [receipt.receiptId],
        );
      });

      ref.invalidate(catalogReceiptsProvider);
      ref.invalidate(catalogProductsProvider);
      ref.invalidate(catalogMovementsProvider);
      ref.invalidate(catalogLowStockAlertsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ghi sổ nhập kho thành công! Đã tăng tồn kho.'),
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
    final receiptsAsync = ref.watch(catalogReceiptsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('Phiếu Nhập Hàng NCC (Trường)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(catalogReceiptsProvider),
          ),
          const LogoutIconButton(),
        ],
      ),
      body: receiptsAsync.when(
        data: (receipts) {
          if (receipts.isEmpty) {
            return const EmptyStateView(
              icon: Icons.inventory_2_outlined,
              title: 'Chưa có phiếu nhập nào',
              message: SystemMessages.msg14,
            );
          }

          final postedCount = receipts.where((r) => r.isPosted).length;
          final totalCostSum = receipts
              .where((r) => r.isPosted)
              .fold<double>(0, (sum, r) => sum + r.totalCost);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppTheme.emeraldGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.emeraldGreen.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text(
                          'Đã ghi sổ nhập',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$postedCount phiếu',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: Colors.grey.shade300,
                    ),
                    Column(
                      children: [
                        const Text(
                          'Tổng vốn nhập',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          Formatters.formatCurrency(totalCostSum),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppTheme.emeraldGreen,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ...receipts.map((rcpt) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              rcpt.receiptId,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                            StatusBadge(status: rcpt.status),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Nhà cung cấp: ${rcpt.supplierName ?? "NCC"}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Thời gian: ${Formatters.formatIsoDate(rcpt.receivedAt)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${rcpt.items.length} mặt hàng',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              Formatters.formatCurrency(rcpt.totalCost),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppTheme.emeraldGreen,
                              ),
                            ),
                          ],
                        ),
                        if (!rcpt.isPosted) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _postReceipt(context, ref, rcpt),
                              icon: const Icon(
                                Icons.check_circle_outline,
                                size: 18,
                              ),
                              label: const Text(
                                'Ghi Sổ Nhập Kho (Tăng Tồn Kho FR-11)',
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Lỗi: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Lập Phiếu Nhập Hàng (FR-10)'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateStockReceiptScreen()),
          );
        },
      ),
    );
  }
}

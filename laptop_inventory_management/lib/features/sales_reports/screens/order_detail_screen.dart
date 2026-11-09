import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/models/sales_order.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/status_badge.dart';
import '../providers/sales_reports_provider.dart';
import 'payment_screen.dart';

class OrderDetailScreen extends ConsumerWidget {
  final SalesOrder order;

  const OrderDetailScreen({super.key, required this.order});

  void _showPrintBillDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.print, color: AppTheme.primaryBlue),
            SizedBox(width: 8),
            Text('Hóa Đơn Bán Lẻ LPSM'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  'LAPTOP & PC SHOP MANAGEMENT\nCửa hàng PRM393 Nhóm 1\n--------------------------------------',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Mã hóa đơn: ${order.orderId}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Ngày: ${Formatters.formatIsoDate(order.createdAt)}'),
              Text('Khách hàng: ${order.customerName ?? "Khách lẻ"}'),
              const Divider(),
              ...order.items.map(
                (it) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${it.productName} (x${it.qty})',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      Text(
                        Formatters.formatCurrency(it.subtotal),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tạm tính:'),
                  Text(Formatters.formatCurrency(order.subtotal)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Chiết khấu (${order.discountPercent}%):'),
                  Text('- ${Formatters.formatCurrency(order.discountAmount)}'),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TỔNG THANH TOÁN:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    Formatters.formatCurrency(order.total),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Đang gửi lệnh in hóa đơn ra máy in nhiệt ESC/POS...',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.print),
            label: const Text('In hóa đơn'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(salesOrderPaymentsProvider(order.orderId));

    return Scaffold(
      appBar: AppBar(
        title: Text('Đơn Hàng #${order.orderId}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: 'In hóa đơn',
            onPressed: () => _showPrintBillDialog(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        order.orderId,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                      StatusBadge(status: order.status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Thời gian tạo: ${Formatters.formatIsoDate(order.createdAt)}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  Text(
                    'Nhân viên bán hàng: ${order.creatorName ?? "Nhân viên"}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  if (order.notes != null)
                    Text(
                      'Ghi chú: ${order.notes}',
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppTheme.primaryBlue,
                child: Icon(Icons.person, color: Colors.white),
              ),
              title: Text(
                order.customerName ?? 'Khách lẻ (Vãng lai)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(order.customerPhone ?? 'Không lưu số điện thoại'),
            ),
          ),
          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Danh sách sản phẩm (Snapshot BR-06)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const Divider(),
                  ...order.items.map((item) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.productName ?? 'Sản phẩm',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  'SKU: ${item.productSku} • Đơn giá: ${Formatters.formatCurrency(item.priceSnapshot)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'x${item.qty}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                Formatters.formatCurrency(item.subtotal),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryBlue,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tạm tính:'),
                      Text(Formatters.formatCurrency(order.subtotal)),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Chiết khấu (${order.discountPercent}%):'),
                      Text(
                        '- ${Formatters.formatCurrency(order.discountAmount)}',
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TỔNG ĐƠN HÀNG:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        Formatters.formatCurrency(order.total),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Lịch sử thanh toán (FR-20)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const Divider(),
                  paymentsAsync.when(
                    data: (payments) {
                      if (payments.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            order.isCompleted
                                ? 'Đã thu đủ ${Formatters.formatCurrency(order.paid)}'
                                : 'Chưa ghi nhận khoản thanh toán',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        );
                      }
                      return Column(
                        children: payments.map((p) {
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              p.method == 'cash'
                                  ? Icons.money
                                  : Icons.account_balance,
                              color: AppTheme.emeraldGreen,
                            ),
                            title: Text(
                              '${p.methodDisplayName} - ${Formatters.formatCurrency(p.amount)}',
                            ),
                            subtitle: Text(
                              Formatters.formatIsoDate(p.createdAt),
                            ),
                            trailing: StatusBadge(status: p.status),
                          );
                        }).toList(),
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Text('Lỗi: $err'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          if (order.isDraft) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    onPressed: () async {
                      final db = await DatabaseHelper.instance.database;
                      await db.update(
                        'sales_orders',
                        {'status': 'cancelled'},
                        where: 'order_id = ?',
                        whereArgs: [order.orderId],
                      );
                      ref.invalidate(salesOrderListProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã hủy đơn hàng đang xử lý (BR-10)'),
                          ),
                        );
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('Hủy Đơn Đang Xử Lý (BR-10)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PaymentScreen(order: order),
                        ),
                      );
                    },
                    icon: const Icon(Icons.payment),
                    label: const Text('Thanh Toán'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

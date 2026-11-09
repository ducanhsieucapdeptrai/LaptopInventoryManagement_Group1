import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/models/sales_order.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../providers/sales_reports_provider.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  final SalesOrder order;
  final bool isNewOrder;

  const PaymentScreen({
    super.key,
    required this.order,
    this.isNewOrder = false,
  });

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  String _method = 'cash'; // 'cash', 'bank_transfer'
  late final TextEditingController _amountCtrl;
  final TextEditingController _refCtrl = TextEditingController();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: widget.order.total.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  Future<void> _commitPayment() async {
    final enteredAmount =
        double.tryParse(_amountCtrl.text.replaceAll(RegExp(r'[^0-9.]'), '')) ??
        0.0;

    // BR-08: Exact payment matching
    if ((enteredAmount - widget.order.total).abs() > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(SystemMessages.msg08),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final db = await DatabaseHelper.instance.database;

      await db.transaction((txn) async {
        final itemRows = await txn.rawQuery(
          '''
          SELECT i.*, p.stock, p.name as product_name
          FROM sales_order_items i
          JOIN products p ON i.product_id = p.product_id
          WHERE i.order_id = ?
        ''',
          [widget.order.orderId],
        );

        for (var item in itemRows) {
          final curStock = (item['stock'] as num).toInt();
          final buyQty = (item['qty'] as num).toInt();
          final pName = item['product_name'] as String;

          // BR-03: Prohibit negative stock
          if (curStock < buyQty) {
            throw Exception(
              '${SystemMessages.msg07} ($pName còn $curStock, yêu cầu $buyQty)',
            );
          }
        }

        final now = DateTime.now().toIso8601String();

        // Atomically deduct inventory & record stock movements
        for (var item in itemRows) {
          final pId = item['product_id'] as String;
          final buyQty = (item['qty'] as num).toInt();

          await txn.rawUpdate(
            'UPDATE products SET stock = stock - ? WHERE product_id = ?',
            [buyQty, pId],
          );
          await txn.insert('stock_movements', {
            'movement_id':
                'mov_sale_${DateTime.now().millisecondsSinceEpoch}_$pId',
            'product_id': pId,
            'created_by': 'u_sales',
            'type': 'sale',
            'qty_delta': -buyQty,
            'ref': 'Bán hàng đơn #${widget.order.orderId}',
            'created_at': now,
          });
        }

        // Record payment
        await txn.insert('payments', {
          'payment_id': 'pay_${DateTime.now().millisecondsSinceEpoch}',
          'order_id': widget.order.orderId,
          'method': _method,
          'amount': enteredAmount,
          'status': 'success',
          'ref_code': _refCtrl.text.trim().isEmpty
              ? null
              : _refCtrl.text.trim(),
          'created_at': now,
        });

        // Update sales order to completed
        await txn.update(
          'sales_orders',
          {'status': 'completed', 'paid': enteredAmount},
          where: 'order_id = ?',
          whereArgs: [widget.order.orderId],
        );

        // Update customer total spend
        if (widget.order.customerId != null) {
          await txn.rawUpdate(
            '''
            UPDATE customers
            SET total_orders = total_orders + 1, total_spent = total_spent + ?
            WHERE customer_id = ?
          ''',
            [widget.order.total, widget.order.customerId],
          );
        }
      });

      // Background REST API cloud sync
      await ApiService.instance.syncOrderToCloudBackend({
        'order_id': widget.order.orderId,
        'amount': enteredAmount,
        'method': _method,
      });

      ref.invalidate(salesOrderListProvider);
      ref.invalidate(salesAnalyticsDataProvider);

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.check_circle, color: AppTheme.emeraldGreen),
              SizedBox(width: 8),
              Text('Thanh Toán Thành Công'),
            ],
          ),
          content: Text(
            'Đơn hàng #${widget.order.orderId} đã được ghi sổ thành công và trừ tồn kho tự động (FR-21, FR-34).\nĐồng bộ Cloud ERP thành công!',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, true);
              },
              child: const Text('Hoàn tất'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Giao dịch thất bại: $e (MSG-10)'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _cancelPayment() async {
    if (_isProcessing) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Hủy lượt thanh toán?'),
          ],
        ),
        content: const Text(
          'Khách hàng chưa thanh toán đơn này.\nBạn có muốn thoát ra ngoài để chỉnh sửa lại sản phẩm / số lượng không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ở lại thanh toán'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Thoát & Sửa đơn'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (widget.isNewOrder) {
        try {
          final db = await DatabaseHelper.instance.database;
          await db.delete(
            'sales_order_items',
            where: 'order_id = ?',
            whereArgs: [widget.order.orderId],
          );
          await db.delete(
            'sales_orders',
            where: 'order_id = ? AND status = ?',
            whereArgs: [widget.order.orderId, 'draft'],
          );
          ref.invalidate(salesOrderListProvider);
        } catch (_) {}
      }
      if (mounted) {
        Navigator.pop(context, false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _cancelPayment();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Quay lại sửa đơn',
            onPressed: _cancelPayment,
          ),
          title: Text('Thanh Toán Đơn #${widget.order.orderId}'),
          actions: [
            TextButton.icon(
              onPressed: _isProcessing ? null : _cancelPayment,
              icon: const Icon(Icons.close, color: Colors.white, size: 18),
              label: const Text('Thoát', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Card(
                color: AppTheme.primaryBlue,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text(
                        'SỐ TIỀN CẦN THU (VND)',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        Formatters.formatCurrency(widget.order.total),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Khách hàng: ${widget.order.customerName ?? "Khách lẻ"}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _method = 'cash'),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _method == 'cash'
                              ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                              : Colors.white,
                          border: Border.all(
                            color: _method == 'cash'
                                ? AppTheme.primaryBlue
                                : Colors.grey.shade300,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: const [
                            Icon(
                              Icons.money,
                              size: 28,
                              color: AppTheme.emeraldGreen,
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Tiền Mặt',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _method = 'bank_transfer'),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _method == 'bank_transfer'
                              ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                              : Colors.white,
                          border: Border.all(
                            color: _method == 'bank_transfer'
                                ? AppTheme.primaryBlue
                                : Colors.grey.shade300,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: const [
                            Icon(
                              Icons.qr_code_2,
                              size: 28,
                              color: AppTheme.primaryBlue,
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Chuyển Khoản',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_method == 'bank_transfer') ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.qr_code,
                          size: 90,
                          color: AppTheme.primaryBlue,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Vietcombank: 1029384756\nChủ TK: CỬA HÀNG LAPTOP NHÓM 1\nNội dung: THANHTOAN ${widget.order.orderId}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _refCtrl,
                          decoration: const InputDecoration(
                            labelText:
                                'Mã giao dịch ngân hàng đối soát (BR-09)',
                            isDense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              TextField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Số tiền thu thực tế (VND) (BR-08)',
                  prefixIcon: Icon(Icons.payments_outlined),
                  helperText: 'Lưu ý: Hệ thống chỉ ghi nhận số tiền đúng bằng giá trị đơn hàng',
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _commitPayment,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.check_circle),
                  label: const Text('Xác Nhận Thu Tiền & Hoàn Tất Đơn (FR-21)'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _isProcessing ? null : _cancelPayment,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade300),
                  ),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text(
                    'Thoát / Quay Lại Chỉnh Sửa Đơn Hàng',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/models/sales_order.dart';
import '../../../core/models/sales_return.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/drawer_menu_button.dart';
import '../../../core/widgets/logout_button.dart';
import '../../administration/providers/administration_provider.dart';
import '../providers/sales_reports_provider.dart';
import 'return_approval_screen.dart';

class SalesReturnRequestScreen extends ConsumerStatefulWidget {
  const SalesReturnRequestScreen({super.key});

  @override
  ConsumerState<SalesReturnRequestScreen> createState() =>
      _SalesReturnRequestScreenState();
}

class _SalesReturnRequestScreenState
    extends ConsumerState<SalesReturnRequestScreen> {
  String? _selectedOrderId;
  SalesOrder? _selectedOrder;
  List<SalesOrderItem> _orderItems = [];
  final Map<String, int> _returnQuantities = {};
  final Map<String, bool> _isRestockable = {};
  final TextEditingController _reasonCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();

  List<SalesOrder> _completedOrders = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  DateTime? _startDate;
  DateTime? _endDate;
  String _datePreset = 'all'; // 'all', 'today', '7days', 'month', 'custom'

  @override
  void initState() {
    super.initState();
    _loadCompletedOrders();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCompletedOrders([String? query]) async {
    final db = await DatabaseHelper.instance.database;
    String sql = '''
      SELECT o.*, c.name as customer_name, c.phone as customer_phone
      FROM sales_orders o
      LEFT JOIN customers c ON o.customer_id = c.customer_id
      WHERE o.status = 'completed'
    ''';
    List<dynamic> args = [];
    if (query != null && query.trim().isNotEmpty) {
      sql += ' AND (o.order_id LIKE ? OR c.name LIKE ? OR c.phone LIKE ?)';
      args.addAll(['%$query%', '%$query%', '%$query%']);
    }
    if (_startDate != null) {
      final s = DateTime(
        _startDate!.year,
        _startDate!.month,
        _startDate!.day,
      ).toIso8601String();
      sql += ' AND o.created_at >= ?';
      args.add(s);
    }
    if (_endDate != null) {
      final e = DateTime(
        _endDate!.year,
        _endDate!.month,
        _endDate!.day,
        23,
        59,
        59,
      ).toIso8601String();
      sql += ' AND o.created_at <= ?';
      args.add(e);
    }
    sql += ' ORDER BY o.created_at DESC';

    final maps = await db.rawQuery(sql, args);
    if (mounted) {
      setState(() {
        _completedOrders = maps.map((m) => SalesOrder.fromMap(m)).toList();
        _isLoading = false;

        // An toàn: Nếu đơn hàng đã chọn không còn trong danh sách sau khi lọc, reset lại
        if (_selectedOrderId != null &&
            !_completedOrders.any((o) => o.orderId == _selectedOrderId)) {
          _selectedOrderId = null;
          _selectedOrder = null;
          _orderItems = [];
        }
      });
    }
  }

  void _setDatePreset(String preset) async {
    final now = DateTime.now();
    DateTime? s;
    DateTime? e;

    if (preset == 'today') {
      s = DateTime(now.year, now.month, now.day);
      e = DateTime(now.year, now.month, now.day, 23, 59, 59);
    } else if (preset == '7days') {
      s = now.subtract(const Duration(days: 7));
      e = now;
    } else if (preset == 'month') {
      s = DateTime(now.year, now.month, 1);
      e = now;
    } else if (preset == 'custom') {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2024),
        lastDate: DateTime(2030),
        initialDateRange: _startDate != null && _endDate != null
            ? DateTimeRange(start: _startDate!, end: _endDate!)
            : DateTimeRange(
                start: now.subtract(const Duration(days: 7)),
                end: now,
              ),
      );
      if (picked != null) {
        s = picked.start;
        e = picked.end;
      } else {
        return;
      }
    }

    setState(() {
      _datePreset = preset;
      _startDate = s;
      _endDate = e;
    });
    _loadCompletedOrders(_searchCtrl.text);
  }

  Future<void> _selectOrder(SalesOrder order) async {
    final db = await DatabaseHelper.instance.database;
    final itemMaps = await db.rawQuery(
      '''
      SELECT i.*, p.name as product_name, p.sku,
        (SELECT IFNULL(SUM(ri.qty), 0) FROM sales_return_items ri WHERE ri.order_item_id = i.order_item_id) as returned_qty
      FROM sales_order_items i
      JOIN products p ON i.product_id = p.product_id
      WHERE i.order_id = ?
    ''',
      [order.orderId],
    );

    final items = itemMaps.map((m) => SalesOrderItem.fromMap(m)).toList();
    if (mounted) {
      setState(() {
        _selectedOrderId = order.orderId;
        _selectedOrder = order;
        _orderItems = items;
        _returnQuantities.clear();
        _isRestockable.clear();
        for (var it in items) {
          _returnQuantities[it.orderItemId] = 0;
          _isRestockable[it.orderItemId] = true;
        }
      });
    }
  }

  double get _totalRefund {
    double sum = 0.0;
    for (var it in _orderItems) {
      final q = _returnQuantities[it.orderItemId] ?? 0;
      sum += q * it.priceSnapshot;
    }
    return sum;
  }

  bool get _isWithin7Days {
    if (_selectedOrder == null) return false;
    final orderDate =
        DateTime.tryParse(_selectedOrder!.createdAt) ?? DateTime.now();
    final diffDays = DateTime.now().difference(orderDate).inDays;
    return diffDays <= BusinessRules.salesReturnValidDays;
  }

  Future<void> _submitReturnRequest() async {
    if (_selectedOrder == null) return;
    final reason = _reasonCtrl.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập lý do đổi trả hàng')),
      );
      return;
    }

    final returnItems = <SalesReturnItem>[];
    for (var it in _orderItems) {
      final q = _returnQuantities[it.orderItemId] ?? 0;
      if (q > 0) {
        returnItems.add(
          SalesReturnItem(
            returnItemId: '',
            returnId: '',
            orderItemId: it.orderItemId,
            qty: q,
            restockable: _isRestockable[it.orderItemId] ?? true,
            refundAmount: q * it.priceSnapshot,
          ),
        );
      }
    }

    if (returnItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vui lòng chọn số lượng ít nhất 1 sản phẩm muốn đổi trả (BR-11)',
          ),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final db = await DatabaseHelper.instance.database;
      final returnId =
          'RET-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
      final now = DateTime.now().toIso8601String();

      await db.transaction((txn) async {
        for (var item in returnItems) {
          final lineRows = await txn.rawQuery(
            '''
            SELECT i.qty, IFNULL(SUM(ri.qty), 0) as already_returned
            FROM sales_order_items i
            LEFT JOIN sales_return_items ri ON i.order_item_id = ri.order_item_id
            WHERE i.order_item_id = ?
            GROUP BY i.order_item_id
          ''',
            [item.orderItemId],
          );

          final soldQty = (lineRows.first['qty'] as num).toInt();
          final prevReturned = (lineRows.first['already_returned'] as num)
              .toInt();
          final eligible = soldQty - prevReturned;

          if (item.qty > eligible) {
            throw Exception(
              '${SystemMessages.msg11} (Còn được trả tối đa: $eligible chiếc)',
            );
          }
        }

        // Insert pending return
        await txn.insert('sales_returns', {
          'return_id': returnId,
          'order_id': _selectedOrder!.orderId,
          'approved_by': null,
          'status': 'pending',
          'refund_total': _totalRefund,
          'reason': reason,
          'created_at': now,
        });

        for (var it in returnItems) {
          await txn.insert('sales_return_items', {
            'return_item_id': '${returnId}_${it.orderItemId}',
            'return_id': returnId,
            'order_item_id': it.orderItemId,
            'qty': it.qty,
            'restockable': it.restockable ? 1 : 0,
            'refund_amount': it.refundAmount,
          });
        }

        // Audit log
        final currentUser = ref.read(currentUserProvider);
        await txn.insert('audit_logs', {
          'audit_id': 'aud_${DateTime.now().millisecondsSinceEpoch}',
          'user_id': currentUser?.userId ?? 'u_sales',
          'action': 'RETURN_REQUEST_CREATED',
          'entity': 'SalesReturn',
          'details':
              '${currentUser?.fullName ?? "Nhân viên"} tạo đề xuất đổi trả #$returnId cho đơn #${_selectedOrder!.orderId}, tiền hoàn: $_totalRefund',
          'created_at': now,
        });
      });

      ref.invalidate(salesReturnsListProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã gửi yêu cầu đổi trả #$returnId chờ Quản lý/Admin duyệt (FR-26)',
          ),
          backgroundColor: AppTheme.emeraldGreen,
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ReturnApprovalScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('Tạo Yêu Cầu Đổi Trả (Trương)'),
        actions: const [LogoutIconButton()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(
                          Icons.assignment_return_outlined,
                          color: AppTheme.primaryBlue,
                        ),
                        SizedBox(width: 8),
                        Text(
                          '1. Chọn Hóa Đơn Đã Hoàn Thành (BR-10)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Filter search field
                    TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText:
                            'Tìm theo mã đơn, tên khách, số điện thoại...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchCtrl.clear();
                            _loadCompletedOrders();
                          },
                        ),
                      ),
                      onSubmitted: _loadCompletedOrders,
                    ),
                    const SizedBox(height: 10),

                    // Date filter chips
                    const Text(
                      'Lọc theo ngày bán:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text(
                              'Tất cả',
                              style: TextStyle(fontSize: 12),
                            ),
                            selected: _datePreset == 'all',
                            onSelected: (_) => _setDatePreset('all'),
                          ),
                          const SizedBox(width: 6),
                          ChoiceChip(
                            label: const Text(
                              'Hôm nay',
                              style: TextStyle(fontSize: 12),
                            ),
                            selected: _datePreset == 'today',
                            onSelected: (_) => _setDatePreset('today'),
                          ),
                          const SizedBox(width: 6),
                          ChoiceChip(
                            label: const Text(
                              '7 ngày qua (Hợp lệ BR-06)',
                              style: TextStyle(fontSize: 12),
                            ),
                            selected: _datePreset == '7days',
                            onSelected: (_) => _setDatePreset('7days'),
                          ),
                          const SizedBox(width: 6),
                          ChoiceChip(
                            label: const Text(
                              'Tháng này',
                              style: TextStyle(fontSize: 12),
                            ),
                            selected: _datePreset == 'month',
                            onSelected: (_) => _setDatePreset('month'),
                          ),
                          const SizedBox(width: 6),
                          ActionChip(
                            avatar: const Icon(Icons.date_range, size: 16),
                            label: Text(
                              _startDate != null && _endDate != null
                                  ? '${Formatters.formatDate(_startDate!)} - ${Formatters.formatDate(_endDate!)}'
                                  : 'Tùy chọn ngày',
                              style: const TextStyle(fontSize: 12),
                            ),
                            onPressed: () => _setDatePreset('custom'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Dropdown safely bound to String orderId
                    if (_completedOrders.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Row(
                          children: const [
                            Icon(
                              Icons.info_outline,
                              color: Colors.amber,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Không có hóa đơn đã hoàn thành nào trong khoảng thời gian đã chọn.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        key: ValueKey(_selectedOrderId),
                        initialValue:
                            _completedOrders.any(
                              (o) => o.orderId == _selectedOrderId,
                            )
                            ? _selectedOrderId
                            : null,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText:
                              'Danh sách hóa đơn đã hoàn thành (${_completedOrders.length})',
                          prefixIcon: const Icon(Icons.receipt_long),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          isDense: true,
                        ),
                        hint: const Text(
                          'Chọn hóa đơn cần tạo phiếu đổi trả...',
                        ),
                        items: _completedOrders.map((o) {
                          final dateStr = Formatters.formatIsoDate(o.createdAt);
                          return DropdownMenuItem<String>(
                            value: o.orderId,
                            child: Text(
                              '#${o.orderId} — ${o.customerName ?? "Khách lẻ"} (${Formatters.formatCurrency(o.total)}) • $dateStr',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          );
                        }).toList(),
                        onChanged: (orderId) {
                          if (orderId != null) {
                            final found = _completedOrders.firstWhere(
                              (o) => o.orderId == orderId,
                            );
                            _selectOrder(found);
                          } else {
                            setState(() {
                              _selectedOrderId = null;
                              _selectedOrder = null;
                              _orderItems = [];
                            });
                          }
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Order details & return items
            if (_selectedOrder != null) ...[
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '2. Chọn Sản Phẩm Đổi Trả (BR-11)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _isWithin7Days
                                  ? const Color(0xFFDCFCE7)
                                  : const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _isWithin7Days
                                  ? 'Hợp lệ trong 7 ngày (BR-06)'
                                  : 'Quá hạn 7 ngày (BR-06)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _isWithin7Days
                                    ? const Color(0xFF15803D)
                                    : const Color(0xFFB91C1C),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ngày mua: ${Formatters.formatIsoDate(_selectedOrder!.createdAt)} • Khách hàng: ${_selectedOrder!.customerName ?? "Khách lẻ"}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      const Divider(height: 20),

                      ..._orderItems.map((it) {
                        final remaining = it.remainingReturnableQty;
                        final cur = _returnQuantities[it.orderItemId] ?? 0;
                        final restockable =
                            _isRestockable[it.orderItemId] ?? true;

                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.grey.shade200),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                it.productName ?? 'Thiết bị Laptop/PC',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Đã mua: ${it.qty} máy • Giá bán: ${Formatters.formatCurrency(it.priceSnapshot)} • Còn được trả: $remaining chiếc',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),

                              Row(
                                children: [
                                  const Text(
                                    'Số lượng trả:',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                      color: Colors.red,
                                    ),
                                    onPressed: cur > 0
                                        ? () => setState(
                                            () =>
                                                _returnQuantities[it
                                                        .orderItemId] =
                                                    cur - 1,
                                          )
                                        : null,
                                  ),
                                  Text(
                                    '$cur',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.add_circle_outline,
                                      color: AppTheme.emeraldGreen,
                                    ),
                                    onPressed: cur < remaining
                                        ? () => setState(
                                            () =>
                                                _returnQuantities[it
                                                        .orderItemId] =
                                                    cur + 1,
                                          )
                                        : null,
                                  ),
                                  const Spacer(),
                                  Row(
                                    children: [
                                      const Text(
                                        'Nhập lại kho:',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      Switch(
                                        value: restockable,
                                        activeThumbColor: AppTheme.emeraldGreen,
                                        onChanged: (val) {
                                          setState(
                                            () =>
                                                _isRestockable[it.orderItemId] =
                                                    val,
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '3. Lý Do & Hoàn Tiền (BR-06)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _reasonCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Lý do đổi trả (Lỗi phần cứng / Khách đổi ý...) *',
                          hintText: 'Nhập chi tiết tình trạng máy lỗi hoặc lý do yêu cầu...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Tổng tiền hoàn dự kiến:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              Formatters.formatCurrency(_totalRefund),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: _isSubmitting
                              ? const SizedBox.shrink()
                              : const Icon(Icons.send_rounded),
                          label: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Gửi Yêu Cầu Đổi Trả (FR-24)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                          onPressed: _isSubmitting
                              ? null
                              : _submitReturnRequest,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

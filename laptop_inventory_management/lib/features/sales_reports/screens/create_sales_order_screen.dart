import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/product.dart';
import '../../../core/models/sales_order.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/drawer_menu_button.dart';
import '../../../core/widgets/logout_button.dart';
import '../../master_data/screens/customer_form_screen.dart';
import '../providers/sales_reports_provider.dart';
import 'payment_screen.dart';

class CreateSalesOrderScreen extends ConsumerStatefulWidget {
  const CreateSalesOrderScreen({super.key});

  @override
  ConsumerState<CreateSalesOrderScreen> createState() =>
      _CreateSalesOrderScreenState();
}

class _CreateSalesOrderScreenState
    extends ConsumerState<CreateSalesOrderScreen> {
  Customer? _selectedCustomer;
  bool _isWalkIn = true;
  final List<SalesOrderItem> _cart = [];
  final TextEditingController _discountController = TextEditingController(
    text: '0',
  );
  final TextEditingController _notesController = TextEditingController();

  List<Product> _products = [];
  List<Customer> _customers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = await DatabaseHelper.instance.database;
    final pMaps = await db.query(
      'products',
      where: 'is_active = 1 AND stock > 0',
    );
    final cMaps = await db.query('customers');

    if (mounted) {
      setState(() {
        _products = pMaps.map((m) => Product.fromMap(m)).toList();
        _customers = cMaps.map((m) => Customer.fromMap(m)).toList();
        _isLoading = false;
      });
    }
  }

  double get _subtotal =>
      _cart.fold<double>(0, (sum, it) => sum + (it.qty * it.priceSnapshot));
  double get _discountPercent =>
      double.tryParse(_discountController.text) ?? 0.0;
  double get _discountAmount => (_subtotal * _discountPercent) / 100.0;
  double get _total =>
      (_subtotal - _discountAmount) > 0 ? (_subtotal - _discountAmount) : 0.0;

  void _addToCart(Product p) {
    final idx = _cart.indexWhere((i) => i.productId == p.productId);
    if (idx >= 0) {
      if (_cart[idx].qty + 1 > p.stock) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tồn kho chỉ còn ${p.stock} máy (MSG-07)')),
        );
        return;
      }
      setState(() => _cart[idx] = _cart[idx].copyWith(qty: _cart[idx].qty + 1));
    } else {
      setState(() {
        _cart.add(
          SalesOrderItem(
            orderItemId: '',
            orderId: '',
            productId: p.productId,
            qty: 1,
            priceSnapshot: p.price,
            costSnapshot: p.cost,
            productName: p.name,
            productSku: p.sku,
          ),
        );
      });
    }
  }

  void _updateCartQty(int idx, int newQty) {
    if (newQty <= 0) {
      setState(() => _cart.removeAt(idx));
      return;
    }
    final it = _cart[idx];
    final prod = _products.firstWhere((p) => p.productId == it.productId);
    if (newQty > prod.stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tồn kho không đủ! Tối đa: ${prod.stock}')),
      );
      return;
    }
    setState(() => _cart[idx] = it.copyWith(qty: newQty));
  }

  Future<void> _proceed({required bool toPayment}) async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text(SystemMessages.msg06)));
      return;
    }

    try {
      final db = await DatabaseHelper.instance.database;
      final orderId =
          'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
      final now = DateTime.now().toIso8601String();

      await db.transaction((txn) async {
        await txn.insert('sales_orders', {
          'order_id': orderId,
          'customer_id': _isWalkIn ? null : _selectedCustomer?.customerId,
          'created_by': 'u_sales',
          'status': 'draft',
          'subtotal': _subtotal,
          'discount_percent': _discountPercent,
          'discount_amount': _discountAmount,
          'total': _total,
          'paid': 0.0,
          'notes': _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          'created_at': now,
        });

        for (var it in _cart) {
          await txn.insert('sales_order_items', {
            'order_item_id': '${orderId}_${it.productId}',
            'order_id': orderId,
            'product_id': it.productId,
            'qty': it.qty,
            'price_snapshot': it.priceSnapshot,
            'cost_snapshot': it.costSnapshot,
          });
        }
      });

      ref.invalidate(salesOrderListProvider);

      if (!mounted) return;
      final createdOrder = SalesOrder(
        orderId: orderId,
        customerId: _isWalkIn ? null : _selectedCustomer?.customerId,
        createdBy: 'u_sales',
        status: 'draft',
        subtotal: _subtotal,
        discountPercent: _discountPercent,
        discountAmount: _discountAmount,
        total: _total,
        paid: 0.0,
        createdAt: now,
        customerName: _selectedCustomer?.name,
        customerPhone: _selectedCustomer?.phone,
        items: _cart,
      );

      if (toPayment) {
        final paid = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) =>
                PaymentScreen(order: createdOrder, isNewOrder: true),
          ),
        );

        if (paid == true) {
          setState(() {
            _cart.clear();
            _selectedCustomer = null;
            _isWalkIn = true;
            _discountController.text = '0';
            _notesController.clear();
          });
          await _loadData();
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Đã quay lại giỏ hàng để bạn chỉnh sửa đơn.'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã lưu đơn đang xử lý #$orderId')),
        );
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          setState(() {
            _cart.clear();
            _selectedCustomer = null;
            _isWalkIn = true;
            _discountController.text = '0';
            _notesController.clear();
          });
          await _loadData();
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Future<void> _openCustomerForm([Customer? customerToEdit]) async {
    final res = await Navigator.push<Customer>(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerFormScreen(customerToEdit: customerToEdit),
      ),
    );
    if (res != null) {
      await _loadData();
      setState(() {
        _selectedCustomer = res;
        _isWalkIn = false;
      });
    }
  }

  void _showCustomerSelectionSheet() {
    String query = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final filtered = _customers.where((c) {
            final q = query.toLowerCase();
            return c.name.toLowerCase().contains(q) || c.phone.contains(q);
          }).toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Khách Hàng (Quản Lý & Gắn Đơn)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Tìm theo tên hoặc số điện thoại...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onChanged: (v) => setSheetState(() => query = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.emeraldGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 12,
                        ),
                      ),
                      icon: const Icon(Icons.person_add, size: 18),
                      label: const Text(
                        'Thêm mới',
                        style: TextStyle(fontSize: 12),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _openCustomerForm();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.grey,
                    child: Icon(Icons.person_pin, color: Colors.white),
                  ),
                  title: const Text('Khách lẻ (Vãng lai)'),
                  subtitle: const Text('Không gắn thông tin khách hàng'),
                  trailing: _isWalkIn
                      ? const Icon(Icons.check, color: AppTheme.primaryBlue)
                      : null,
                  onTap: () {
                    setState(() {
                      _isWalkIn = true;
                      _selectedCustomer = null;
                    });
                    Navigator.pop(ctx);
                  },
                ),
                const Divider(),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text('Không tìm thấy khách hàng nào'),
                        )
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final c = filtered[i];
                            final isSel =
                                !_isWalkIn &&
                                _selectedCustomer?.customerId == c.customerId;
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isSel
                                    ? AppTheme.primaryBlue
                                    : Colors.teal.shade50,
                                foregroundColor: isSel
                                    ? Colors.white
                                    : Colors.teal,
                                child: Text(
                                  c.name.isNotEmpty ? c.name[0] : 'K',
                                ),
                              ),
                              title: Text(
                                c.name,
                                style: TextStyle(
                                  fontWeight: isSel
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              subtitle: Text(
                                '${c.phone}${c.address != null ? " • ${c.address}" : ""}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit_note,
                                      color: AppTheme.primaryBlue,
                                    ),
                                    tooltip: 'Sửa thông tin khách (Minh)',
                                    onPressed: () async {
                                      Navigator.pop(ctx);
                                      await _openCustomerForm(c);
                                    },
                                  ),
                                  if (isSel)
                                    const Icon(
                                      Icons.check_circle,
                                      color: AppTheme.primaryBlue,
                                    ),
                                ],
                              ),
                              onTap: () {
                                setState(() {
                                  _isWalkIn = false;
                                  _selectedCustomer = c;
                                });
                                Navigator.pop(ctx);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('Bán Hàng & Giỏ Hàng (Trương)'),
        actions: const [LogoutIconButton()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: _isWalkIn
                          ? Colors.grey.shade400
                          : AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      child: Icon(
                        _isWalkIn ? Icons.person_pin : Icons.person,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isWalkIn
                                ? 'Khách lẻ (Vãng lai)'
                                : _selectedCustomer!.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isWalkIn
                                ? 'Chưa gắn khách hàng thành viên'
                                : 'SĐT: ${_selectedCustomer!.phone}${_selectedCustomer!.address != null ? " • ${_selectedCustomer!.address}" : ""}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (!_isWalkIn && _selectedCustomer != null)
                      IconButton(
                        icon: const Icon(
                          Icons.edit_note,
                          color: AppTheme.primaryBlue,
                        ),
                        tooltip: 'Sửa thông tin khách (Minh)',
                        onPressed: () => _openCustomerForm(_selectedCustomer),
                      ),
                    IconButton(
                      icon: const Icon(
                        Icons.person_add_alt,
                        color: AppTheme.emeraldGreen,
                      ),
                      tooltip: 'Thêm khách hàng mới (Minh)',
                      onPressed: () => _openCustomerForm(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.swap_horiz, color: Colors.indigo),
                      tooltip: 'Đổi khách hàng',
                      onPressed: _showCustomerSelectionSheet,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sản phẩm (${_cart.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (ctx) => ListView.builder(
                        itemCount: _products.length,
                        itemBuilder: (ctx, i) {
                          final p = _products[i];
                          return ListTile(
                            leading: const Icon(Icons.laptop),
                            title: Text(p.name),
                            subtitle: Text(
                              'SKU: ${p.sku} • Tồn: ${p.stock}\n${Formatters.formatCurrency(p.price)}',
                            ),
                            trailing: ElevatedButton(
                              onPressed: () {
                                _addToCart(p);
                                Navigator.pop(ctx);
                              },
                              child: const Text('Chọn'),
                            ),
                          );
                        },
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_shopping_cart, size: 18),
                  label: const Text('Thêm laptop'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_cart.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(
                    child: Text(
                      'Giỏ hàng trống. Bấm "Thêm laptop" để chọn sản phẩm.',
                    ),
                  ),
                ),
              )
            else
              ...List.generate(_cart.length, (idx) {
                final it = _cart[idx];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(
                      it.productName ?? 'Sản phẩm',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Đơn giá: ${Formatters.formatCurrency(it.priceSnapshot)}\nThành tiền: ${Formatters.formatCurrency(it.subtotal)}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => _updateCartQty(idx, it.qty - 1),
                        ),
                        Text(
                          '${it.qty}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => _updateCartQty(idx, it.qty + 1),
                        ),
                      ],
                    ),
                  ),
                );
              }),

            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Text('Chiết khấu (%): '),
                        SizedBox(
                          width: 70,
                          child: TextField(
                            controller: _discountController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              isDense: true,
                              suffixText: '%',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Ghi chú đơn hàng',
                        isDense: true,
                      ),
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tạm tính:'),
                        Text(Formatters.formatCurrency(_subtotal)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Chiết khấu ($_discountPercent%):'),
                        Text('- ${Formatters.formatCurrency(_discountAmount)}'),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TỔNG THANH TOÁN:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          Formatters.formatCurrency(_total),
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
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _proceed(toPayment: false),
                    child: const Text('Lưu Đang Xử Lý'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () => _proceed(toPayment: true),
                    icon: const Icon(Icons.payment),
                    label: const Text('Thanh Toán Ngay'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

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
import '../../administration/providers/administration_provider.dart';
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

  Map<String, dynamic>? _selectedPromotion;
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

  double get _voucherDiscountAmount {
    if (_selectedPromotion == null) return 0.0;
    final percent =
        (_selectedPromotion!['discount_percent'] as num?)?.toDouble() ?? 0.0;
    final fixedAmt =
        (_selectedPromotion!['discount_amount'] as num?)?.toDouble() ?? 0.0;
    if (percent > 0) {
      return (_subtotal * percent) / 100.0;
    }
    return fixedAmt;
  }

  double get _manualDiscountPercent =>
      double.tryParse(_discountController.text) ?? 0.0;

  double get _manualDiscountAmount =>
      (_subtotal * _manualDiscountPercent) / 100.0;

  double get _discountAmount {
    final amt = _voucherDiscountAmount + _manualDiscountAmount;
    return amt > _subtotal ? _subtotal : amt;
  }

  double get _discountPercent {
    if (_subtotal <= 0) return 0.0;
    return (_discountAmount / _subtotal) * 100.0;
  }

  double get _total =>
      (_subtotal - _discountAmount) > 0 ? (_subtotal - _discountAmount) : 0.0;

  void _validateVoucherCondition() {
    if (_selectedPromotion != null) {
      final minSpend =
          (_selectedPromotion!['min_order_spend'] as num?)?.toDouble() ?? 0.0;
      if (_subtotal < minSpend) {
        final code = _selectedPromotion!['code'];
        _selectedPromotion = null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đơn hàng chưa đạt tối thiểu ${Formatters.formatCurrency(minSpend)}. Mã $code đã tự động được gỡ bỏ.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _resetCart() {
    setState(() {
      _cart.clear();
      _selectedCustomer = null;
      _isWalkIn = true;
      _selectedPromotion = null;
      _discountController.text = '0';
      _notesController.clear();
    });
  }

  void _addToCart(Product p) {
    final idx = _cart.indexWhere((i) => i.productId == p.productId);
    if (idx >= 0) {
      if (_cart[idx].qty + 1 > p.stock) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tồn kho chỉ còn ${p.stock} máy (MSG-07)')),
        );
        return;
      }
      setState(() {
        _cart[idx] = _cart[idx].copyWith(qty: _cart[idx].qty + 1);
        _validateVoucherCondition();
      });
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
        _validateVoucherCondition();
      });
    }
  }

  void _updateCartQty(int idx, int newQty) {
    if (newQty <= 0) {
      setState(() {
        _cart.removeAt(idx);
        if (_cart.isEmpty) {
          _selectedPromotion = null;
        } else {
          _validateVoucherCondition();
        }
      });
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
    setState(() {
      _cart[idx] = it.copyWith(qty: newQty);
      _validateVoucherCondition();
    });
  }

  Future<void> _proceed({required bool toPayment}) async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text(SystemMessages.msg06)));
      return;
    }

    final currentUser = ref.read(currentUserProvider);
    final creatorId = currentUser?.userId ?? 'u_sales';

    // BR-07: Sales Staff max discount is 10%, Admin max discount is 30%
    final maxAllowedManual = currentUser?.role == 'admin'
        ? BusinessRules.maxAdminDiscountPercent
        : BusinessRules.maxSalesStaffDiscountPercent;

    if (_manualDiscountPercent > maxAllowedManual) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Chiết khấu thủ công ($_manualDiscountPercent%) vượt quá hạn mức nhân viên ($maxAllowedManual%) theo BR-07.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final db = await DatabaseHelper.instance.database;
      final orderId =
          'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
      final now = DateTime.now().toIso8601String();

      final userNote = _notesController.text.trim();
      final promoNote = _selectedPromotion != null
          ? '[Voucher: ${_selectedPromotion!['code']} - ${_selectedPromotion!['title']}]'
          : '';
      final combinedNotes =
          [userNote, promoNote].where((s) => s.isNotEmpty).join(' | ');

      await db.transaction((txn) async {
        await txn.insert('sales_orders', {
          'order_id': orderId,
          'customer_id': _isWalkIn ? null : _selectedCustomer?.customerId,
          'created_by': creatorId,
          'status': 'draft',
          'subtotal': _subtotal,
          'discount_percent': _discountPercent,
          'discount_amount': _discountAmount,
          'total': _total,
          'paid': 0.0,
          'notes': combinedNotes.isEmpty ? null : combinedNotes,
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
        createdBy: creatorId,
        status: 'draft',
        subtotal: _subtotal,
        discountPercent: _discountPercent,
        discountAmount: _discountAmount,
        total: _total,
        paid: 0.0,
        notes: combinedNotes.isEmpty ? null : combinedNotes,
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
          _resetCart();
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
          _resetCart();
          await _loadData();
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Future<void> _openVoucherSelectionSheet() async {
    final db = await DatabaseHelper.instance.database;
    final promoMaps = await db.query(
      'promotions',
      where: 'is_active = 1',
      orderBy: 'min_order_spend ASC',
    );

    if (!mounted) return;

    final voucherCodeCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void applyVoucher(Map<String, dynamic> promo) {
              final minSpend =
                  (promo['min_order_spend'] as num?)?.toDouble() ?? 0.0;
              if (_subtotal < minSpend) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Đơn hàng tối thiểu ${Formatters.formatCurrency(minSpend)} để áp dụng mã này (Hiện tại: ${Formatters.formatCurrency(_subtotal)}).',
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              setState(() {
                _selectedPromotion = promo;
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Đã áp dụng mã ưu đãi ${promo['code']} thành công!',
                  ),
                  backgroundColor: Colors.green,
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.75,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.local_offer,
                              color: AppTheme.primaryBlue,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Kho Voucher & Khuyến Mãi',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: voucherCodeCtrl,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              hintText: 'Nhập mã voucher (VD: LAPTOP2026)',
                              isDense: true,
                              prefixIcon: const Icon(
                                Icons.confirmation_number_outlined,
                                size: 20,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            final code =
                                voucherCodeCtrl.text.trim().toUpperCase();
                            if (code.isEmpty) return;
                            final found = promoMaps.firstWhere(
                              (p) =>
                                  (p['code'] as String).toUpperCase() == code,
                              orElse: () => <String, dynamic>{},
                            );
                            if (found.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Mã voucher không tồn tại hoặc đã hết hạn.',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                            applyVoucher(found);
                          },
                          child: const Text('Áp dụng'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Ưu đãi sẵn có (${promoMaps.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: promoMaps.isEmpty
                          ? const Center(
                              child: Text(
                                'Hiện không có mã khuyến mãi nào đang kích hoạt.',
                              ),
                            )
                          : ListView.separated(
                              itemCount: promoMaps.length,
                              separatorBuilder: (_, index) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (ctx, i) {
                                final promo = promoMaps[i];
                                final code = promo['code'] as String;
                                final title = promo['title'] as String;
                                final percent =
                                    (promo['discount_percent'] as num?)
                                        ?.toDouble() ??
                                    0.0;
                                final fixedAmt =
                                    (promo['discount_amount'] as num?)
                                        ?.toDouble() ??
                                    0.0;
                                final minSpend =
                                    (promo['min_order_spend'] as num?)
                                        ?.toDouble() ??
                                    0.0;
                                final validUntil =
                                    promo['valid_until']?.toString() ??
                                    '2026-12-31';

                                final isEligible = _subtotal >= minSpend;
                                final isSelected =
                                    _selectedPromotion != null &&
                                    _selectedPromotion!['promo_id'] ==
                                        promo['promo_id'];

                                final discountLabel = percent > 0
                                    ? 'Giảm ${percent.toStringAsFixed(0)}%'
                                    : 'Giảm ${Formatters.formatCurrency(fixedAmt)}';

                                return Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: isSelected
                                          ? AppTheme.primaryBlue
                                          : isEligible
                                              ? Colors.grey.shade300
                                              : Colors.grey.shade200,
                                      width: isSelected ? 2 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    color: isSelected
                                        ? AppTheme.primaryBlue.withValues(
                                            alpha: 0.05,
                                          )
                                        : isEligible
                                            ? Colors.white
                                            : Colors.grey.shade50,
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isEligible
                                              ? Colors.orange.shade50
                                              : Colors.grey.shade200,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.local_offer,
                                          color: isEligible
                                              ? Colors.orange.shade800
                                              : Colors.grey,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  code,
                                                  style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold,
                                                    fontSize: 15,
                                                    color: isEligible
                                                        ? AppTheme.primaryBlue
                                                        : Colors.grey,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: isEligible
                                                        ? Colors.red.shade50
                                                        : Colors.grey.shade200,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                    border: Border.all(
                                                      color: isEligible
                                                          ? Colors.red.shade200
                                                          : Colors.transparent,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    discountLabel,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 11,
                                                      color: isEligible
                                                          ? Colors.red.shade800
                                                          : Colors.grey,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              title,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: isEligible
                                                    ? Colors.black87
                                                    : Colors.grey,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Đơn tối thiểu: ${Formatters.formatCurrency(minSpend)} • HSD: $validUntil',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            if (!isEligible)
                                              Padding(
                                                padding:
                                                    const EdgeInsets.only(
                                                      top: 4,
                                                    ),
                                                child: Text(
                                                  'Mua thêm ${Formatters.formatCurrency(minSpend - _subtotal)} để áp dụng',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color:
                                                        Colors.orange.shade800,
                                                    fontStyle:
                                                        FontStyle.italic,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (isSelected)
                                        const Chip(
                                          avatar: Icon(
                                            Icons.check,
                                            size: 16,
                                            color: Colors.green,
                                          ),
                                          label: Text(
                                            'Đang dùng',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.green,
                                            ),
                                          ),
                                          backgroundColor: Colors.transparent,
                                          side: BorderSide(
                                            color: Colors.green,
                                          ),
                                        )
                                      else
                                        ElevatedButton(
                                          onPressed: isEligible
                                              ? () => applyVoucher(promo)
                                              : null,
                                          style: ElevatedButton.styleFrom(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 8,
                                                ),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                          child: const Text(
                                            'Dùng',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : const DrawerMenuButton(),
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
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- MÃ GIẢM GIÁ / VOUCHER ---
                    if (_selectedPromotion == null)
                      InkWell(
                        onTap: _openVoucherSelectionSheet,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.confirmation_number_outlined,
                                color: Colors.amber.shade900,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Chọn hoặc nhập mã Voucher giảm giá',
                                  style: TextStyle(
                                    color: Colors.amber.shade900,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 14,
                                color: Colors.amber.shade900,
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.verified,
                              color: Colors.green.shade700,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade700,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          _selectedPromotion!['code']
                                              .toString(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          _selectedPromotion!['title']
                                              .toString(),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Ưu đãi: -${Formatters.formatCurrency(_voucherDiscountAmount)}',
                                    style: TextStyle(
                                      color: Colors.green.shade800,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.redAccent,
                                size: 20,
                              ),
                              tooltip: 'Bỏ mã voucher',
                              onPressed: () {
                                setState(() => _selectedPromotion = null);
                              },
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),

                    // --- CHIẾT KHẤU BỔ SUNG & GHI CHÚ ---
                    Row(
                      children: [
                        const Text('Chiết khấu thêm (%): '),
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

                    // --- CHI TIẾT TÍNH TIỀN ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tạm tính:'),
                        Text(
                          Formatters.formatCurrency(_subtotal),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    if (_voucherDiscountAmount > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Voucher (${_selectedPromotion!['code']}):'),
                          Text(
                            '- ${Formatters.formatCurrency(_voucherDiscountAmount)}',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_manualDiscountAmount > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Chiết khấu thêm (${_manualDiscountPercent.toStringAsFixed(1)}%):',
                          ),
                          Text(
                            '- ${Formatters.formatCurrency(_manualDiscountAmount)}',
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_voucherDiscountAmount == 0 &&
                        _manualDiscountAmount == 0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text('Chiết khấu:'),
                          Text('- 0 đ'),
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

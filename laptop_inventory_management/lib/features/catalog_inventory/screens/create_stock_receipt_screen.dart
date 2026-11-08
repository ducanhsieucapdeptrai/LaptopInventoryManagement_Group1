import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/models/product.dart';
import '../../../core/models/stock_receipt.dart';
import '../../../core/models/supplier.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../providers/catalog_inventory_provider.dart';

class CreateStockReceiptScreen extends ConsumerStatefulWidget {
  const CreateStockReceiptScreen({super.key});

  @override
  ConsumerState<CreateStockReceiptScreen> createState() =>
      _CreateStockReceiptScreenState();
}

class _CreateStockReceiptScreenState
    extends ConsumerState<CreateStockReceiptScreen> {
  Supplier? _selectedSupplier;
  final List<StockReceiptItem> _receiptItems = [];
  final TextEditingController _notesController = TextEditingController();

  List<Product> _allProducts = [];
  List<Supplier> _allSuppliers = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final db = await DatabaseHelper.instance.database;
    final pMaps = await db.query('products', where: 'is_active = 1');
    final sMaps = await db.query('suppliers', where: 'is_active = 1');

    final prods = pMaps.map((m) => Product.fromMap(m)).toList();
    final sups = sMaps.map((m) => Supplier.fromMap(m)).toList();

    if (mounted) {
      setState(() {
        _allProducts = prods;
        _allSuppliers = sups;
        if (sups.isNotEmpty) _selectedSupplier = sups.first;
        _isLoading = false;
      });
    }
  }

  double get _totalCost {
    return _receiptItems.fold<double>(0, (sum, i) => sum + i.subtotal);
  }

  void _showAddProductDialog() {
    Product? chosenProd = _allProducts.isNotEmpty ? _allProducts.first : null;
    final qtyCtrl = TextEditingController(text: '5');
    final costCtrl = TextEditingController(
      text: chosenProd != null ? chosenProd.cost.toStringAsFixed(0) : '',
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return AlertDialog(
              title: const Text('Thêm Sản Phẩm Nhập Kho'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<Product>(
                      initialValue: chosenProd,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Chọn laptop / PC',
                        isDense: true,
                      ),
                      items: _allProducts
                          .map(
                            (p) => DropdownMenuItem(
                              value: p,
                              child: Text('${p.sku} - ${p.name}'),
                            ),
                          )
                          .toList(),
                      onChanged: (p) {
                        if (p != null) {
                          setDlgState(() {
                            chosenProd = p;
                            costCtrl.text = p.cost.toStringAsFixed(0);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Số lượng nhập (>0) * (MSG-06)',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: costCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Đơn giá vốn nhập (VND) *',
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                    final cost =
                        double.tryParse(
                          costCtrl.text.replaceAll(RegExp(r'[^0-9.]'), ''),
                        ) ??
                        0.0;
                    if (chosenProd == null || qty <= 0 || cost < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text(SystemMessages.msg06)),
                      );
                      return;
                    }

                    setState(() {
                      _receiptItems.add(
                        StockReceiptItem(
                          receiptItemId: const Uuid().v4(),
                          receiptId: '',
                          productId: chosenProd!.productId,
                          qty: qty,
                          unitCost: cost,
                          productName: chosenProd!.name,
                          productSku: chosenProd!.sku,
                        ),
                      );
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('Thêm vào phiếu'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveReceipt() async {
    if (_selectedSupplier == null || _receiptItems.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text(SystemMessages.msg06)));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final db = await DatabaseHelper.instance.database;
      final receiptId =
          'RCPT-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
      final now = DateTime.now().toIso8601String();

      await db.transaction((txn) async {
        await txn.insert('stock_receipts', {
          'receipt_id': receiptId,
          'supplier_id': _selectedSupplier!.supplierId,
          'created_by': 'u_truong',
          'status': 'draft',
          'received_at': now,
          'total_cost': _totalCost,
          'notes': _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        });

        for (var it in _receiptItems) {
          await txn.insert('stock_receipt_items', {
            'receipt_item_id': const Uuid().v4(),
            'receipt_id': receiptId,
            'product_id': it.productId,
            'qty': it.qty,
            'unit_cost': it.unitCost,
          });
        }
      });

      ref.invalidate(catalogReceiptsProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã tạo thành công phiếu nhập #$receiptId (Draft)'),
          backgroundColor: AppTheme.emeraldGreen,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Tạo Phiếu Nhập Kho (Trường)')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nhà cung cấp (FR-09)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<Supplier>(
                      initialValue: _selectedSupplier,
                      isExpanded: true,
                      decoration: const InputDecoration(isDense: true),
                      items: _allSuppliers
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text('${s.name} (${s.phone})'),
                            ),
                          )
                          .toList(),
                      onChanged: (s) => setState(() => _selectedSupplier = s),
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
                  'Sản phẩm nhập (${_receiptItems.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showAddProductDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Thêm máy'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_receiptItems.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.inventory_outlined,
                          size: 40,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Chưa có mặt hàng nào trong phiếu nhập',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ...List.generate(_receiptItems.length, (idx) {
                final it = _receiptItems[idx];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(
                      it.productName ?? 'Sản phẩm',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'SKU: ${it.productSku}\n${it.qty} x ${Formatters.formatCurrency(it.unitCost)} = ${Formatters.formatCurrency(it.subtotal)}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () =>
                          setState(() => _receiptItems.removeAt(idx)),
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
                    TextField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Ghi chú đơn nhập / Hóa đơn chứng từ',
                        isDense: true,
                      ),
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TỔNG TIỀN VỐN:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          Formatters.formatCurrency(_totalCost),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppTheme.emeraldGreen,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveReceipt,
                icon: const Icon(Icons.save),
                label: const Text('Lưu Phiếu Nhập Kho (Draft FR-10)'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

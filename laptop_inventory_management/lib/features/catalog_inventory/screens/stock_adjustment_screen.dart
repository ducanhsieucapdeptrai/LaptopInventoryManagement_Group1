// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/models/product.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../providers/catalog_inventory_provider.dart';

class StockAdjustmentScreen extends ConsumerStatefulWidget {
  const StockAdjustmentScreen({super.key});

  @override
  ConsumerState<StockAdjustmentScreen> createState() =>
      _StockAdjustmentScreenState();
}

class _StockAdjustmentScreenState extends ConsumerState<StockAdjustmentScreen> {
  final _formKey = GlobalKey<FormState>();
  Product? _selectedProduct;
  String _adjustmentType = 'increase';
  final TextEditingController _qtyController = TextEditingController(text: '1');
  final TextEditingController _reasonController = TextEditingController();

  List<Product> _products = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'products',
      where: 'is_active = 1',
      orderBy: 'name ASC',
    );
    final prods = maps.map((m) => Product.fromMap(m)).toList();
    if (mounted) {
      setState(() {
        _products = prods;
        if (prods.isNotEmpty) _selectedProduct = prods.first;
        _isLoading = false;
      });
    }
  }

  int get _deltaQty {
    final q = int.tryParse(_qtyController.text.trim()) ?? 0;
    return _adjustmentType == 'increase' ? q : -q;
  }

  int get _calculatedNewStock {
    if (_selectedProduct == null) return 0;
    return _selectedProduct!.stock + _deltaQty;
  }

  Future<void> _submitAdjustment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProduct == null) return;

    if (_calculatedNewStock < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '${SystemMessages.msg07} Không được để tồn kho âm (BR-03)',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now().toIso8601String();

      await db.transaction((txn) async {
        await txn.update(
          'products',
          {'stock': _calculatedNewStock},
          where: 'product_id = ?',
          whereArgs: [_selectedProduct!.productId],
        );
        await txn.insert('stock_movements', {
          'movement_id': 'mov_${DateTime.now().millisecondsSinceEpoch}',
          'product_id': _selectedProduct!.productId,
          'created_by': 'u_truong',
          'type': _deltaQty >= 0 ? 'adjustment_in' : 'adjustment_out',
          'qty_delta': _deltaQty,
          'ref': 'Kiểm kê: ${_reasonController.text.trim()}',
          'created_at': now,
        });

        await txn.insert('audit_logs', {
          'audit_id': const Uuid().v4(),
          'user_id': 'u_truong',
          'action': 'STOCK_ADJUSTMENT',
          'entity': 'Product',
          'details':
              'Điều chỉnh tồn kho ${_selectedProduct!.name}: ${_selectedProduct!.stock} -> $_calculatedNewStock. Lý do: ${_reasonController.text.trim()}',
          'created_at': now,
        });
      });

      ref.invalidate(catalogProductsProvider);
      ref.invalidate(catalogMovementsProvider);
      ref.invalidate(catalogLowStockAlertsProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã cập nhật tồn kho mới: $_calculatedNewStock chiếc'),
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
      appBar: AppBar(title: const Text('Kiểm Kê Điều Chỉnh Kho (Trường)')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
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
                        'Chọn thiết bị kiểm đếm',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<Product>(
                        initialValue: _selectedProduct,
                        isExpanded: true,
                        decoration: const InputDecoration(isDense: true),
                        items: _products
                            .map(
                              (p) => DropdownMenuItem(
                                value: p,
                                child: Text(
                                  '${p.sku} - ${p.name} (Tồn: ${p.stock})',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (p) => setState(() => _selectedProduct = p),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hình thức điều chỉnh (FR-12)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              dense: true,
                              title: const Text('Tăng (+)'),
                              value: 'increase',
                              groupValue: _adjustmentType,
                              onChanged: (v) =>
                                  setState(() => _adjustmentType = v!),
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              dense: true,
                              title: const Text('Hao hụt (-)'),
                              value: 'decrease',
                              groupValue: _adjustmentType,
                              onChanged: (v) =>
                                  setState(() => _adjustmentType = v!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _qtyController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Số lượng thay đổi * (MSG-06)',
                          isDense: true,
                        ),
                        validator: (v) =>
                            Validators.positiveNumber(v, 'Số lượng'),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _calculatedNewStock < 0
                              ? Colors.red.shade50
                              : AppTheme.primaryBlue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Tồn kho sau điều chỉnh:'),
                            Text(
                              '$_calculatedNewStock chiếc',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: _calculatedNewStock < 0
                                    ? Colors.red
                                    : AppTheme.primaryBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Lý do kiểm kê điều chỉnh * (Bắt buộc FR-12)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _reasonController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          hintText: 'VD: Kiểm đếm cuối kỳ thừa 1 máy do NCC giao bù...',
                          isDense: true,
                        ),
                        validator: (v) => Validators.requiredField(v, 'Lý do'),
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
                  onPressed: _isSaving ? null : _submitAdjustment,
                  icon: const Icon(Icons.check),
                  label: const Text('Xác Nhận & Ghi Sổ Kiểm Kê'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

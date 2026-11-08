import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/models/category.dart';
import '../../../core/models/product.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../providers/catalog_inventory_provider.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final Product? productToEdit;

  const ProductFormScreen({super.key, this.productToEdit});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _skuController;
  late final TextEditingController _nameController;
  late final TextEditingController _brandController;
  late final TextEditingController _specsController;
  late final TextEditingController _priceController;
  late final TextEditingController _costController;
  late final TextEditingController _stockController;
  late final TextEditingController _thresholdController;

  String? _selectedCategoryId;
  List<Category> _categories = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.productToEdit;
    _skuController = TextEditingController(text: p?.sku ?? '');
    _nameController = TextEditingController(text: p?.name ?? '');
    _brandController = TextEditingController(text: p?.brand ?? '');
    _specsController = TextEditingController(text: p?.specs ?? '');
    _priceController = TextEditingController(
      text: p != null ? p.price.toStringAsFixed(0) : '',
    );
    _costController = TextEditingController(
      text: p != null ? p.cost.toStringAsFixed(0) : '',
    );
    _stockController = TextEditingController(
      text: p != null ? p.stock.toString() : '0',
    );
    _thresholdController = TextEditingController(
      text: p != null ? p.alertThreshold.toString() : '5',
    );
    _selectedCategoryId = p?.categoryId;

    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'categories',
      where: 'is_active = 1',
      orderBy: 'name ASC',
    );
    final cats = maps.map((m) => Category.fromMap(m)).toList();
    if (mounted) {
      setState(() {
        _categories = cats;
        if (_selectedCategoryId == null && cats.isNotEmpty) {
          _selectedCategoryId = cats.first.categoryId;
        }
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _skuController.dispose();
    _nameController.dispose();
    _brandController.dispose();
    _specsController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _stockController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vui lòng chọn danh mục')));
      return;
    }

    final price =
        double.tryParse(
          _priceController.text.replaceAll(RegExp(r'[^0-9.]'), ''),
        ) ??
        0.0;
    final cost =
        double.tryParse(
          _costController.text.replaceAll(RegExp(r'[^0-9.]'), ''),
        ) ??
        0.0;
    final stock =
        int.tryParse(_stockController.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
        0;
    final threshold =
        int.tryParse(
          _thresholdController.text.replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        5;

    setState(() => _isSaving = true);

    try {
      final db = await DatabaseHelper.instance.database;
      final isNew = widget.productToEdit == null;
      final sku = _skuController.text.trim().toUpperCase();

      // BR-01: SKU uniqueness check
      if (isNew) {
        final existing = await db.query(
          'products',
          where: 'sku = ?',
          whereArgs: [sku],
        );
        if (existing.isNotEmpty) throw Exception(SystemMessages.msg05);
      } else {
        final existing = await db.query(
          'products',
          where: 'sku = ? AND product_id != ?',
          whereArgs: [sku, widget.productToEdit!.productId],
        );
        if (existing.isNotEmpty) throw Exception(SystemMessages.msg05);
      }

      final prod = Product(
        productId: widget.productToEdit?.productId ?? const Uuid().v4(),
        categoryId: _selectedCategoryId!,
        sku: sku,
        name: _nameController.text.trim(),
        brand: _brandController.text.trim(),
        specs: _specsController.text.trim(),
        price: price,
        cost: cost,
        stock: stock,
        alertThreshold: threshold,
        isActive: widget.productToEdit?.isActive ?? true,
      );

      if (isNew) {
        await db.insert('products', prod.toMap());
      } else {
        await db.update(
          'products',
          prod.toMap(),
          where: 'product_id = ?',
          whereArgs: [prod.productId],
        );
      }

      ref.invalidate(catalogProductsProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã lưu thành công sản phẩm ${prod.name}'),
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

    final isEdit = widget.productToEdit != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEdit ? 'Sửa Sản Phẩm (Trường)' : 'Thêm Laptop / PC (Trường)',
        ),
      ),
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
                        'Thông số định danh (FR-06)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _skuController,
                        decoration: const InputDecoration(
                          labelText: 'Mã SKU duy nhất * (BR-01, MSG-05)',
                          hintText: 'VD: LAP-ROG-G16',
                          isDense: true,
                        ),
                        validator: Validators.sku,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Tên dòng máy *',
                          hintText: 'VD: Asus ROG Strix G16 2024',
                          isDense: true,
                        ),
                        validator: (v) =>
                            Validators.requiredField(v, 'Tên sản phẩm'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _brandController,
                              decoration: const InputDecoration(
                                labelText: 'Hãng sản xuất *',
                                hintText: 'VD: Asus, Apple, Dell',
                                isDense: true,
                              ),
                              validator: (v) =>
                                  Validators.requiredField(v, 'Hãng'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedCategoryId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Loại sản phẩm *',
                                isDense: true,
                              ),
                              items: _categories
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c.categoryId,
                                      child: Text(c.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (id) =>
                                  setState(() => _selectedCategoryId = id),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _specsController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Thông số kỹ thuật (CPU / RAM / SSD / VGA / Màn hình) *',
                          hintText: 'VD: Intel i7-13650HX / 16GB DDR5 / 512GB SSD / RTX 4060 8GB',
                          isDense: true,
                        ),
                        validator: (v) =>
                            Validators.requiredField(v, 'Thông số kỹ thuật'),
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
                        'Giá thành & Tồn kho (BR-02)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _priceController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Giá bán niêm yết (VND) *',
                                isDense: true,
                              ),
                              validator: (v) =>
                                  Validators.positiveNumber(v, 'Giá bán'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _costController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Giá vốn nhập (VND) *',
                                isDense: true,
                              ),
                              validator: (v) =>
                                  Validators.nonNegativeNumber(v, 'Giá vốn'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _stockController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Số lượng tồn *',
                                isDense: true,
                              ),
                              validator: (v) =>
                                  Validators.nonNegativeNumber(v, 'Tồn kho'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _thresholdController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Ngưỡng cảnh báo hết *',
                                isDense: true,
                              ),
                              validator: (v) => Validators.nonNegativeNumber(
                                v,
                                'Ngưỡng cảnh báo',
                              ),
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
                  onPressed: _isSaving ? null : _saveProduct,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: const Text('Lưu Sản Phẩm'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/models/category.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../providers/master_data_provider.dart';

class CategoryFormScreen extends ConsumerStatefulWidget {
  final Category? categoryToEdit;

  const CategoryFormScreen({super.key, this.categoryToEdit});

  @override
  ConsumerState<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends ConsumerState<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.categoryToEdit?.name ?? '',
    );
    _descController = TextEditingController(
      text: widget.categoryToEdit?.description ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _saveCategory() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final db = await DatabaseHelper.instance.database;
      final isNew = widget.categoryToEdit == null;

      final cat = Category(
        categoryId:
            widget.categoryToEdit?.categoryId ??
            'cat_${const Uuid().v4().substring(0, 8)}',
        name: _nameController.text.trim(),
        description: _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
      );

      if (isNew) {
        await db.insert('categories', cat.toMap());
      } else {
        await db.update(
          'categories',
          cat.toMap(),
          where: 'category_id = ?',
          whereArgs: [cat.categoryId],
        );
      }

      ref.invalidate(masterCategoriesProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã lưu danh mục ${cat.name}'),
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
    final isEdit = widget.categoryToEdit != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Sửa Danh Mục (Minh)' : 'Thêm Danh Mục (Minh)'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Tên danh mục loại máy * (FR-05)',
                          isDense: true,
                        ),
                        validator: (v) =>
                            Validators.requiredField(v, 'Tên danh mục'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Mô tả tóm tắt',
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveCategory,
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
                  label: const Text('Lưu Danh Mục'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

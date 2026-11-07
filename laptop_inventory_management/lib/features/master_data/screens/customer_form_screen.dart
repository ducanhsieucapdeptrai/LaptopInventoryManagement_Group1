import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/models/customer.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../providers/master_data_provider.dart';

class CustomerFormScreen extends ConsumerStatefulWidget {
  final Customer? customerToEdit;

  const CustomerFormScreen({super.key, this.customerToEdit});

  @override
  ConsumerState<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends ConsumerState<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.customerToEdit;
    _nameController = TextEditingController(text: c?.name ?? '');
    _phoneController = TextEditingController(text: c?.phone ?? '');
    _emailController = TextEditingController(text: c?.email ?? '');
    _addressController = TextEditingController(text: c?.address ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final db = await DatabaseHelper.instance.database;
      final isNew = widget.customerToEdit == null;

      final cust = Customer(
        customerId: widget.customerToEdit?.customerId ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        totalOrders: widget.customerToEdit?.totalOrders ?? 0,
        totalSpent: widget.customerToEdit?.totalSpent ?? 0.0,
      );

      if (isNew) {
        await db.insert('customers', cust.toMap());
      } else {
        await db.update(
          'customers',
          cust.toMap(),
          where: 'customer_id = ?',
          whereArgs: [cust.customerId],
        );
      }

      ref.invalidate(masterCustomersProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã lưu thông tin khách hàng ${cust.name}'),
          backgroundColor: AppTheme.emeraldGreen,
        ),
      );
      Navigator.pop(context, cust);
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
    final isEdit = widget.customerToEdit != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEdit ? 'Sửa Khách Hàng (Minh)' : 'Thêm Khách Hàng (Minh)',
        ),
      ),
      body: SingleChildScrollView(
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
                          labelText: 'Họ và tên khách hàng * (FR-15)',
                          isDense: true,
                        ),
                        validator: (v) => Validators.requiredField(v, 'Họ tên'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Số điện thoại *',
                          isDense: true,
                        ),
                        validator: (v) =>
                            Validators.phoneNumber(v) ??
                            Validators.requiredField(v, 'Số điện thoại'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(
                          labelText: 'Địa chỉ nhận hàng',
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
                  onPressed: _isSaving ? null : _saveCustomer,
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
                  label: const Text('Lưu Thông Tin Khách Hàng'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

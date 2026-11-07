import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/drawer_menu_button.dart';
import '../../../core/widgets/logout_button.dart';
import '../providers/administration_provider.dart';

class StoreSettingsScreen extends ConsumerStatefulWidget {
  const StoreSettingsScreen({super.key});

  @override
  ConsumerState<StoreSettingsScreen> createState() =>
      _StoreSettingsScreenState();
}

class _StoreSettingsScreenState extends ConsumerState<StoreSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;

  late TextEditingController _nameController;
  late TextEditingController _taxController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _vatController;
  late TextEditingController _warrantyController;
  late TextEditingController _footerController;
  late TextEditingController _thresholdController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _taxController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _addressController = TextEditingController();
    _vatController = TextEditingController(text: '8.0');
    _warrantyController = TextEditingController(text: '24');
    _footerController = TextEditingController();
    _thresholdController = TextEditingController(text: '5');
    _loadSettings();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _taxController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _vatController.dispose();
    _warrantyController.dispose();
    _footerController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'store_settings',
      where: 'id = ?',
      whereArgs: ['default_shop'],
    );
    if (rows.isNotEmpty) {
      final s = rows.first;
      _nameController.text = s['store_name']?.toString() ?? '';
      _taxController.text = s['tax_code']?.toString() ?? '';
      _phoneController.text = s['phone']?.toString() ?? '';
      _emailController.text = s['email']?.toString() ?? '';
      _addressController.text = s['address']?.toString() ?? '';
      _vatController.text =
          (s['vat_percent'] as num?)?.toStringAsFixed(1) ?? '8.0';
      _warrantyController.text =
          s['default_warranty_months']?.toString() ?? '24';
      _footerController.text = s['invoice_footer']?.toString() ?? '';
      _thresholdController.text = s['low_stock_threshold']?.toString() ?? '5';
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final db = await DatabaseHelper.instance.database;
      final vat = double.tryParse(_vatController.text.trim()) ?? 8.0;
      final warranty = int.tryParse(_warrantyController.text.trim()) ?? 24;
      final threshold = int.tryParse(_thresholdController.text.trim()) ?? 5;

      await db.insert('store_settings', {
        'id': 'default_shop',
        'store_name': _nameController.text.trim(),
        'tax_code': _taxController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'address': _addressController.text.trim(),
        'vat_percent': vat,
        'default_warranty_months': warranty,
        'invoice_footer': _footerController.text.trim(),
        'low_stock_threshold': threshold,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await db.insert('audit_logs', {
        'audit_id': DateTime.now().millisecondsSinceEpoch.toString(),
        'user_id': ref.read(currentUserProvider)?.userId ?? 'u_admin',
        'action': 'SETTINGS_UPDATED',
        'entity': 'StoreSettings',
        'details': 'Cập nhật cấu hình cửa hàng: ${_nameController.text.trim()}',
        'created_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã lưu cấu hình cửa hàng & hóa đơn thành công!'),
          backgroundColor: AppTheme.emeraldGreen,
        ),
      );
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
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('Cài Đặt Cửa Hàng & Hóa Đơn (Đức Anh)'),
        actions: const [LogoutIconButton()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
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
                      Row(
                        children: const [
                          Icon(Icons.storefront, color: AppTheme.primaryBlue),
                          SizedBox(width: 8),
                          Text(
                            'Thông Tin Showroom Laptop/PC',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Tên cửa hàng / Showroom *',
                          prefixIcon: Icon(Icons.business),
                        ),
                        validator: (v) =>
                            Validators.requiredField(v, 'Tên cửa hàng'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _taxController,
                              decoration: const InputDecoration(
                                labelText: 'Mã số thuế (MST) *',
                                prefixIcon: Icon(Icons.badge_outlined),
                              ),
                              validator: (v) =>
                                  Validators.requiredField(v, 'Mã số thuế'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _phoneController,
                              decoration: const InputDecoration(
                                labelText: 'Hotline *',
                                prefixIcon: Icon(Icons.phone),
                              ),
                              validator: Validators.phoneNumber,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email liên hệ',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(
                          labelText: 'Địa chỉ cửa hàng *',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                        validator: (v) =>
                            Validators.requiredField(v, 'Địa chỉ'),
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
                      Row(
                        children: const [
                          Icon(Icons.receipt_long, color: AppTheme.accentCyan),
                          SizedBox(width: 8),
                          Text(
                            'Chính Sách Bán Hàng & In Hóa Đơn POS',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _vatController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Thuế VAT mặc định (%)',
                                prefixIcon: Icon(Icons.percent),
                              ),
                              validator: (v) =>
                                  Validators.positiveNumber(v, 'Thuế VAT'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _warrantyController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Bảo hành mặc định (Tháng)',
                                prefixIcon: Icon(Icons.verified_outlined),
                              ),
                              validator: (v) => Validators.positiveNumber(
                                v,
                                'Thời hạn bảo hành',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _thresholdController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText:
                              'Ngưỡng cảnh báo tồn kho tối thiểu (Chiếc)',
                          prefixIcon: Icon(Icons.warning_amber_rounded),
                        ),
                        validator: (v) =>
                            Validators.positiveNumber(v, 'Ngưỡng tồn kho'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _footerController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Lời cảm ơn trên chân trang hóa đơn in',
                          prefixIcon: Icon(Icons.notes),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

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
                  icon: _isSaving
                      ? const SizedBox.shrink()
                      : const Icon(Icons.save),
                  label: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Lưu Thiết Lập Cửa Hàng',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                  onPressed: _isSaving ? null : _saveSettings,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

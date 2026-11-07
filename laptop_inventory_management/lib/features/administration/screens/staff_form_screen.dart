import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/models/app_user.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../providers/administration_provider.dart';

class StaffFormScreen extends ConsumerStatefulWidget {
  final AppUser? userToEdit;

  const StaffFormScreen({super.key, this.userToEdit});

  @override
  ConsumerState<StaffFormScreen> createState() => _StaffFormScreenState();
}

class _StaffFormScreenState extends ConsumerState<StaffFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _nameController;
  late String _selectedRole;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final u = widget.userToEdit;
    _usernameController = TextEditingController(text: u?.username ?? '');
    _passwordController = TextEditingController();
    _nameController = TextEditingController(text: u?.fullName ?? '');
    _selectedRole = u?.role ?? AppRoles.salesStaff;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;

    final isNew = widget.userToEdit == null;
    if (isNew && _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập mật khẩu cho nhân viên mới'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final db = await DatabaseHelper.instance.database;
      final currentAdmin = ref.read(currentUserProvider);

      if (isNew) {
        final existing = await db.query(
          'app_users',
          where: 'username = ?',
          whereArgs: [_usernameController.text.trim()],
        );
        if (existing.isNotEmpty) {
          throw Exception(
            'Tên đăng nhập đã tồn tại! Vui lòng chọn username khác.',
          );
        }

        final newUser = AppUser(
          userId: 'u_${const Uuid().v4().substring(0, 8)}',
          username: _usernameController.text.trim(),
          passwordHash: DatabaseHelper.hashPassword(
            _passwordController.text.trim(),
          ),
          role: _selectedRole,
          fullName: _nameController.text.trim(),
          isActive: true,
        );

        await db.insert('app_users', newUser.toMap());
        await db.insert('audit_logs', {
          'audit_id': DateTime.now().millisecondsSinceEpoch.toString(),
          'user_id': currentAdmin?.userId ?? 'u_admin',
          'action': 'USER_CREATED',
          'entity': 'AppUser',
          'details':
              'Tạo tài khoản: ${newUser.username} - Quyền: ${newUser.role}',
          'created_at': DateTime.now().toIso8601String(),
        });
      } else {
        final updateMap = <String, dynamic>{
          'full_name': _nameController.text.trim(),
          'role': _selectedRole,
        };
        if (_passwordController.text.trim().isNotEmpty) {
          updateMap['password_hash'] = DatabaseHelper.hashPassword(
            _passwordController.text.trim(),
          );
        }

        await db.update(
          'app_users',
          updateMap,
          where: 'user_id = ?',
          whereArgs: [widget.userToEdit!.userId],
        );
        await db.insert('audit_logs', {
          'audit_id': DateTime.now().millisecondsSinceEpoch.toString(),
          'user_id': currentAdmin?.userId ?? 'u_admin',
          'action': 'USER_UPDATED',
          'entity': 'AppUser',
          'details': 'Cập nhật tài khoản: ${widget.userToEdit!.username}',
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      ref.invalidate(adminStaffListProvider);
      ref.invalidate(adminAuditLogsProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã lưu thành công nhân viên ${_nameController.text.trim()}',
          ),
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
    final isEdit = widget.userToEdit != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEdit ? 'Sửa Nhân Viên (Đức Anh)' : 'Thêm Nhân Viên (Đức Anh)',
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
                        'Thông tin nhân sự (FR-30)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Họ và tên *',
                          isDense: true,
                        ),
                        validator: (v) => Validators.requiredField(v, 'Họ tên'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _usernameController,
                        enabled: !isEdit,
                        decoration: const InputDecoration(
                          labelText: 'Tên đăng nhập (Username) *',
                          isDense: true,
                        ),
                        validator: (v) =>
                            Validators.requiredField(v, 'Tên đăng nhập'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: isEdit
                              ? 'Mật khẩu mới (Bỏ trống nếu không đổi)'
                              : 'Mật khẩu khởi tạo * (Salted SHA-256 NFR-03)',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedRole,
                        decoration: const InputDecoration(
                          labelText: 'Phân quyền vai trò (FR-02) *',
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: AppRoles.salesStaff,
                            child: Text('Nhân viên bán hàng (Sales Staff)'),
                          ),
                          DropdownMenuItem(
                            value: AppRoles.inventoryStaff,
                            child: Text('Nhân viên kho (Inventory Staff)'),
                          ),
                          DropdownMenuItem(
                            value: AppRoles.admin,
                            child: Text('Quản trị viên (Store Admin)'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedRole = val);
                        },
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
                  onPressed: _isSaving ? null : _saveUser,
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
                  label: Text(
                    _isSaving ? 'Đang lưu...' : 'Lưu Tài Khoản Nhân Viên',
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell_screen.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/models/app_user.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/administration_provider.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _usernameController = TextEditingController(text: 'admin');
  final _passwordController = TextEditingController(text: 'admin123');
  bool _obscurePassword = true;
  bool _isLoading = false;
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    // BR-12: Account lockout policy (5 failed attempts -> 15 min lock)
    if (_lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!)) {
      final remaining = _lockoutUntil!.difference(DateTime.now()).inMinutes + 1;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${SystemMessages.msg04} (Còn $remaining phút)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(SystemMessages.msg01),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final db = await DatabaseHelper.instance.database;
      final hashedInput = DatabaseHelper.hashPassword(password);

      final userRows = await db.query(
        'app_users',
        where: 'username = ?',
        whereArgs: [username],
      );

      if (userRows.isEmpty || userRows.first['password_hash'] != hashedInput) {
        _failedAttempts++;
        if (_failedAttempts >= BusinessRules.maxLoginAttempts) {
          _lockoutUntil = DateTime.now().add(
            const Duration(minutes: BusinessRules.lockoutMinutes),
          );
          throw Exception(SystemMessages.msg04);
        }
        throw Exception(SystemMessages.msg02);
      }

      final user = AppUser.fromMap(userRows.first);

      if (!user.isActive) {
        throw Exception(SystemMessages.msg03);
      }

      _failedAttempts = 0;
      _lockoutUntil = null;

      ref.read(currentUserProvider.notifier).state = user;
      if (user.role == AppRoles.masterData) {
        ref.read(activeWorkspaceProvider.notifier).state = 'minh';
      } else if (user.role == AppRoles.inventoryStaff) {
        ref.read(activeWorkspaceProvider.notifier).state = 'truong';
      } else if (user.role == AppRoles.salesStaff) {
        ref.read(activeWorkspaceProvider.notifier).state = 'sales';
      } else {
        ref.read(activeWorkspaceProvider.notifier).state = 'ducanh';
      }

      await db.insert('audit_logs', {
        'audit_id': DateTime.now().millisecondsSinceEpoch.toString(),
        'user_id': user.userId,
        'action': 'LOGIN_SUCCESS',
        'entity': 'AppUser',
        'details':
            'Đăng nhập thành công vai trò: ${user.role} (${user.fullName})',
        'created_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ShellScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _quickLogin(String username, String pass) {
    _usernameController.text = username;
    _passwordController.text = pass;
    _handleLogin();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryBlue,
              AppTheme.primaryBlue.withValues(alpha: 0.85),
              const Color(0xFF0F172A),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.laptop_chromebook,
                          size: 48,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'LAPTOP & PC SHOP (LPSM)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'PRM393 — Nhóm 1 (Đức Anh, Minh, Trường, Trương)',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 24),

                      TextField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Tên đăng nhập',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 14),

                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                        onSubmitted: (_) => _handleLogin(),
                      ),
                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Đăng Nhập (UC-01)',
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Đăng nhập nhanh theo phân hệ 4 thành viên:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                            horizontal: 8,
                                          ),
                                          side: BorderSide(
                                            color: AppTheme.primaryBlue
                                                .withValues(alpha: 0.5),
                                          ),
                                          alignment: Alignment.centerLeft,
                                        ),
                                        icon: const Icon(
                                          Icons.admin_panel_settings,
                                          size: 18,
                                          color: AppTheme.primaryBlue,
                                        ),
                                        label: const Text(
                                          '1. Đức Anh\n(Quản trị)',
                                          style: TextStyle(
                                            fontSize: 11,
                                            height: 1.2,
                                          ),
                                        ),
                                        onPressed: () =>
                                            _quickLogin('admin', 'admin123'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                            horizontal: 8,
                                          ),
                                          side: BorderSide(
                                            color: Colors.teal.withValues(
                                              alpha: 0.5,
                                            ),
                                          ),
                                          alignment: Alignment.centerLeft,
                                        ),
                                        icon: const Icon(
                                          Icons.category,
                                          size: 18,
                                          color: Colors.teal,
                                        ),
                                        label: const Text(
                                          '2. Minh\n(Master Data)',
                                          style: TextStyle(
                                            fontSize: 11,
                                            height: 1.2,
                                          ),
                                        ),
                                        onPressed: () =>
                                            _quickLogin('minh', 'minh123'),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                            horizontal: 8,
                                          ),
                                          side: BorderSide(
                                            color: Colors.orange.withValues(
                                              alpha: 0.5,
                                            ),
                                          ),
                                          alignment: Alignment.centerLeft,
                                        ),
                                        icon: const Icon(
                                          Icons.warehouse,
                                          size: 18,
                                          color: Colors.orange,
                                        ),
                                        label: const Text(
                                          '3. Trường\n(Kho hàng)',
                                          style: TextStyle(
                                            fontSize: 11,
                                            height: 1.2,
                                          ),
                                        ),
                                        onPressed: () =>
                                            _quickLogin('truong', 'truong123'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                            horizontal: 8,
                                          ),
                                          side: BorderSide(
                                            color: AppTheme.emeraldGreen
                                                .withValues(alpha: 0.5),
                                          ),
                                          alignment: Alignment.centerLeft,
                                        ),
                                        icon: const Icon(
                                          Icons.point_of_sale,
                                          size: 18,
                                          color: AppTheme.emeraldGreen,
                                        ),
                                        label: const Text(
                                          '4. Trương\n(Bán hàng POS)',
                                          style: TextStyle(
                                            fontSize: 11,
                                            height: 1.2,
                                          ),
                                        ),
                                        onPressed: () =>
                                            _quickLogin('sales', 'sales123'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

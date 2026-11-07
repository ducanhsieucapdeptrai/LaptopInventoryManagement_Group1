import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/administration/providers/administration_provider.dart';
import '../../features/administration/screens/sign_in_screen.dart';

void showLogoutConfirmation(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: const [
          Icon(Icons.logout, color: Colors.red),
          SizedBox(width: 8),
          Text('Đăng Xuất', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: const Text(
        'Bạn có chắc chắn muốn đăng xuất khỏi hệ thống quản lý Laptop LPSM không?',
        style: TextStyle(fontSize: 14),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.logout, size: 18),
          label: const Text('Đăng Xuất'),
          onPressed: () {
            Navigator.pop(ctx);
            ref.read(currentUserProvider.notifier).state = null;
            ref.read(activeWorkspaceProvider.notifier).state = 'ducanh';
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const SignInScreen()),
              (route) => false,
            );
          },
        ),
      ],
    ),
  );
}

class LogoutIconButton extends ConsumerWidget {
  const LogoutIconButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.logout, color: Colors.redAccent),
      tooltip: 'Đăng xuất (UC-02)',
      onPressed: () => showLogoutConfirmation(context, ref),
    );
  }
}

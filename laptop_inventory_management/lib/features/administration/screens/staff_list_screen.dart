import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/drawer_menu_button.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/logout_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../providers/administration_provider.dart';
import 'staff_form_screen.dart';

class StaffListScreen extends ConsumerWidget {
  const StaffListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(adminStaffListProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('Danh Sách Nhân Viên (Đức Anh)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(adminStaffListProvider),
          ),
          const LogoutIconButton(),
        ],
      ),
      body: staffAsync.when(
        data: (users) {
          if (users.isEmpty) {
            return const EmptyStateView(
              icon: Icons.people_outline,
              title: 'Chưa có nhân viên nào',
              message: SystemMessages.msg14,
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (ctx, i) {
              final u = users[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: u.role == AppRoles.admin
                        ? AppTheme.primaryBlue
                        : (u.role == AppRoles.salesStaff
                              ? AppTheme.emeraldGreen
                              : AppTheme.amberOrange),
                    foregroundColor: Colors.white,
                    child: Icon(
                      u.role == AppRoles.admin
                          ? Icons.admin_panel_settings
                          : Icons.person,
                    ),
                  ),
                  title: Text(
                    u.fullName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Username: ${u.username} • ${AppRoles.getDisplayName(u.role)}',
                      ),
                      Text(
                        'Tạo lúc: ${Formatters.formatIsoDate(u.createdAt)}',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StatusBadge(status: u.isActive ? 'active' : 'inactive'),
                      IconButton(
                        icon: const Icon(
                          Icons.edit_outlined,
                          color: AppTheme.primaryBlue,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StaffFormScreen(userToEdit: u),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          u.isActive ? Icons.toggle_on : Icons.toggle_off,
                          color: u.isActive
                              ? AppTheme.emeraldGreen
                              : Colors.grey,
                          size: 28,
                        ),
                        tooltip: u.isActive ? 'Khóa tài khoản' : 'Mở khóa',
                        onPressed: () async {
                          final db = await DatabaseHelper.instance.database;
                          await db.update(
                            'app_users',
                            {'is_active': u.isActive ? 0 : 1},
                            where: 'user_id = ?',
                            whereArgs: [u.userId],
                          );
                          ref.invalidate(adminStaffListProvider);
                          ref.invalidate(adminAuditLogsProvider);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Lỗi: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Thêm Nhân Viên (FR-30)'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StaffFormScreen()),
          );
        },
      ),
    );
  }
}

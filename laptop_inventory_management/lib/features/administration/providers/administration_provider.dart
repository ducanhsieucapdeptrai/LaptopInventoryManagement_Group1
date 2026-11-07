import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/audit_log.dart';
import '../../../core/services/api_service.dart';

final currentUserProvider = StateProvider<AppUser?>((ref) => null);
final activeWorkspaceProvider = StateProvider<String>((ref) => 'ducanh');

final adminStaffListProvider = FutureProvider<List<AppUser>>((ref) async {
  final db = await DatabaseHelper.instance.database;
  final maps = await db.query('app_users', orderBy: 'created_at ASC');
  return maps.map((m) => AppUser.fromMap(m)).toList();
});

final adminAuditLogsProvider = FutureProvider<List<AuditLog>>((ref) async {
  final db = await DatabaseHelper.instance.database;
  final maps = await db.rawQuery('''
    SELECT a.*, u.username
    FROM audit_logs a
    LEFT JOIN app_users u ON a.user_id = u.user_id
    ORDER BY a.created_at DESC
    LIMIT 100
  ''');
  return maps.map((m) => AuditLog.fromMap(m)).toList();
});

final apiHealthStatusProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  return ApiService.instance.checkHealth();
});

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/drawer_menu_button.dart';
import '../../../core/widgets/logout_button.dart';
import '../../../core/widgets/stat_card.dart';
import '../providers/administration_provider.dart';
import 'audit_history_screen.dart';
import 'promotion_list_screen.dart';
import 'staff_list_screen.dart';
import 'store_settings_screen.dart';
import '../../sales_report/screens/reports_screen.dart';
import '../../sales_report/screens/return_approval_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  Future<Map<String, dynamic>> _loadOverviewData() async {
    final db = await DatabaseHelper.instance.database;
    final userCount =
        (await db.rawQuery(
              'SELECT COUNT(*) as c FROM app_users WHERE is_active=1',
            )).first['c']
            as int;
    final productCount =
        (await db.rawQuery(
              'SELECT COUNT(*) as c FROM products WHERE is_active=1',
            )).first['c']
            as int;
    final orderCount =
        (await db.rawQuery(
              'SELECT COUNT(*) as c FROM sales_orders WHERE status="completed"',
            )).first['c']
            as int;
    final totalRevenue =
        (await db.rawQuery(
              'SELECT IFNULL(SUM(total), 0) as s FROM sales_orders WHERE status="completed"',
            )).first['s']
            as num;
    final lowStockCount =
        (await db.rawQuery(
              'SELECT COUNT(*) as c FROM products WHERE is_active=1 AND stock <= alert_threshold',
            )).first['c']
            as int;
    final pendingReturnCount =
        (await db.rawQuery(
              'SELECT COUNT(*) as c FROM sales_returns WHERE status="pending"',
            )).first['c']
            as int;

    return {
      'users': userCount,
      'products': productCount,
      'orders': orderCount,
      'revenue': totalRevenue.toDouble(),
      'low_stock': lowStockCount,
      'pending_returns': pendingReturnCount,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('Tổng Quan Quản Trị (Đức Anh)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_outlined),
            tooltip: 'Báo cáo doanh thu & Xuất CSV (UC-2.6)',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReportsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.storefront_outlined),
            tooltip: 'Cài đặt cửa hàng & Hóa đơn',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StoreSettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.local_offer_outlined),
            tooltip: 'Khuyến mãi & Voucher',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PromotionListScreen()),
              );
            },
          ),
          const LogoutIconButton(),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadOverviewData(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Welcome Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryBlue, AppTheme.accentCyan],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.white,
                      child: Icon(
                        user?.role == AppRoles.admin
                            ? Icons.admin_panel_settings
                            : Icons.person,
                        color: AppTheme.primaryBlue,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Xin chào, ${user?.fullName ?? "Quản trị viên"}!',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Vai trò: ${AppRoles.getDisplayName(user?.role ?? AppRoles.admin)}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // KPI Summary
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: 'Doanh số bán ra',
                      value: Formatters.formatCurrency(
                        data['revenue'] as double,
                      ),
                      subtitle: '${data['orders']} đơn hoàn tất',
                      icon: Icons.trending_up,
                      color: AppTheme.emeraldGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      title: 'Sản phẩm kinh doanh',
                      value: '${data['products']} SKU',
                      subtitle: 'Sắp hết: ${data['low_stock']} máy',
                      icon: Icons.laptop_chromebook,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Quick Administration Tools
              const Text(
                'Chức Năng Quản Trị Hệ Thống (Đức Anh)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 10),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            (data['pending_returns'] as int? ?? 0) > 0
                            ? const Color(0xFFFEE2E2)
                            : const Color(0xFFDCFCE7),
                        child: Icon(
                          Icons.assignment_return,
                          color: (data['pending_returns'] as int? ?? 0) > 0
                              ? Colors.red
                              : AppTheme.emeraldGreen,
                        ),
                      ),
                      title: const Text(
                        'Phê duyệt đổi trả & Hoàn tiền (FR-26)',
                      ),
                      subtitle: Text(
                        (data['pending_returns'] as int? ?? 0) > 0
                            ? 'Có ${data['pending_returns']} yêu cầu đổi trả đang chờ Admin duyệt!'
                            : 'Duyệt hoàn tiền & tự động hoàn kho sản phẩm',
                        style: TextStyle(
                          color: (data['pending_returns'] as int? ?? 0) > 0
                              ? Colors.red.shade700
                              : null,
                          fontWeight: (data['pending_returns'] as int? ?? 0) > 0
                              ? FontWeight.bold
                              : null,
                        ),
                      ),
                      trailing: (data['pending_returns'] as int? ?? 0) > 0
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${data['pending_returns']} chờ',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ReturnApprovalScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFDCFCE7),
                        child: Icon(
                          Icons.bar_chart,
                          color: AppTheme.emeraldGreen,
                        ),
                      ),
                      title: const Text(
                        'Báo cáo doanh thu & Xuất file CSV (UC-2.6, FR-29)',
                      ),
                      subtitle: const Text(
                        'Xem chi tiết doanh thu, lợi nhuận gộp, top laptop và xuất CSV',
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ReportsScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE0E7FF),
                        child: Icon(Icons.people, color: AppTheme.primaryBlue),
                      ),
                      title: const Text('Quản lý nhân viên (FR-30)'),
                      subtitle: Text(
                        '${data['users']} tài khoản nhân sự đang hoạt động',
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const StaffListScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFDCFCE7),
                        child: Icon(
                          Icons.security,
                          color: AppTheme.emeraldGreen,
                        ),
                      ),
                      title: const Text(
                        'Nhật ký kiểm toán hệ thống (Audit Log FR-31)',
                      ),
                      subtitle: const Text(
                        'Theo dõi dấu vết thao tác login, kho, đơn hàng',
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AuditHistoryScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFFEF3C7),
                        child: Icon(
                          Icons.storefront,
                          color: AppTheme.amberOrange,
                        ),
                      ),
                      title: const Text('Cài đặt thông tin cửa hàng & Hóa đơn'),
                      subtitle: const Text(
                        'Cấu hình VAT, hotline, địa chỉ, lời cảm ơn hóa đơn',
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const StoreSettingsScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE0F2FE),
                        child: Icon(
                          Icons.local_offer,
                          color: AppTheme.accentCyan,
                        ),
                      ),
                      title: const Text(
                        'Quản lý khuyến mãi & Voucher giảm giá',
                      ),
                      subtitle: const Text(
                        'Thiết lập mã coupon, mức giảm %, thời hạn áp dụng',
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PromotionListScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

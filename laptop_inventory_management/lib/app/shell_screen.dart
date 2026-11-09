import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/firebase_service.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/drawer_menu_button.dart';
import '../core/widgets/logout_button.dart';
import '../features/administration/providers/administration_provider.dart';
import '../features/administration/screens/audit_history_screen.dart';
import '../features/administration/screens/dashboard_screen.dart';
import '../features/administration/screens/promotion_list_screen.dart';
import '../features/administration/screens/staff_form_screen.dart';
import '../features/administration/screens/staff_list_screen.dart';
import '../features/administration/screens/store_settings_screen.dart';
import '../features/catalog_inventory/screens/create_stock_receipt_screen.dart';
import '../features/catalog_inventory/screens/product_form_screen.dart';
import '../features/catalog_inventory/screens/product_list_screen.dart';
import '../features/catalog_inventory/screens/stock_adjustment_screen.dart';
import '../features/catalog_inventory/screens/stock_history_screen.dart';
import '../features/catalog_inventory/screens/stock_receipt_list_screen.dart';
import '../features/master_data/screens/category_form_screen.dart';
import '../features/master_data/screens/category_list_screen.dart';
import '../features/master_data/screens/customer_form_screen.dart';
import '../features/master_data/screens/customer_list_screen.dart';
import '../features/master_data/screens/supplier_form_screen.dart';
import '../features/master_data/screens/supplier_list_screen.dart';
import '../features/sales_report/screens/create_sales_order_screen.dart';
import '../features/sales_report/screens/order_list_screen.dart';
import '../features/sales_report/screens/reports_screen.dart';
import '../features/sales_report/screens/return_approval_screen.dart';
import '../features/sales_report/screens/sales_return_request_screen.dart';

class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  int _currentIndex = 0;

  void _switchWorkspace(String ws) {
    setState(() {
      _currentIndex = 0;
    });
    ref.read(activeWorkspaceProvider.notifier).state = ws;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final workspace = ref.watch(activeWorkspaceProvider);

    // Build dedicated tabs & navigation bar according to active workspace
    late List<Widget> currentTabs;
    late List<NavigationDestination> destinations;
    late String workspaceTitle;
    late String ownerName;
    late Color themeColor;

    switch (workspace) {
      case 'minh':
        workspaceTitle = 'Dữ Liệu Danh Mục & Đối Tác';
        ownerName = 'Bùi Quang Minh';
        themeColor = Colors.teal;
        currentTabs = const [
          CategoryListScreen(),
          SupplierListScreen(),
          CustomerListScreen(),
        ];
        destinations = const [
          NavigationDestination(
            icon: Icon(Icons.category_outlined),
            selectedIcon: Icon(Icons.category),
            label: 'Danh Mục',
          ),
          NavigationDestination(
            icon: Icon(Icons.business_outlined),
            selectedIcon: Icon(Icons.business),
            label: 'Nhà Cung Cấp',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Khách Hàng',
          ),
        ];
        break;

      case 'truong':
        workspaceTitle = 'Kho Laptop & Biến Động Tồn';
        ownerName = 'Dương Văn Trường';
        themeColor = Colors.orange.shade800;
        currentTabs = const [
          ProductListScreen(),
          StockReceiptListScreen(),
          StockHistoryScreen(),
        ];
        destinations = const [
          NavigationDestination(
            icon: Icon(Icons.laptop_chromebook_outlined),
            selectedIcon: Icon(Icons.laptop_chromebook),
            label: 'Kho Laptop',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Phiếu Nhập',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Sổ Thẻ Kho',
          ),
        ];
        break;

      case 'sales':
        workspaceTitle = 'Bán Hàng POS & Báo Cáo';
        ownerName = 'Đỗ Nhật Trương';
        themeColor = AppTheme.emeraldGreen;
        currentTabs = const [
          CreateSalesOrderScreen(),
          OrderListScreen(),
          ReturnApprovalScreen(),
          ReportsScreen(),
        ];
        destinations = const [
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale),
            label: 'Bán Hàng POS',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_outlined),
            selectedIcon: Icon(Icons.receipt),
            label: 'Hóa Đơn',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_return_outlined),
            selectedIcon: Icon(Icons.assignment_return),
            label: 'Đổi Trả',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Báo Cáo',
          ),
        ];
        break;

      case 'ducanh':
      default:
        workspaceTitle = 'Quản Trị Hệ Thống';
        ownerName = 'Đoàn Đức Anh';
        themeColor = AppTheme.primaryBlue;
        currentTabs = const [
          DashboardScreen(),
          StaffListScreen(),
          ReportsScreen(),
          StoreSettingsScreen(),
          PromotionListScreen(),
        ];
        destinations = const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Tổng Quan',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Nhân Viên',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Báo Cáo CSV',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Cài Đặt Shop',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_offer_outlined),
            selectedIcon: Icon(Icons.local_offer),
            label: 'Khuyến Mãi',
          ),
        ];
        break;
    }

    final safeIndex = _currentIndex < currentTabs.length ? _currentIndex : 0;

    return Scaffold(
      key: shellScaffoldKey,
      body: IndexedStack(index: safeIndex, children: currentTabs),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: themeColor),
              otherAccountsPictures: [
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  tooltip: 'Đăng xuất tài khoản',
                  onPressed: () {
                    Navigator.pop(context);
                    showLogoutConfirmation(context, ref);
                  },
                ),
              ],
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  ownerName.isNotEmpty ? ownerName.split(' ').last[0] : 'U',
                  style: TextStyle(
                    color: themeColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              accountName: Text(
                user?.fullName ?? ownerName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              accountEmail: Text(
                'Phân hệ: $workspaceTitle ($ownerName)',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),

            // Cloud BaaS alert preview
            StreamBuilder<String>(
              stream: FirebaseCloudService.instance.realTimeCloudAlerts,
              builder: (ctx, snap) {
                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.cloud_done,
                        size: 18,
                        color: AppTheme.accentCyan,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          snap.data ?? 'Hệ thống Cloud BaaS: Trực tuyến',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.primaryBlue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Switcher for switching between member workspaces (Preview/Review)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CHUYỂN PHÂN HỆ THÀNH VIÊN (REVIEW):',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ChoiceChip(
                        label: const Text(
                          '1. Đức Anh',
                          style: TextStyle(fontSize: 11),
                        ),
                        selected: workspace == 'ducanh',
                        onSelected: (val) {
                          if (val) _switchWorkspace('ducanh');
                        },
                      ),
                      ChoiceChip(
                        label: const Text(
                          '2. Minh',
                          style: TextStyle(fontSize: 11),
                        ),
                        selected: workspace == 'minh',
                        onSelected: (val) {
                          if (val) _switchWorkspace('minh');
                        },
                      ),
                      ChoiceChip(
                        label: const Text(
                          '3. Trường',
                          style: TextStyle(fontSize: 11),
                        ),
                        selected: workspace == 'truong',
                        onSelected: (val) {
                          if (val) _switchWorkspace('truong');
                        },
                      ),
                      ChoiceChip(
                        label: const Text(
                          '4. Trương',
                          style: TextStyle(fontSize: 11),
                        ),
                        selected: workspace == 'sales',
                        onSelected: (val) {
                          if (val) _switchWorkspace('sales');
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(),

            // DEDICATED ITEMS BASED ON ACTIVE WORKSPACE
            if (workspace == 'ducanh') ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  'CHỨC NĂNG CỦA ĐỨC ANH (7 MÀN HÌNH)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.dashboard_outlined),
                title: const Text('1. Dashboard Quản Trị'),
                selected: safeIndex == 0,
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 0);
                },
              ),
              ListTile(
                leading: const Icon(Icons.people_outline),
                title: const Text('2. Quản Lý Nhân Viên (FR-30)'),
                selected: safeIndex == 1,
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 1);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_add_outlined),
                title: const Text('3. Thêm/Sửa Tài Khoản Nhân Viên'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StaffFormScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.bar_chart_outlined),
                title: const Text('4. Báo Cáo Doanh Thu & Xuất CSV (UC-2.6)'),
                selected: safeIndex == 2,
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 2);
                },
              ),
              ListTile(
                leading: const Icon(Icons.storefront_outlined),
                title: const Text('5. Cài Đặt Cửa Hàng & Hóa Đơn'),
                selected: safeIndex == 3,
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 3);
                },
              ),
              ListTile(
                leading: const Icon(Icons.local_offer_outlined),
                title: const Text('6. Quản Lý Khuyến Mãi & Voucher'),
                selected: safeIndex == 4,
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 4);
                },
              ),
              ListTile(
                leading: const Icon(Icons.security),
                title: const Text('7. Nhật Ký Kiểm Toán (FR-31)'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AuditHistoryScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('8. Xác Thực Bảo Mật & Lockout (BR-12)'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Xác thực SHA-256 & Chính sách khóa 15 phút (BR-12) đang hoạt động!',
                      ),
                    ),
                  );
                },
              ),
            ] else if (workspace == 'minh') ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  'CHỨC NĂNG CỦA MINH (7 MÀN HÌNH)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.category_outlined),
                title: const Text('1. Danh Mục Loại Máy & Linh Kiện'),
                selected: safeIndex == 0,
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 0);
                },
              ),
              ListTile(
                leading: const Icon(Icons.add_box_outlined),
                title: const Text('2. Thêm/Sửa Danh Mục (FR-05)'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CategoryFormScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.business_outlined),
                title: const Text('3. Danh Sách Nhà Cung Cấp (FR-09)'),
                selected: safeIndex == 1,
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 1);
                },
              ),
              ListTile(
                leading: const Icon(Icons.add_business_outlined),
                title: const Text('4. Thêm Nhà Cung Cấp Mới'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SupplierFormScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.people_outline),
                title: const Text('5. Danh Bạ Khách Hàng (FR-15)'),
                selected: safeIndex == 2,
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 2);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_add_alt),
                title: const Text('6. Đăng Ký Khách Hàng Mới'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CustomerFormScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.card_giftcard),
                title: const Text('7. Tích Điểm Thành Viên (BR-08)'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 2);
                },
              ),
            ] else if (workspace == 'truong') ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  'CHỨC NĂNG CỦA TRƯỜNG (7 MÀN HÌNH)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.laptop_chromebook),
                title: const Text('1. Kho Laptop & PC (FR-06, FR-08)'),
                selected: safeIndex == 0,
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 0);
                },
              ),
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: const Text('2. Thêm Mới Thiết Bị (Specs JSON)'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ProductFormScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.receipt_long),
                title: const Text('3. Danh Sách Phiếu Nhập Kho (FR-10)'),
                selected: safeIndex == 1,
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 1);
                },
              ),
              ListTile(
                leading: const Icon(Icons.post_add),
                title: const Text('4. Lập Phiếu Nhập Kho Mới (FR-11)'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CreateStockReceiptScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.tune),
                title: const Text('5. Kiểm Kê & Điều Chỉnh Tồn (FR-12)'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StockAdjustmentScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('6. Sổ Thẻ Kho Biến Động (FR-13)'),
                selected: safeIndex == 2,
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 2);
                },
              ),
              ListTile(
                leading: const Icon(Icons.warning_amber),
                title: const Text('7. Cảnh Báo Tồn Kho Tối Thiểu (FR-14)'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 2);
                },
              ),
            ] else if (workspace == 'sales') ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  'CHỨC NĂNG CỦA TRƯƠNG (7 MÀN HÌNH)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.emeraldGreen,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.add_shopping_cart),
                title: const Text('1. Bán Hàng POS (FR-16, FR-17)'),
                selected: safeIndex == 0,
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 0);
                },
              ),
              ListTile(
                leading: const Icon(Icons.point_of_sale),
                title: const Text('2. Danh Sách Hóa Đơn Bán Lẻ (FR-23)'),
                selected: safeIndex == 1,
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 1);
                },
              ),
              ListTile(
                leading: const Icon(Icons.assignment_return_outlined),
                title: const Text('3. Yêu Cầu Đổi Trả 7 Ngày (FR-24)'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SalesReturnRequestScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.gavel),
                title: const Text('4. Phê Duyệt Đổi Trả (FR-26)'),
                selected: safeIndex == 2,
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 2);
                },
              ),
              ListTile(
                leading: const Icon(Icons.bar_chart),
                title: const Text('5. Báo Cáo Doanh Thu (FR-27)'),
                selected: safeIndex == 3,
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 3);
                },
              ),
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('6. Xuất Dữ Liệu Báo Cáo Ra CSV'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 3);
                },
              ),
              ListTile(
                leading: const Icon(Icons.verified_outlined),
                title: const Text('7. Tra Cứu Bảo Hành & Hóa Đơn (FR-33)'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 1);
                },
              ),
            ],

            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Đăng Xuất (UC-02)',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                showLogoutConfirmation(context, ref);
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: destinations,
      ),
    );
  }
}

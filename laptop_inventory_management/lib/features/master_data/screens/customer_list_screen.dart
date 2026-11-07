import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/drawer_menu_button.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/logout_button.dart';
import '../providers/master_data_provider.dart';
import 'customer_detail_screen.dart';
import 'customer_form_screen.dart';

class CustomerListScreen extends ConsumerWidget {
  const CustomerListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(masterCustomersProvider);
    final query = ref.watch(customerSearchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('Danh Sách Khách Hàng (Minh)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(masterCustomersProvider),
          ),
          const LogoutIconButton(),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(14),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Tìm kiếm khách hàng theo tên, SĐT...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () =>
                            ref
                                    .read(customerSearchQueryProvider.notifier)
                                    .state =
                                '',
                      )
                    : null,
                isDense: true,
              ),
              onChanged: (val) =>
                  ref.read(customerSearchQueryProvider.notifier).state = val
                      .trim(),
            ),
          ),
          Expanded(
            child: customersAsync.when(
              data: (customers) {
                if (customers.isEmpty) {
                  return const EmptyStateView(
                    icon: Icons.people_outline,
                    title: 'Không tìm thấy khách hàng',
                    message: SystemMessages.msg14,
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  itemCount: customers.length,
                  itemBuilder: (ctx, i) {
                    final c = customers[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryBlue.withValues(
                            alpha: 0.12,
                          ),
                          foregroundColor: AppTheme.primaryBlue,
                          child: Text(
                            c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          c.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Text(
                              'SĐT: ${c.phone} • ${c.address ?? "Chưa có địa chỉ"}',
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Đã mua: ${c.totalOrders} đơn • Tổng chi: ${Formatters.formatCurrency(c.totalSpent)}',
                              style: const TextStyle(
                                color: AppTheme.emeraldGreen,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CustomerDetailScreen(customer: c),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Lỗi: $err')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Thêm Khách Hàng (FR-15)'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CustomerFormScreen()),
          );
        },
      ),
    );
  }
}

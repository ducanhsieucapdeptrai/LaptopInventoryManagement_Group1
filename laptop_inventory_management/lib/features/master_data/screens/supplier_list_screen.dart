import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/drawer_menu_button.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/logout_button.dart';
import '../providers/master_data_provider.dart';
import 'supplier_form_screen.dart';

class SupplierListScreen extends ConsumerWidget {
  const SupplierListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliersAsync = ref.watch(masterSuppliersProvider);
    final query = ref.watch(supplierSearchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('Nhà Cung Cấp & Phân Phối (Minh)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(masterSuppliersProvider),
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
                hintText: 'Tìm kiếm nhà phân phối theo tên, SĐT...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () =>
                            ref
                                    .read(supplierSearchQueryProvider.notifier)
                                    .state =
                                '',
                      )
                    : null,
                isDense: true,
              ),
              onChanged: (val) =>
                  ref.read(supplierSearchQueryProvider.notifier).state = val
                      .trim(),
            ),
          ),
          Expanded(
            child: suppliersAsync.when(
              data: (suppliers) {
                if (suppliers.isEmpty) {
                  return const EmptyStateView(
                    icon: Icons.business,
                    title: 'Chưa có nhà cung cấp nào',
                    message: SystemMessages.msg14,
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  itemCount: suppliers.length,
                  itemBuilder: (ctx, i) {
                    final sup = suppliers[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryBlue.withValues(
                            alpha: 0.1,
                          ),
                          child: const Icon(
                            Icons.business,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                        title: Text(
                          sup.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Text(
                              'Hotline: ${sup.phone} • ${sup.email ?? "Chưa có email"}',
                            ),
                            if (sup.address != null)
                              Text(
                                'Địa chỉ: ${sup.address}',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: AppTheme.primaryBlue,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    SupplierFormScreen(supplierToEdit: sup),
                              ),
                            );
                          },
                        ),
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
        icon: const Icon(Icons.add_business),
        label: const Text('Thêm Nhà Cung Cấp (FR-09)'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SupplierFormScreen()),
          );
        },
      ),
    );
  }
}

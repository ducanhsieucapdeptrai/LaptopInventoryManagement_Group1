import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/models/category.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/drawer_menu_button.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/logout_button.dart';
import '../providers/master_data_provider.dart';
import 'category_form_screen.dart';

class CategoryListScreen extends ConsumerWidget {
  const CategoryListScreen({super.key});

  Future<int> _getProductCount(String categoryId) async {
    final db = await DatabaseHelper.instance.database;
    final res = await db.rawQuery(
      'SELECT COUNT(*) as c FROM products WHERE category_id = ? AND is_active = 1',
      [categoryId],
    );
    return res.first['c'] as int;
  }

  void _deleteCategory(
    BuildContext context,
    WidgetRef ref,
    Category cat,
  ) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final count = await _getProductCount(cat.categoryId);
      if (count > 0) {
        throw Exception(
          'Không thể xóa! Đang có $count sản phẩm thuộc danh mục này (FR-05).',
        );
      }

      await db.delete(
        'categories',
        where: 'category_id = ?',
        whereArgs: [cat.categoryId],
      );
      ref.invalidate(masterCategoriesProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Đã xóa danh mục ${cat.name}')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  IconData _getCategoryIcon(String catId, String name) {
    final lower = '$catId $name'.toLowerCase();
    if (lower.contains('gaming')) {
      return Icons.sports_esports;
    }
    if (lower.contains('văn phòng') ||
        lower.contains('office') ||
        lower.contains('doanh nhân')) {
      return Icons.business_center;
    }
    if (lower.contains('pc') || lower.contains('bàn')) {
      return Icons.desktop_windows;
    }
    if (lower.contains('phụ kiện') || lower.contains('linh kiện')) {
      return Icons.memory;
    }
    return Icons.laptop;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(masterCategoriesProvider);
    final query = ref.watch(categorySearchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('Danh Mục Loại Máy & Linh Kiện (Minh)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(masterCategoriesProvider),
          ),
          const LogoutIconButton(),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Tìm kiếm danh mục theo tên, mô tả...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () =>
                            ref
                                    .read(categorySearchQueryProvider.notifier)
                                    .state =
                                '',
                      )
                    : null,
                isDense: true,
              ),
              onChanged: (val) =>
                  ref.read(categorySearchQueryProvider.notifier).state = val
                      .trim(),
            ),
          ),
          Expanded(
            child: categoriesAsync.when(
              data: (categories) {
                if (categories.isEmpty) {
                  return const EmptyStateView(
                    icon: Icons.category_outlined,
                    title: 'Chưa có danh mục nào',
                    message: SystemMessages.msg14,
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  itemCount: categories.length,
                  itemBuilder: (ctx, i) {
                    final cat = categories[i];
                    return FutureBuilder<int>(
                      future: _getProductCount(cat.categoryId),
                      builder: (ctx, snap) {
                        final prodCount = snap.data ?? 0;
                        final icon = _getCategoryIcon(cat.categoryId, cat.name);

                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryBlue.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    icon,
                                    color: AppTheme.primaryBlue,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              cat.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '$prodCount SP',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.primaryBlue,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        cat.description ?? 'Danh mục linh kiện thiết bị chính hãng',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade700,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    color: AppTheme.primaryBlue,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CategoryFormScreen(
                                          categoryToEdit: cat,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  onPressed: () =>
                                      _deleteCategory(context, ref, cat),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
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
        icon: const Icon(Icons.add),
        label: const Text('Thêm Danh Mục (FR-05)'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CategoryFormScreen()),
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/drawer_menu_button.dart';
import '../../../core/widgets/logout_button.dart';

final promotionListProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final db = await DatabaseHelper.instance.database;
  return await db.query('promotions', orderBy: 'is_active DESC, code ASC');
});

class PromotionListScreen extends ConsumerWidget {
  const PromotionListScreen({super.key});

  void _showAddEditDialog(
    BuildContext context,
    WidgetRef ref, [
    Map<String, dynamic>? promo,
  ]) {
    final isEdit = promo != null;
    final codeCtrl = TextEditingController(
      text: promo?['code']?.toString() ?? '',
    );
    final titleCtrl = TextEditingController(
      text: promo?['title']?.toString() ?? '',
    );
    final percentCtrl = TextEditingController(
      text: (promo?['discount_percent'] as num?)?.toStringAsFixed(0) ?? '10',
    );
    final minSpendCtrl = TextEditingController(
      text:
          (promo?['min_order_spend'] as num?)?.toStringAsFixed(0) ?? '10000000',
    );
    final validCtrl = TextEditingController(
      text: promo?['valid_until']?.toString() ?? '2026-12-31',
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isEdit ? 'Chỉnh Sửa Voucher' : 'Tạo Mã Khuyến Mãi Mới (Đức Anh)',
        ),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Mã voucher (Ví dụ: ROG2026) *',
                    isDense: true,
                  ),
                  validator: (v) => Validators.requiredField(v, 'Mã voucher'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tên chương trình ưu đãi *',
                    isDense: true,
                  ),
                  validator: (v) =>
                      Validators.requiredField(v, 'Tên chương trình'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: percentCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Mức giảm (%) *',
                          isDense: true,
                        ),
                        validator: (v) =>
                            Validators.positiveNumber(v, 'Mức giảm'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: validCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Hạn dùng (YYYY-MM-DD)',
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: minSpendCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Đơn hàng tối thiểu (VND)',
                    isDense: true,
                  ),
                  validator: (v) =>
                      Validators.positiveNumber(v, 'Đơn hàng tối thiểu'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final db = await DatabaseHelper.instance.database;
              final code = codeCtrl.text.trim().toUpperCase();
              final title = titleCtrl.text.trim();
              final percent = double.tryParse(percentCtrl.text.trim()) ?? 10.0;
              final minSpend = double.tryParse(minSpendCtrl.text.trim()) ?? 0.0;
              final valid = validCtrl.text.trim();

              if (isEdit) {
                await db.update(
                  'promotions',
                  {
                    'code': code,
                    'title': title,
                    'discount_percent': percent,
                    'min_order_spend': minSpend,
                    'valid_until': valid,
                  },
                  where: 'promo_id = ?',
                  whereArgs: [promo['promo_id']],
                );
              } else {
                await db.insert('promotions', {
                  'promo_id': const Uuid().v4(),
                  'code': code,
                  'title': title,
                  'discount_percent': percent,
                  'discount_amount': 0.0,
                  'min_order_spend': minSpend,
                  'is_active': 1,
                  'valid_until': valid,
                });
              }

              ref.invalidate(promotionListProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Lưu Voucher'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promosAsync = ref.watch(promotionListProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('Quản Lý Khuyến Mãi & Voucher (Đức Anh)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(promotionListProvider),
          ),
          const LogoutIconButton(),
        ],
      ),
      body: promosAsync.when(
        data: (promos) {
          if (promos.isEmpty) {
            return const Center(child: Text('Chưa có mã khuyến mãi nào'));
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: promos.length,
            itemBuilder: (ctx, i) {
              final p = promos[i];
              final isActive = (p['is_active'] as int? ?? 1) == 1;
              final percent =
                  (p['discount_percent'] as num?)?.toDouble() ?? 0.0;
              final minSpend =
                  (p['min_order_spend'] as num?)?.toDouble() ?? 0.0;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isActive
                        ? AppTheme.primaryBlue.withValues(alpha: 0.3)
                        : Colors.grey.shade300,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isActive ? AppTheme.primaryBlue : Colors.grey,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.local_offer,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '-${percent.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  p['code']?.toString() ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? Colors.green.shade50
                                        : Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isActive ? 'ĐANG ÁP DỤNG' : 'TẠM DỪNG',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: isActive
                                          ? Colors.green.shade800
                                          : Colors.red.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              p['title']?.toString() ?? '',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Đơn tối thiểu: ${Formatters.formatCurrency(minSpend)} • HSD: ${p['valid_until'] ?? "Vô thời hạn"}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.edit_outlined,
                          color: AppTheme.primaryBlue,
                          size: 20,
                        ),
                        onPressed: () => _showAddEditDialog(context, ref, p),
                      ),
                      Switch(
                        value: isActive,
                        activeTrackColor: AppTheme.primaryBlue,
                        onChanged: (val) async {
                          final db = await DatabaseHelper.instance.database;
                          await db.update(
                            'promotions',
                            {'is_active': val ? 1 : 0},
                            where: 'promo_id = ?',
                            whereArgs: [p['promo_id']],
                          );
                          ref.invalidate(promotionListProvider);
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
        icon: const Icon(Icons.add),
        label: const Text('Thêm Mã Giảm Giá'),
        onPressed: () => _showAddEditDialog(context, ref),
      ),
    );
  }
}

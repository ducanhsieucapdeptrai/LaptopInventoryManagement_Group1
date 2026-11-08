import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/models/product.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../providers/catalog_inventory_provider.dart';
import 'product_form_screen.dart';

class ProductDetailScreen extends ConsumerWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final margin = product.price - product.cost;
    final marginPercent = product.price > 0
        ? (margin / product.price) * 100
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(product.sku),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Sửa thông tin',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductFormScreen(productToEdit: product),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(
              product.isActive ? Icons.visibility : Icons.visibility_off,
            ),
            tooltip: product.isActive ? 'Ngừng kinh doanh' : 'Mở lại',
            onPressed: () async {
              final db = await DatabaseHelper.instance.database;
              await db.update(
                'products',
                {'is_active': product.isActive ? 0 : 1},
                where: 'product_id = ?',
                whereArgs: [product.productId],
              );
              ref.invalidate(catalogProductsProvider);

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Đã chuyển trạng thái: ${!product.isActive ? "Kinh doanh" : "Ngừng bán"}',
                    ),
                  ),
                );
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.laptop,
                      color: AppTheme.primaryBlue,
                      size: 40,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Hãng: ${product.brand}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Mã SKU: ${product.sku}',
                          style: const TextStyle(
                            color: AppTheme.primaryBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cấu hình chi tiết (Technical Specifications)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const Divider(),
                  Text(
                    product.specs,
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Giá thành & Tỷ suất lợi nhuận (FR-06)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const Divider(),
                  _row(
                    'Giá niêm yết bán lẻ:',
                    Formatters.formatCurrency(product.price),
                    isHighlight: true,
                  ),
                  _row(
                    'Giá vốn nhập hàng:',
                    Formatters.formatCurrency(product.cost),
                  ),
                  _row(
                    'Lợi nhuận gộp / chiếc:',
                    Formatters.formatCurrency(margin),
                  ),
                  _row(
                    'Tỷ suất lợi nhuận:',
                    '${marginPercent.toStringAsFixed(1)}%',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tồn kho thực tế (FR-13)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Số lượng hiện có:'),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: product.isLowStock
                              ? Colors.red.shade100
                              : Colors.green.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${product.stock} chiếc ${product.isLowStock ? "(Sắp hết)" : "(Đủ hàng)"}',
                          style: TextStyle(
                            color: product.isLowStock
                                ? Colors.red.shade900
                                : Colors.green.shade900,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ngưỡng cảnh báo an toàn: ${product.alertThreshold} chiếc',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontSize: isHighlight ? 16 : 13,
              fontWeight: FontWeight.bold,
              color: isHighlight ? AppTheme.primaryBlue : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

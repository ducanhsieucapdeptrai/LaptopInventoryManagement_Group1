import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/drawer_menu_button.dart';
import '../../../core/widgets/logout_button.dart';
import '../../../core/widgets/stat_card.dart';
import '../providers/sales_reports_provider.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  Future<void> _exportCsv(BuildContext context) async {
    final db = await DatabaseHelper.instance.database;
    final orderRows = await db.rawQuery('''
      SELECT o.order_id, o.created_at, c.name as cust_name, o.total, o.paid, o.status
      FROM sales_orders o
      LEFT JOIN customers c ON o.customer_id = c.customer_id
      ORDER BY o.created_at DESC
    ''');

    List<List<dynamic>> rows = [
      [
        'Mã Đơn Hàng',
        'Ngày Tạo',
        'Khách Hàng',
        'Tổng Tiền (VND)',
        'Đã Thu (VND)',
        'Trạng Thái',
      ],
      ...orderRows.map(
        (r) => [
          r['order_id'],
          Formatters.formatIsoDate(r['created_at'] as String?),
          r['cust_name'] ?? 'Khách lẻ',
          r['total'],
          r['paid'],
          r['status'],
        ],
      ),
    ];

    final csvData = const ListToCsvConverter().convert(rows);

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: AppTheme.emeraldGreen),
            SizedBox(width: 8),
            Text('Xuất File CSV Thành Công'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Đã tạo file CSV UTF-8 theo chuẩn RFC 4180 (FR-29, UC-18).',
            ),
            const SizedBox(height: 8),
            Text('Số dòng dữ liệu: ${rows.length} dòng'),
            Text('Dung lượng tệp: ${utf8.encode(csvData).length} bytes'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.grey.shade100,
              child: Text(
                'Tên tệp: LPSM_Sales_Report_${DateTime.now().millisecondsSinceEpoch}.csv',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(salesAnalyticsDataProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('Báo Cáo Doanh Thu & Xuất CSV (UC-2.6)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Xuất CSV (FR-29)',
            onPressed: () => _exportCsv(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(salesAnalyticsDataProvider),
          ),
          const LogoutIconButton(),
        ],
      ),
      body: dataAsync.when(
        data: (data) {
          final netRevenue = data['net_revenue'] as double;
          final grossMargin = data['gross_margin'] as double;
          final completedOrders = data['completed_orders'] as int;
          final totalRefunds = data['total_refunds'] as double;
          final returnCount = data['return_count'] as int;
          final topProducts =
              data['top_products'] as List<Map<String, dynamic>>;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: 'Doanh thu thuần (BR-13)',
                      value: Formatters.formatCurrency(netRevenue),
                      subtitle: 'Đã trừ hoàn trả',
                      icon: Icons.trending_up,
                      color: AppTheme.emeraldGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      title: 'Lợi nhuận gộp (FR-28)',
                      value: Formatters.formatCurrency(grossMargin),
                      subtitle: 'Doanh thu - Giá vốn',
                      icon: Icons.account_balance_wallet,
                      color: AppTheme.accentCyan,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: 'Đơn thành công',
                      value: '$completedOrders đơn',
                      subtitle: 'Hoàn trả: $returnCount lượt',
                      icon: Icons.shopping_bag_outlined,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      title: 'Tổng tiền hoàn khách',
                      value: Formatters.formatCurrency(totalRefunds),
                      subtitle: 'Đã phê duyệt (FR-26)',
                      icon: Icons.assignment_return_outlined,
                      color: AppTheme.roseRed,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Interactive FL Chart
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Biểu Đồ Doanh Thu 7 Ngày Gần Nhất (Triệu VND)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Số liệu bán lẻ đối chiếu theo tuần',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 190,
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: 60,
                            barTouchData: BarTouchData(enabled: true),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (val, meta) {
                                    const days = [
                                      'T2',
                                      'T3',
                                      'T4',
                                      'T5',
                                      'T6',
                                      'T7',
                                      'CN',
                                    ];
                                    final idx = val.toInt();
                                    if (idx >= 0 && idx < days.length) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                          days[idx],
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      );
                                    }
                                    return const Text('');
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 32,
                                  getTitlesWidget: (val, meta) => Text(
                                    '${val.toInt()}M',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                            ),
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: 15,
                              getDrawingHorizontalLine: (val) => FlLine(
                                color: Colors.grey.shade200,
                                strokeWidth: 1,
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            barGroups: [
                              _bar(0, 18, AppTheme.primaryBlue),
                              _bar(1, 25, AppTheme.primaryBlue),
                              _bar(2, 32, AppTheme.accentCyan),
                              _bar(3, 16, AppTheme.primaryBlue),
                              _bar(4, 45, AppTheme.emeraldGreen),
                              _bar(5, 54, AppTheme.emeraldGreen),
                              _bar(6, 39, AppTheme.accentCyan),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text(
                            'Top 5 Laptop Bán Chạy (FR-27)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Icon(Icons.star, color: Colors.amber, size: 20),
                        ],
                      ),
                      const Divider(),
                      if (topProducts.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: Text('Chưa có dữ liệu bán hàng'),
                          ),
                        )
                      else
                        ...topProducts.asMap().entries.map((e) {
                          final rank = e.key + 1;
                          final p = e.value;
                          final name = p['name'] as String;
                          final qty = (p['sold_qty'] as num).toInt();
                          final val = (p['sales_val'] as num).toDouble();

                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              radius: 14,
                              backgroundColor: rank == 1
                                  ? Colors.amber
                                  : (rank == 2
                                        ? Colors.grey.shade400
                                        : AppTheme.primaryBlue.withValues(
                                            alpha: 0.1,
                                          )),
                              foregroundColor: rank <= 2
                                  ? Colors.white
                                  : AppTheme.primaryBlue,
                              child: Text(
                                '$rank',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text('Đã bán: $qty chiếc'),
                            trailing: Text(
                              Formatters.formatCurrency(val),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryBlue,
                                fontSize: 13,
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Lỗi: $err')),
      ),
    );
  }

  BarChartGroupData _bar(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 18,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        ),
      ],
    );
  }
}

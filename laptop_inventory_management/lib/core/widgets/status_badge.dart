import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;

    switch (status.toLowerCase()) {
      case 'completed':
      case 'posted':
      case 'approved':
      case 'active':
      case 'success':
        bg = const Color(0xFFDCFCE7); // Light green
        fg = const Color(0xFF15803D); // Dark green
        label = status == 'completed'
            ? 'Hoàn thành'
            : status == 'posted'
            ? 'Đã nhập kho'
            : status == 'approved'
            ? 'Đã duyệt'
            : status == 'active'
            ? 'Đang hoạt động'
            : 'Thành công';
        break;
      case 'draft':
      case 'pending':
        bg = const Color(0xFFE0F2FE); // Light sky blue
        fg = const Color(0xFF0369A1); // Dark sky blue
        label = status == 'draft' ? 'Đang xử lý' : 'Chờ duyệt';
        break;
      case 'cancelled':
      case 'rejected':
      case 'inactive':
      case 'failed':
        bg = const Color(0xFFFEE2E2); // Light red
        fg = const Color(0xFFB91C1C); // Dark red
        label = status == 'cancelled'
            ? 'Đã hủy'
            : status == 'rejected'
            ? 'Từ chối'
            : status == 'inactive'
            ? 'Ngừng hoạt động'
            : 'Thất bại';
        break;
      default:
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade800;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

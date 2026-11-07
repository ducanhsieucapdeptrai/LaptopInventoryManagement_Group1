class SalesReturn {
  final String returnId;
  final String orderId;
  final String? approvedBy;
  final String status; // 'pending', 'approved', 'rejected'
  final double refundTotal;
  final String reason;
  final String createdAt;
  final String? approverName;
  final List<SalesReturnItem> items;

  SalesReturn({
    required this.returnId,
    required this.orderId,
    this.approvedBy,
    required this.status,
    required this.refundTotal,
    required this.reason,
    required this.createdAt,
    this.approverName,
    this.items = const [],
  });

  bool get isApproved => status == 'approved';

  factory SalesReturn.fromMap(
    Map<String, dynamic> map, {
    List<SalesReturnItem> items = const [],
  }) {
    return SalesReturn(
      returnId: map['return_id'] as String,
      orderId: map['order_id'] as String,
      approvedBy: map['approved_by'] as String?,
      status: map['status'] as String,
      refundTotal: (map['refund_total'] as num).toDouble(),
      reason: map['reason'] as String? ?? '',
      createdAt: map['created_at'] as String,
      approverName: map['approver_name'] as String?,
      items: items,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'return_id': returnId,
      'order_id': orderId,
      'approved_by': approvedBy,
      'status': status,
      'refund_total': refundTotal,
      'reason': reason,
      'created_at': createdAt,
    };
  }

  SalesReturn copyWith({
    String? returnId,
    String? orderId,
    String? approvedBy,
    String? status,
    double? refundTotal,
    String? reason,
    String? createdAt,
    String? approverName,
    List<SalesReturnItem>? items,
  }) {
    return SalesReturn(
      returnId: returnId ?? this.returnId,
      orderId: orderId ?? this.orderId,
      approvedBy: approvedBy ?? this.approvedBy,
      status: status ?? this.status,
      refundTotal: refundTotal ?? this.refundTotal,
      reason: reason ?? this.reason,
      createdAt: createdAt ?? this.createdAt,
      approverName: approverName ?? this.approverName,
      items: items ?? this.items,
    );
  }
}

class SalesReturnItem {
  final String returnItemId;
  final String returnId;
  final String orderItemId;
  final int qty;
  final bool restockable; // BR-11: sellable vs damaged
  final double refundAmount;
  final String? productName;
  final String? productSku;

  SalesReturnItem({
    required this.returnItemId,
    required this.returnId,
    required this.orderItemId,
    required this.qty,
    required this.restockable,
    required this.refundAmount,
    this.productName,
    this.productSku,
  });

  factory SalesReturnItem.fromMap(Map<String, dynamic> map) {
    return SalesReturnItem(
      returnItemId: map['return_item_id'] as String,
      returnId: map['return_id'] as String,
      orderItemId: map['order_item_id'] as String,
      qty: (map['qty'] as num).toInt(),
      restockable: (map['restockable'] as int? ?? 1) == 1,
      refundAmount: (map['refund_amount'] as num).toDouble(),
      productName: map['product_name'] as String?,
      productSku: map['sku'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'return_item_id': returnItemId,
      'return_id': returnId,
      'order_item_id': orderItemId,
      'qty': qty,
      'restockable': restockable ? 1 : 0,
      'refund_amount': refundAmount,
    };
  }
}

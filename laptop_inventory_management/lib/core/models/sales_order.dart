class SalesOrder {
  final String orderId;
  final String? customerId;
  final String createdBy;
  final String status; // 'draft', 'completed', 'cancelled'
  final double subtotal;
  final double discountPercent;
  final double discountAmount;
  final double total;
  final double paid;
  final String? notes;
  final String createdAt;
  final String? customerName;
  final String? customerPhone;
  final String? creatorName;
  final List<SalesOrderItem> items;

  SalesOrder({
    required this.orderId,
    this.customerId,
    required this.createdBy,
    required this.status,
    required this.subtotal,
    this.discountPercent = 0.0,
    this.discountAmount = 0.0,
    required this.total,
    this.paid = 0.0,
    this.notes,
    required this.createdAt,
    this.customerName,
    this.customerPhone,
    this.creatorName,
    this.items = const [],
  });

  bool get isDraft => status == 'draft';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get isFullyPaid => paid >= total;

  factory SalesOrder.fromMap(
    Map<String, dynamic> map, {
    List<SalesOrderItem> items = const [],
  }) {
    return SalesOrder(
      orderId: map['order_id'] as String,
      customerId: map['customer_id'] as String?,
      createdBy: map['created_by'] as String,
      status: map['status'] as String,
      subtotal: (map['subtotal'] as num).toDouble(),
      discountPercent: (map['discount_percent'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (map['discount_amount'] as num?)?.toDouble() ?? 0.0,
      total: (map['total'] as num).toDouble(),
      paid: (map['paid'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String,
      customerName: map['customer_name'] as String?,
      customerPhone: map['customer_phone'] as String?,
      creatorName: map['creator_name'] as String?,
      items: items,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'order_id': orderId,
      'customer_id': customerId,
      'created_by': createdBy,
      'status': status,
      'subtotal': subtotal,
      'discount_percent': discountPercent,
      'discount_amount': discountAmount,
      'total': total,
      'paid': paid,
      'notes': notes,
      'created_at': createdAt,
    };
  }

  SalesOrder copyWith({
    String? orderId,
    String? customerId,
    String? createdBy,
    String? status,
    double? subtotal,
    double? discountPercent,
    double? discountAmount,
    double? total,
    double? paid,
    String? notes,
    String? createdAt,
    String? customerName,
    String? customerPhone,
    String? creatorName,
    List<SalesOrderItem>? items,
  }) {
    return SalesOrder(
      orderId: orderId ?? this.orderId,
      customerId: customerId ?? this.customerId,
      createdBy: createdBy ?? this.createdBy,
      status: status ?? this.status,
      subtotal: subtotal ?? this.subtotal,
      discountPercent: discountPercent ?? this.discountPercent,
      discountAmount: discountAmount ?? this.discountAmount,
      total: total ?? this.total,
      paid: paid ?? this.paid,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      creatorName: creatorName ?? this.creatorName,
      items: items ?? this.items,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SalesOrder &&
          runtimeType == other.runtimeType &&
          orderId == other.orderId;

  @override
  int get hashCode => orderId.hashCode;
}

class SalesOrderItem {
  final String orderItemId;
  final String orderId;
  final String productId;
  final int qty;
  final double priceSnapshot; // BR-06 immutable selling price
  final double costSnapshot; // BR-06 immutable cost
  final String? productName;
  final String? productSku;
  final int returnedQty; // Already returned quantity

  SalesOrderItem({
    required this.orderItemId,
    required this.orderId,
    required this.productId,
    required this.qty,
    required this.priceSnapshot,
    required this.costSnapshot,
    this.productName,
    this.productSku,
    this.returnedQty = 0,
  });

  double get subtotal => qty * priceSnapshot;
  int get remainingReturnableQty => qty - returnedQty;

  factory SalesOrderItem.fromMap(Map<String, dynamic> map) {
    return SalesOrderItem(
      orderItemId: map['order_item_id'] as String,
      orderId: map['order_id'] as String,
      productId: map['product_id'] as String,
      qty: (map['qty'] as num).toInt(),
      priceSnapshot: (map['price_snapshot'] as num).toDouble(),
      costSnapshot: (map['cost_snapshot'] as num).toDouble(),
      productName: map['product_name'] as String?,
      productSku: map['sku'] as String?,
      returnedQty: (map['returned_qty'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'order_item_id': orderItemId,
      'order_id': orderId,
      'product_id': productId,
      'qty': qty,
      'price_snapshot': priceSnapshot,
      'cost_snapshot': costSnapshot,
    };
  }

  SalesOrderItem copyWith({
    String? orderItemId,
    String? orderId,
    String? productId,
    int? qty,
    double? priceSnapshot,
    double? costSnapshot,
    String? productName,
    String? productSku,
    int? returnedQty,
  }) {
    return SalesOrderItem(
      orderItemId: orderItemId ?? this.orderItemId,
      orderId: orderId ?? this.orderId,
      productId: productId ?? this.productId,
      qty: qty ?? this.qty,
      priceSnapshot: priceSnapshot ?? this.priceSnapshot,
      costSnapshot: costSnapshot ?? this.costSnapshot,
      productName: productName ?? this.productName,
      productSku: productSku ?? this.productSku,
      returnedQty: returnedQty ?? this.returnedQty,
    );
  }
}

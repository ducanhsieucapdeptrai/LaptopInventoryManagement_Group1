class StockReceipt {
  final String receiptId;
  final String supplierId;
  final String createdBy;
  final String status; // 'draft', 'posted'
  final String receivedAt;
  final double totalCost;
  final String? notes;
  final String? supplierName;
  final String? creatorName;
  final List<StockReceiptItem> items;

  StockReceipt({
    required this.receiptId,
    required this.supplierId,
    required this.createdBy,
    required this.status,
    required this.receivedAt,
    required this.totalCost,
    this.notes,
    this.supplierName,
    this.creatorName,
    this.items = const [],
  });

  bool get isPosted => status == 'posted';

  factory StockReceipt.fromMap(
    Map<String, dynamic> map, {
    List<StockReceiptItem> items = const [],
  }) {
    return StockReceipt(
      receiptId: map['receipt_id'] as String,
      supplierId: map['supplier_id'] as String,
      createdBy: map['created_by'] as String,
      status: map['status'] as String,
      receivedAt: map['received_at'] as String,
      totalCost: (map['total_cost'] as num).toDouble(),
      notes: map['notes'] as String?,
      supplierName: map['supplier_name'] as String?,
      creatorName: map['creator_name'] as String?,
      items: items,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'receipt_id': receiptId,
      'supplier_id': supplierId,
      'created_by': createdBy,
      'status': status,
      'received_at': receivedAt,
      'total_cost': totalCost,
      'notes': notes,
    };
  }

  StockReceipt copyWith({
    String? receiptId,
    String? supplierId,
    String? createdBy,
    String? status,
    String? receivedAt,
    double? totalCost,
    String? notes,
    String? supplierName,
    String? creatorName,
    List<StockReceiptItem>? items,
  }) {
    return StockReceipt(
      receiptId: receiptId ?? this.receiptId,
      supplierId: supplierId ?? this.supplierId,
      createdBy: createdBy ?? this.createdBy,
      status: status ?? this.status,
      receivedAt: receivedAt ?? this.receivedAt,
      totalCost: totalCost ?? this.totalCost,
      notes: notes ?? this.notes,
      supplierName: supplierName ?? this.supplierName,
      creatorName: creatorName ?? this.creatorName,
      items: items ?? this.items,
    );
  }
}

class StockReceiptItem {
  final String receiptItemId;
  final String receiptId;
  final String productId;
  final int qty;
  final double unitCost;
  final String? productName;
  final String? productSku;

  StockReceiptItem({
    required this.receiptItemId,
    required this.receiptId,
    required this.productId,
    required this.qty,
    required this.unitCost,
    this.productName,
    this.productSku,
  });

  double get subtotal => qty * unitCost;

  factory StockReceiptItem.fromMap(Map<String, dynamic> map) {
    return StockReceiptItem(
      receiptItemId: map['receipt_item_id'] as String,
      receiptId: map['receipt_id'] as String,
      productId: map['product_id'] as String,
      qty: (map['qty'] as num).toInt(),
      unitCost: (map['unit_cost'] as num).toDouble(),
      productName: map['product_name'] as String?,
      productSku: map['sku'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'receipt_item_id': receiptItemId,
      'receipt_id': receiptId,
      'product_id': productId,
      'qty': qty,
      'unit_cost': unitCost,
    };
  }
}

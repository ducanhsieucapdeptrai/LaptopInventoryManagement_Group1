class StockMovement {
  final String movementId;
  final String productId;
  final String createdBy;
  final String
  type; // 'receipt', 'sale', 'return', 'adjustment_in', 'adjustment_out'
  final int qtyDelta; // + or -
  final String ref;
  final String createdAt;
  final String? productName;
  final String? productSku;
  final String? creatorName;

  StockMovement({
    required this.movementId,
    required this.productId,
    required this.createdBy,
    required this.type,
    required this.qtyDelta,
    required this.ref,
    required this.createdAt,
    this.productName,
    this.productSku,
    this.creatorName,
  });

  String get typeDisplayName {
    switch (type) {
      case 'receipt':
        return 'Nhập kho NCC';
      case 'sale':
        return 'Bán hàng (Xuất kho)';
      case 'return':
        return 'Khách đổi trả (Nhập lại)';
      case 'adjustment_in':
        return 'Kiểm kê tăng';
      case 'adjustment_out':
        return 'Kiểm kê giảm/Hao hụt';
      default:
        return type;
    }
  }

  factory StockMovement.fromMap(Map<String, dynamic> map) {
    return StockMovement(
      movementId: map['movement_id'] as String,
      productId: map['product_id'] as String,
      createdBy: map['created_by'] as String,
      type: map['type'] as String,
      qtyDelta: (map['qty_delta'] as num).toInt(),
      ref: map['ref'] as String,
      createdAt: map['created_at'] as String,
      productName: map['product_name'] as String?,
      productSku: map['sku'] as String?,
      creatorName: map['creator_name'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'movement_id': movementId,
      'product_id': productId,
      'created_by': createdBy,
      'type': type,
      'qty_delta': qtyDelta,
      'ref': ref,
      'created_at': createdAt,
    };
  }
}

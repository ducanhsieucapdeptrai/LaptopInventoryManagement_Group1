class Payment {
  final String paymentId;
  final String orderId;
  final String method; // 'cash', 'bank_transfer'
  final double amount;
  final String status; // 'success', 'failed'
  final String? refCode;
  final String createdAt;

  Payment({
    required this.paymentId,
    required this.orderId,
    required this.method,
    required this.amount,
    this.status = 'success',
    this.refCode,
    required this.createdAt,
  });

  String get methodDisplayName {
    switch (method) {
      case 'cash':
        return 'Tiền mặt';
      case 'bank_transfer':
        return 'Chuyển khoản ngân hàng';
      default:
        return method;
    }
  }

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      paymentId: map['payment_id'] as String,
      orderId: map['order_id'] as String,
      method: map['method'] as String,
      amount: (map['amount'] as num).toDouble(),
      status: map['status'] as String,
      refCode: map['ref_code'] as String?,
      createdAt: map['created_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'payment_id': paymentId,
      'order_id': orderId,
      'method': method,
      'amount': amount,
      'status': status,
      'ref_code': refCode,
      'created_at': createdAt,
    };
  }
}

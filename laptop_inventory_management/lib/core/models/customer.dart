class Customer {
  final String customerId;
  final String name;
  final String phone;
  final String? email;
  final String? address;
  final int totalOrders;
  final double totalSpent;

  Customer({
    required this.customerId,
    required this.name,
    required this.phone,
    this.email,
    this.address,
    this.totalOrders = 0,
    this.totalSpent = 0.0,
  });

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      customerId: map['customer_id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String,
      email: map['email'] as String?,
      address: map['address'] as String?,
      totalOrders: (map['total_orders'] as num?)?.toInt() ?? 0,
      totalSpent: (map['total_spent'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customer_id': customerId,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'total_orders': totalOrders,
      'total_spent': totalSpent,
    };
  }

  Customer copyWith({
    String? customerId,
    String? name,
    String? phone,
    String? email,
    String? address,
    int? totalOrders,
    double? totalSpent,
  }) {
    return Customer(
      customerId: customerId ?? this.customerId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      totalOrders: totalOrders ?? this.totalOrders,
      totalSpent: totalSpent ?? this.totalSpent,
    );
  }
}

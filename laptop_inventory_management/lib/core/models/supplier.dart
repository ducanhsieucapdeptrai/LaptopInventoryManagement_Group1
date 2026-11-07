class Supplier {
  final String supplierId;
  final String name;
  final String phone;
  final String? email;
  final String? address;
  final bool isActive;

  Supplier({
    required this.supplierId,
    required this.name,
    required this.phone,
    this.email,
    this.address,
    this.isActive = true,
  });

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      supplierId: map['supplier_id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String,
      email: map['email'] as String?,
      address: map['address'] as String?,
      isActive: (map['is_active'] as int? ?? 1) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'supplier_id': supplierId,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'is_active': isActive ? 1 : 0,
    };
  }

  Supplier copyWith({
    String? supplierId,
    String? name,
    String? phone,
    String? email,
    String? address,
    bool? isActive,
  }) {
    return Supplier(
      supplierId: supplierId ?? this.supplierId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      isActive: isActive ?? this.isActive,
    );
  }
}

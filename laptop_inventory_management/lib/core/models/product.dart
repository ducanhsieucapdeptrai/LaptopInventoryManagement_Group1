class Product {
  final String productId;
  final String categoryId;
  final String sku;
  final String name;
  final String brand;
  final String specs; // e.g. "Core i7-13700H / 16GB / 512GB SSD / RTX 4060"
  final double price; // Selling price in VND
  final double cost; // Cost price in VND
  final int stock; // Quantity on hand
  final int alertThreshold; // Low stock threshold (default 5)
  final bool isActive;
  final String? categoryName;

  Product({
    required this.productId,
    required this.categoryId,
    required this.sku,
    required this.name,
    required this.brand,
    required this.specs,
    required this.price,
    required this.cost,
    required this.stock,
    this.alertThreshold = 5,
    this.isActive = true,
    this.categoryName,
  });

  bool get isLowStock => stock <= alertThreshold;

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      productId: map['product_id'] as String,
      categoryId: map['category_id'] as String,
      sku: map['sku'] as String,
      name: map['name'] as String,
      brand: map['brand'] as String,
      specs: map['specs'] as String? ?? '',
      price: (map['price'] as num).toDouble(),
      cost: (map['cost'] as num).toDouble(),
      stock: (map['stock'] as num).toInt(),
      alertThreshold: (map['alert_threshold'] as num?)?.toInt() ?? 5,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      categoryName: map['category_name'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'product_id': productId,
      'category_id': categoryId,
      'sku': sku,
      'name': name,
      'brand': brand,
      'specs': specs,
      'price': price,
      'cost': cost,
      'stock': stock,
      'alert_threshold': alertThreshold,
      'is_active': isActive ? 1 : 0,
    };
  }

  Product copyWith({
    String? productId,
    String? categoryId,
    String? sku,
    String? name,
    String? brand,
    String? specs,
    double? price,
    double? cost,
    int? stock,
    int? alertThreshold,
    bool? isActive,
    String? categoryName,
  }) {
    return Product(
      productId: productId ?? this.productId,
      categoryId: categoryId ?? this.categoryId,
      sku: sku ?? this.sku,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      specs: specs ?? this.specs,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      stock: stock ?? this.stock,
      alertThreshold: alertThreshold ?? this.alertThreshold,
      isActive: isActive ?? this.isActive,
      categoryName: categoryName ?? this.categoryName,
    );
  }
}

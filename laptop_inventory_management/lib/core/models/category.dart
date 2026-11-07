class Category {
  final String categoryId;
  final String name;
  final String? description;
  final bool isActive;

  Category({
    required this.categoryId,
    required this.name,
    this.description,
    this.isActive = true,
  });

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      categoryId: map['category_id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      isActive: (map['is_active'] as int? ?? 1) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'category_id': categoryId,
      'name': name,
      'description': description,
      'is_active': isActive ? 1 : 0,
    };
  }

  Category copyWith({
    String? categoryId,
    String? name,
    String? description,
    bool? isActive,
  }) {
    return Category(
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
    );
  }
}

class AppUser {
  final String userId;
  final String username;
  final String passwordHash;
  final String role; // admin, sales_staff, inventory_staff
  final String fullName;
  final bool isActive;
  final String? createdAt;

  AppUser({
    required this.userId,
    required this.username,
    required this.passwordHash,
    required this.role,
    required this.fullName,
    this.isActive = true,
    this.createdAt,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      userId: map['user_id'] as String,
      username: map['username'] as String,
      passwordHash: map['password_hash'] as String,
      role: map['role'] as String,
      fullName: map['full_name'] as String? ?? map['username'] as String,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: map['created_at'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'username': username,
      'password_hash': passwordHash,
      'role': role,
      'full_name': fullName,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
    };
  }

  AppUser copyWith({
    String? userId,
    String? username,
    String? passwordHash,
    String? role,
    String? fullName,
    bool? isActive,
    String? createdAt,
  }) {
    return AppUser(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
      role: role ?? this.role,
      fullName: fullName ?? this.fullName,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

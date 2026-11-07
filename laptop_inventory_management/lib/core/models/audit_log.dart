class AuditLog {
  final String auditId;
  final String? userId;
  final String action;
  final String entity;
  final String details;
  final String createdAt;
  final String? username;

  AuditLog({
    required this.auditId,
    this.userId,
    required this.action,
    required this.entity,
    required this.details,
    required this.createdAt,
    this.username,
  });

  factory AuditLog.fromMap(Map<String, dynamic> map) {
    return AuditLog(
      auditId: map['audit_id'] as String,
      userId: map['user_id'] as String?,
      action: map['action'] as String,
      entity: map['entity'] as String,
      details: map['details'] as String? ?? '',
      createdAt: map['created_at'] as String,
      username: map['username'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'audit_id': auditId,
      'user_id': userId,
      'action': action,
      'entity': entity,
      'details': details,
      'created_at': createdAt,
    };
  }
}

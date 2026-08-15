/// A single audit-trail entry from `user_activities`.
///
/// The backend eager-loads `user:id,username,name,email`, so [userName] and
/// [userUsername] are populated whenever the actor still exists.
class ActivityLog {
  final int id;
  final int? userId;
  final int? modelId;
  final String activityType;
  final String? description;
  final String? ipAddress;
  final String? userAgent;
  final Map<String, dynamic>? metadata;
  final DateTime? createdAt;

  final String? userUsername;
  final String? userName;
  final String? userEmail;

  const ActivityLog({
    required this.id,
    this.userId,
    this.modelId,
    required this.activityType,
    this.description,
    this.ipAddress,
    this.userAgent,
    this.metadata,
    this.createdAt,
    this.userUsername,
    this.userName,
    this.userEmail,
  });

  static int _toInt(dynamic v, [int fallback = 0]) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  static int? _toIntOrNull(dynamic v) => v == null ? null : _toInt(v);

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    final user = json['user'];

    // `metadata` is cast to array server-side, but tolerate a JSON string too.
    Map<String, dynamic>? meta;
    final rawMeta = json['metadata'];
    if (rawMeta is Map) {
      meta = Map<String, dynamic>.from(rawMeta);
    }

    return ActivityLog(
      id: _toInt(json['id']),
      userId: _toIntOrNull(json['user_id']),
      modelId: _toIntOrNull(json['model_id']),
      activityType: json['activity_type']?.toString() ?? 'unknown',
      description: json['description']?.toString(),
      ipAddress: json['ip_address']?.toString(),
      userAgent: json['user_agent']?.toString(),
      metadata: meta,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      userUsername: user is Map ? user['username']?.toString() : null,
      userName: user is Map ? user['name']?.toString() : null,
      userEmail: user is Map ? user['email']?.toString() : null,
    );
  }

  /// Best available label for the actor; deleted users fall back to their ID.
  String get actorLabel {
    if (userUsername != null && userUsername!.isNotEmpty) return userUsername!;
    if (userName != null && userName!.isNotEmpty) return userName!;
    if (userId != null) return 'User #$userId';
    return 'System';
  }

  /// `create_user` -> `Create User`
  String get typeLabel => activityType
      .split('_')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

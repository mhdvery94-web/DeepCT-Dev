/// Someone asking for a platform account, from the public landing page.
///
/// Mirrors `GET /api/admin/access-requests`. The submission side sends a plain
/// map, so only the admin-facing shape needs a model.
class AccessRequest {
  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String institution;
  final String? reason;

  /// One of `pending`, `approved`, `rejected`.
  final String status;

  final String? reviewNote;
  final String? reviewerName;

  /// Username of the account created when this was approved.
  final String? createdUsername;

  final DateTime? createdAt;
  final DateTime? reviewedAt;

  const AccessRequest({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.institution,
    this.reason,
    required this.status,
    this.reviewNote,
    this.reviewerName,
    this.createdUsername,
    this.createdAt,
    this.reviewedAt,
  });

  static DateTime? _date(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString());

  factory AccessRequest.fromJson(Map<String, dynamic> json) {
    final reviewer = json['reviewer'];
    final createdUser = json['created_user'];

    return AccessRequest(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      institution: json['institution']?.toString() ?? '',
      reason: json['reason']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      reviewNote: json['review_note']?.toString(),
      reviewerName: reviewer is Map
          ? (reviewer['name'] ?? reviewer['username'])?.toString()
          : null,
      createdUsername: createdUser is Map
          ? createdUser['username']?.toString()
          : null,
      createdAt: _date(json['created_at']),
      reviewedAt: _date(json['reviewed_at']),
    );
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  String get fullName => '$firstName $lastName'.trim();
}

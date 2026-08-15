/// One reported problem, and optionally the conversation about it.
///
/// The list endpoints omit `messages`; the detail endpoint includes them.
class SupportTicket {
  final int id;
  final String subject;
  final String category;

  /// One of `open`, `in_progress`, `resolved`, `closed`.
  final String status;

  /// One of `low`, `normal`, `high`.
  final String priority;

  /// True while it is the administrator's turn to reply. Drives the badge.
  final bool awaitingAdmin;

  final int messageCount;
  final int? analysisRecordId;

  /// Who raised it. Only meaningful in the admin queue. Falls back to the
  /// name a guest typed on the sign-in page.
  final String? userName;
  final String? userEmail;

  /// Raised from the sign-in page by someone who could not get in. There is no
  /// account to show a reply in, so the administrator answers [userEmail].
  final bool isGuest;

  final DateTime? createdAt;
  final DateTime? lastReplyAt;
  final DateTime? resolvedAt;

  final List<SupportMessage> messages;

  const SupportTicket({
    required this.id,
    required this.subject,
    required this.category,
    required this.status,
    required this.priority,
    required this.awaitingAdmin,
    required this.messageCount,
    this.analysisRecordId,
    this.userName,
    this.userEmail,
    this.isGuest = false,
    this.createdAt,
    this.lastReplyAt,
    this.resolvedAt,
    this.messages = const [],
  });

  static int _int(dynamic v) => v is int
      ? v
      : (v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0);

  static DateTime? _date(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString());

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    final guest = json['guest'];
    final rawMessages = json['messages'];

    return SupportTicket(
      id: _int(json['id']),
      subject: json['subject']?.toString() ?? '',
      category: json['category']?.toString() ?? 'other',
      status: json['status']?.toString() ?? 'open',
      priority: json['priority']?.toString() ?? 'normal',
      awaitingAdmin: json['awaiting_admin'] == true,
      messageCount: _int(json['message_count']),
      analysisRecordId: json['analysis_record_id'] == null
          ? null
          : _int(json['analysis_record_id']),
      userName: user is Map
          ? (user['name'] ?? user['username'])?.toString()
          : (guest is Map ? guest['name']?.toString() : null),
      userEmail: user is Map
          ? user['email']?.toString()
          : (guest is Map ? guest['email']?.toString() : null),
      isGuest: json['is_guest'] == true,
      createdAt: _date(json['created_at']),
      lastReplyAt: _date(json['last_reply_at']),
      resolvedAt: _date(json['resolved_at']),
      messages: rawMessages is List
          ? rawMessages
                .map((e) => SupportMessage.fromJson(
                      Map<String, dynamic>.from(e as Map),
                    ))
                .toList()
          : const [],
    );
  }

  bool get isOpen => status == 'open' || status == 'in_progress';
  bool get isClosed => status == 'closed';
  bool get isResolved => status == 'resolved';

  String get statusLabel => switch (status) {
    'open' => 'OPEN',
    'in_progress' => 'IN PROGRESS',
    'resolved' => 'RESOLVED',
    'closed' => 'CLOSED',
    _ => status.toUpperCase(),
  };
}

/// One message in a support conversation.
class SupportMessage {
  final int id;
  final String body;

  /// Written by staff. Stamped server-side when the message was created, so
  /// promoting the author later does not rewrite history.
  final bool fromAdmin;

  final String? author;
  final DateTime? createdAt;

  const SupportMessage({
    required this.id,
    required this.body,
    required this.fromAdmin,
    this.author,
    this.createdAt,
  });

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    return SupportMessage(
      id: SupportTicket._int(json['id']),
      body: json['body']?.toString() ?? '',
      fromAdmin: json['from_admin'] == true,
      author: json['author']?.toString(),
      createdAt: SupportTicket._date(json['created_at']),
    );
  }
}

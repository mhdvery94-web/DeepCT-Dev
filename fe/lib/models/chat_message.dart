/// One message in a support conversation.
class ChatMessage {
  final int id;
  final String body;

  /// Written by staff. Stamped server-side when the message was created, so
  /// promoting someone later does not rewrite history.
  final bool fromAdmin;

  final String? author;
  final String? authorAvatarPath;

  /// When the other side read it. Null means still unread.
  final DateTime? readAt;

  final DateTime? createdAt;

  const ChatMessage({
    required this.id,
    required this.body,
    required this.fromAdmin,
    this.author,
    this.authorAvatarPath,
    this.readAt,
    this.createdAt,
  });

  static int _int(dynamic v) => v is int
      ? v
      : (v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0);

  static DateTime? _date(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString());

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: _int(json['id']),
      body: json['body']?.toString() ?? '',
      fromAdmin: json['from_admin'] == true,
      author: json['author']?.toString(),
      authorAvatarPath: json['author_avatar_url']?.toString(),
      readAt: _date(json['read_at']),
      createdAt: _date(json['created_at']),
    );
  }

  bool get isRead => readAt != null;

  /// True when this message should sit on the right — the side the person
  /// looking at it is on.
  bool isMine({required bool viewerIsAdmin}) => fromAdmin == viewerIsAdmin;
}

/// One thread: a person and the administrators.
///
/// A researcher has exactly one, so their screen never needs [id] to fetch it
/// — `GET /messages` can only mean "mine".
class Conversation {
  /// Null when the researcher has never written; the server creates no row
  /// for silence.
  final int? id;

  /// Who is on the other end, for the admin inbox.
  final String name;

  final bool isGuest;
  final String? guestEmail;
  final bool isArchived;

  /// Unread from the reader's point of view: replies for a researcher,
  /// questions for an administrator.
  final int unread;

  final DateTime? lastMessageAt;

  /// First line of the newest message. Admin list only.
  final String preview;

  /// Whether that newest message was a reply, so the inbox can show at a
  /// glance which threads are still waiting on an answer.
  final bool? lastFromAdmin;

  final String? userAvatarPath;
  final String? userEmail;

  final List<ChatMessage> messages;

  const Conversation({
    this.id,
    this.name = '',
    this.isGuest = false,
    this.guestEmail,
    this.isArchived = false,
    this.unread = 0,
    this.lastMessageAt,
    this.preview = '',
    this.lastFromAdmin,
    this.userAvatarPath,
    this.userEmail,
    this.messages = const [],
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    final rawMessages = json['messages'];

    return Conversation(
      id: json['id'] == null ? null : ChatMessage._int(json['id']),
      name: json['name']?.toString() ?? '',
      isGuest: json['is_guest'] == true,
      guestEmail: json['guest_email']?.toString(),
      isArchived: json['is_archived'] == true,
      unread: ChatMessage._int(json['unread']),
      lastMessageAt: ChatMessage._date(json['last_message_at']),
      preview: json['preview']?.toString() ?? '',
      lastFromAdmin: json['last_from_admin'] == null
          ? null
          : json['last_from_admin'] == true,
      userAvatarPath: user is Map ? user['avatar_url']?.toString() : null,
      userEmail: user is Map
          ? user['email']?.toString()
          : json['guest_email']?.toString(),
      messages: rawMessages is List
          ? rawMessages
                .map(
                  (e) => ChatMessage.fromJson(Map<String, dynamic>.from(e as Map)),
                )
                .toList()
          : const [],
    );
  }

  bool get isEmpty => messages.isEmpty;
}

import '../config/api_config.dart';
import '../models/chat_message.dart';
import '../models/pagination.dart';
import 'api_client.dart';

/// IT support, as messaging.
///
/// The researcher's calls take no conversation id — they have exactly one
/// thread, so "mine" is the only thing they could mean. The admin calls do,
/// because an inbox is a list of other people's.
class MessageService {
  final ApiClient _api = ApiClient.instance;

  // ------------------------------------------------------------ researcher

  /// GET /messages — my thread, with everything said in it.
  Future<Conversation> myThread() async {
    final body = await _api.get(ApiConfig.messages);

    return Conversation.fromJson(Map<String, dynamic>.from(body['data'] as Map));
  }

  /// POST /messages — say something. Creates the thread on first use.
  Future<ChatMessage> send(String body) async {
    final response = await _api.post(ApiConfig.messages, data: {'body': body});

    return ChatMessage.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }

  /// POST /messages/read — I have seen the replies.
  Future<void> markRead() async {
    await _api.post('${ApiConfig.messages}/read');
  }

  // ---------------------------------------------------------------- public

  /// POST /messages/public — from the sign-in page, no token needed.
  ///
  /// For people who cannot sign in, which is the usual reason to press "IT
  /// Support" there. The answer arrives by email, not in the app, because
  /// there is no account session to show it in.
  Future<String> sendPublic({
    required String name,
    required String email,
    required String body,
  }) async {
    final response = await _api.post(
      '${ApiConfig.messages}/public',
      data: {'name': name, 'email': email, 'body': body},
    );

    return response['message']?.toString() ??
        'Message sent. An administrator will reply by email.';
  }

  // ----------------------------------------------------------------- admin

  /// GET /admin/conversations — the inbox.
  Future<({PaginatedResult<Conversation> page, int unreadConversations})> inbox({
    int page = 1,
    bool archived = false,
    bool unreadOnly = false,
    String? search,
  }) async {
    final body = await _api.get(
      ApiConfig.adminConversations,
      query: {
        'page': page,
        if (archived) 'archived': 1,
        if (unreadOnly) 'unread': 1,
        'search': search,
      },
    );

    final items = (body['data'] as List? ?? [])
        .map((e) => Conversation.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    final meta = body['meta'];

    return (
      page: PaginatedResult(
        items: items,
        pagination: body['pagination'] != null
            ? Pagination.fromJson(
                Map<String, dynamic>.from(body['pagination'] as Map),
              )
            : const Pagination.empty(),
      ),
      unreadConversations: meta is Map
          ? (meta['unread_conversations'] as num?)?.toInt() ?? 0
          : 0,
    );
  }

  /// GET /admin/conversations/{id}
  Future<Conversation> thread(int id) async {
    final body = await _api.get('${ApiConfig.adminConversations}/$id');

    return Conversation.fromJson(Map<String, dynamic>.from(body['data'] as Map));
  }

  /// POST /admin/conversations/{id}/reply
  Future<ChatMessage> reply(int id, String body) async {
    final response = await _api.post(
      '${ApiConfig.adminConversations}/$id/reply',
      data: {'body': body},
    );

    return ChatMessage.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }

  /// POST /admin/conversations/{id}/read
  Future<void> markThreadRead(int id) async {
    await _api.post('${ApiConfig.adminConversations}/$id/read');
  }

  /// PATCH /admin/conversations/{id} — archive or restore.
  Future<Conversation> setArchived(int id, bool archived) async {
    final body = await _api.patch(
      '${ApiConfig.adminConversations}/$id',
      data: {'is_archived': archived},
    );

    return Conversation.fromJson(Map<String, dynamic>.from(body['data'] as Map));
  }

  /// DELETE /admin/conversations/{id}
  Future<void> delete(int id) async {
    await _api.delete('${ApiConfig.adminConversations}/$id');
  }
}

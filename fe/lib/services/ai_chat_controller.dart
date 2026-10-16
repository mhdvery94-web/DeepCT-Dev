import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'ai_service.dart';
import 'api_client.dart';
import '../models/assistant_sources.dart';

/// Transport retry retains its admission payload. Request polling and late
/// responses stop when navigating or disposing this owner-scoped chat.
class AiChatController extends ChangeNotifier {
  final AiService service;
  AiChatController(this.service, {this.contextId})
    : _contextSpecified = contextId != null;
  int? contextId;
  bool _contextSpecified;
  bool get inheritsContext => !_contextSpecified;
  Map<String, dynamic>? status, conversation, request, pending, knownActive;
  List<Map<String, dynamic>> conversations = [], messages = [];
  int historyPage = 1, historyLast = 1, messagePage = 1, messageLast = 1;
  List<Map<String, dynamic>> analyses = [];
  int analysisPage = 0, analysisLast = 1;
  bool analysesLoading = false;
  String? analysesError;
  bool loading = true, busy = false;
  String? error, pollError;
  Timer? _timer;
  bool _disposed = false;
  int _selection = 0, _historySequence = 0;
  final Random _random = Random.secure();
  bool get enabled => status?['enabled'] == true;
  bool get active => ['queued', 'processing'].contains(request?['status']);
  bool get canSend =>
      enabled &&
      !active &&
      knownActive == null &&
      !busy &&
      !loading &&
      pending == null;
  Map<String, dynamic> get limits => map(status?['limits']);
  static Map<String, dynamic> map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : {};
  static List<Map<String, dynamic>> rows(dynamic value) =>
      value is List ? value.map(map).toList() : [];
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  String _key() =>
      '${DateTime.now().microsecondsSinceEpoch}-${List.generate(16, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';

  Future<void> initialize() async {
    loading = true;
    error = null;
    _notify();
    try {
      final result = await service.get('status');
      if (_disposed) return;
      status = result;
      if (status?['mode'] == 'metadata' && analysisPage == 0) {
        unawaited(loadAnalyses());
      }
      await loadHistory(1);
    } catch (e) {
      if (!_disposed) {
        error = assistantErrorMessage(e is ApiException ? e.message : null);
      }
    } finally {
      if (!_disposed) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> loadAnalyses() async {
    if (_disposed || analysesLoading) return;
    analysesLoading = true;
    analysesError = null;
    _notify();
    try {
      final result = await service.analyses(page: analysisPage + 1);
      if (_disposed) return;
      final unique = {for (final row in analyses) row['id']: row};
      for (final row in rows(result['data'])) {
        unique[row['id']] = {'id': row['id'], 'status': row['status']};
      }
      analyses = unique.values.toList();
      final pagination = map(result['pagination']);
      analysisPage = pagination['current_page'] as int? ?? analysisPage + 1;
      analysisLast = pagination['last_page'] as int? ?? analysisPage;
    } catch (e) {
      if (!_disposed) {
        analysesError = assistantErrorMessage(
          e is ApiException ? e.message : null,
        );
      }
    } finally {
      if (!_disposed) {
        analysesLoading = false;
        _notify();
      }
    }
  }

  void selectContext(int? id) {
    if (_disposed || !canSend) return;
    contextId = id;
    _contextSpecified = true;
    _notify();
  }

  void inheritContext() {
    if (_disposed || !canSend) return;
    contextId = null;
    _contextSpecified = false;
    _notify();
  }

  Future<void> loadHistory(int page) async {
    final sequence = ++_historySequence;
    try {
      final result = await service.get('conversations', page: page);
      if (_disposed || sequence != _historySequence) return;
      conversations = rows(result['conversations']);
      historyPage = page;
      historyLast = map(result['pagination'])['last_page'] as int? ?? 1;
      _notify();
    } catch (e) {
      if (!_disposed && sequence == _historySequence) {
        error = assistantErrorMessage(e is ApiException ? e.message : null);
        _notify();
      }
    }
  }

  Future<void> open(Map<String, dynamic> item) async {
    if (busy || pending != null) return;
    final selection = ++_selection;
    _timer?.cancel();
    conversation = item;
    messages = [];
    request = null;
    error = null;
    pollError = null;
    loading = true;
    messagePage = messageLast = 1;
    _notify();
    try {
      final result = await service.get('conversations/${item['id']}');
      if (_disposed || selection != _selection) return;
      messages = rows(result['messages']);
      messageLast = map(result['pagination'])['last_page'] as int? ?? 1;
      conversation = result;
      if (result['request'] != null) _accept(map(result['request']));
      _schedulePoll();
    } catch (e) {
      if (!_disposed && selection == _selection) {
        error = assistantErrorMessage(e is ApiException ? e.message : null);
      }
    } finally {
      if (!_disposed && selection == _selection) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> olderMessages() async {
    if (busy || conversation == null || messagePage >= messageLast) return;
    busy = true;
    _notify();
    final selection = _selection;
    try {
      final result = await service.get(
        'conversations/${conversation!['id']}',
        page: messagePage + 1,
      );
      if (_disposed || selection != _selection) return;
      _merge(rows(result['messages']));
      messagePage++;
      messageLast =
          map(result['pagination'])['last_page'] as int? ?? messageLast;
    } catch (e) {
      if (!_disposed && selection == _selection) {
        error = assistantErrorMessage(e is ApiException ? e.message : null);
      }
    } finally {
      if (!_disposed) {
        busy = false;
        _notify();
      }
    }
  }

  void _merge(List<Map<String, dynamic>> incoming) {
    final unique = {for (final message in messages) message['id']: message};
    for (final message in incoming) {
      unique[message['id']] = message;
    }
    messages = unique.values.toList()
      ..sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
  }

  void newChat() {
    if (busy || pending != null) return;
    ++_selection;
    _timer?.cancel();
    conversation = null;
    messages = [];
    request = null;
    loading = false;
    error = pollError = null;
    messagePage = messageLast = 1;
    _notify();
  }

  Future<bool> send(
    String content, {
    bool retry = false,
    bool useRequestContext = false,
  }) async {
    if (!enabled ||
        active ||
        knownActive != null ||
        busy ||
        loading ||
        (!retry && pending != null)) {
      return false;
    }
    // The persisted request owns regeneration context, including an explicit
    // null. Composer changes apply only to new questions.
    final selectedContext = useRequestContext
        ? (request?['analysis_record_id'] as int?)
        : contextId;
    final payload = retry
        ? pending
        : {
            'content': content.trim(),
            'idempotency_key': _key(),
            if (useRequestContext || _contextSpecified)
              'analysis_record_id': selectedContext,
          };
    if (payload == null || payload['content'].toString().isEmpty) return false;
    busy = true;
    error = null;
    _notify();
    try {
      if (conversation == null) {
        final created = await service.post('conversations', {});
        if (_disposed) return false;
        conversation = created;
      }
      pending = payload;
      final result = await service.post(
        'conversations/${conversation!['id']}/messages',
        payload,
      );
      if (_disposed) return false;
      _merge([map(result['user_message'])]);
      _accept(map(result['request']));
      pending = null;
      pollError = null;
      _schedulePoll();
      unawaited(loadHistory(1));
      return true;
    } catch (e) {
      if (!_disposed) {
        error = assistantErrorMessage(e is ApiException ? e.message : null);
        if (e is ApiException &&
            ((e.statusCode != null && e.statusCode! < 500) ||
                e.errorCode == 'assistant_disabled')) {
          pending = null;
          if (e.errorCode == 'assistant_disabled') {
            status = {...?status, 'enabled': false};
          }
        }
      }
      return false;
    } finally {
      if (!_disposed) {
        busy = false;
        _notify();
      }
    }
  }

  Future<bool> regenerate() async {
    final original = messages.where(
      (message) => message['id'] == request?['user_message_id'],
    );
    if (original.isEmpty) return false;
    return send(original.first['content'].toString(), useRequestContext: true);
  }

  void _accept(Map<String, dynamic> incoming) {
    request = incoming;
    if (active) {
      knownActive = incoming;
    } else if (knownActive?['id'] == incoming['id']) {
      knownActive = null;
    }
    if (incoming['assistant_message'] != null) {
      _merge([map(incoming['assistant_message'])]);
    }
  }

  void _schedulePoll([Duration delay = const Duration(seconds: 1)]) {
    _timer?.cancel();
    if (!_disposed && active) _timer = Timer(delay, poll);
  }

  Future<void> poll() async {
    if (_disposed || !active) return;
    final selection = _selection, id = request!['id'];
    try {
      final result = await service.get('requests/$id');
      if (_disposed ||
          selection != _selection ||
          request?['id'] != id ||
          !active) {
        return;
      }
      pollError = null;
      _accept(result);
      _notify();
      if (active) {
        _schedulePoll(const Duration(seconds: 3));
      } else {
        unawaited(loadHistory(1));
      }
    } catch (e) {
      if (!_disposed && selection == _selection && active) {
        pollError = assistantErrorMessage(e is ApiException ? e.message : null);
        _notify();
      }
    }
  }

  void retryPoll() {
    pollError = null;
    _notify();
    _schedulePoll(Duration.zero);
  }

  Future<void> cancel() async {
    if (!active || busy) return;
    busy = true;
    error = null;
    _notify();
    try {
      final result = await service.post(
        'requests/${request!['id']}/cancel',
        {},
      );
      if (_disposed) return;
      _timer?.cancel();
      _accept(result);
      pollError = null;
      if (active) _schedulePoll();
    } catch (e) {
      if (!_disposed) {
        error = assistantErrorMessage(e is ApiException ? e.message : null);
      }
    } finally {
      if (!_disposed) {
        busy = false;
        _notify();
      }
    }
  }

  void clearContext() {
    selectContext(null);
  }

  void reportError(String message) {
    error = message;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_selection;
    _timer?.cancel();
    service.dispose();
    super.dispose();
  }
}

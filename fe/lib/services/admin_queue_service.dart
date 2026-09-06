import '../config/api_config.dart';
import 'api_client.dart';

/// One job on the queue, as the administrator's board sees it.
class QueueEntry {
  const QueueEntry({
    required this.id,
    required this.status,
    this.jobId,
    this.userName,
    this.userEmail,
    this.modelName,
    this.modelVersion,
    this.inputFilesCount = 0,
    this.elapsedSeconds = 0,
    this.queuePosition,
    this.estimatedWaitMinutes,
  });

  final int id;

  /// `processing` or `pending`. Nothing else reaches this endpoint.
  final String status;

  final String? jobId;

  /// Null only where the column allows it; `user_id` cascades, so a queued
  /// row without an owner is not something the platform can produce.
  final String? userName;
  final String? userEmail;

  /// Null when the model was deregistered while its work was still queued —
  /// `model_id` is `set null`, so this one genuinely occurs.
  final String? modelName;
  final String? modelVersion;

  final int inputFilesCount;

  /// Waiting time for a queued job, running time for one in progress. The
  /// same clock; [status] says which question it answers.
  final int elapsedSeconds;

  /// Null for a running job. It is not waiting for anything, and numbering it
  /// alongside the queue would say it is still in the line.
  final int? queuePosition;
  final int? estimatedWaitMinutes;

  bool get isRunning => status == 'processing';

  String get who => userName ?? 'Deleted account';

  String get model => modelVersion == null || modelVersion!.isEmpty
      ? (modelName ?? 'Model removed')
      : '${modelName ?? 'Model removed'} $modelVersion';

  /// `4m` / `1h 12m`, because a queue is read at a glance.
  String get elapsedLabel {
    final minutes = elapsedSeconds ~/ 60;
    if (minutes < 1) return 'just now';
    if (minutes < 60) return '${minutes}m';

    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '${hours}h' : '${hours}h ${rest}m';
  }

  static int _toInt(dynamic v, [int fallback = 0]) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  static int? _toIntOrNull(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  factory QueueEntry.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map?;
    final model = json['model'] as Map?;

    return QueueEntry(
      id: _toInt(json['id']),
      status: json['status']?.toString() ?? 'pending',
      jobId: json['job_id']?.toString(),
      userName: user?['name']?.toString(),
      userEmail: user?['email']?.toString(),
      modelName: model?['name']?.toString(),
      modelVersion: model?['version']?.toString(),
      inputFilesCount: _toInt(json['input_files_count']),
      elapsedSeconds: _toInt(json['elapsed_seconds']),
      queuePosition: _toIntOrNull(json['queue_position']),
      estimatedWaitMinutes: _toIntOrNull(json['estimated_wait_minutes']),
    );
  }
}

/// The whole board: what is running, what is waiting, and whether anything is
/// consuming the queue at all.
class QueueBoard {
  const QueueBoard({
    this.running = const [],
    this.waiting = const [],
    this.minutesPerJob = 0,
    this.stalled = false,
    this.queueMessage,
  });

  final List<QueueEntry> running;
  final List<QueueEntry> waiting;

  /// The average a wait estimate is built from — worth showing, because it is
  /// measured rather than assumed and it explains every number beside it.
  final int minutesPerJob;

  /// Nothing has claimed a job for over a minute. A long queue and a dead
  /// worker look identical from a list of waiting jobs and call for opposite
  /// responses, so they are told apart here.
  final bool stalled;
  final String? queueMessage;

  bool get isEmpty => running.isEmpty && waiting.isEmpty;

  factory QueueBoard.fromJson(Map<String, dynamic> body) {
    final data = Map<String, dynamic>.from(body['data'] as Map? ?? const {});
    final meta = Map<String, dynamic>.from(body['meta'] as Map? ?? const {});

    List<QueueEntry> parse(String key) => (data[key] as List? ?? const [])
        .map((e) => QueueEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return QueueBoard(
      running: parse('running'),
      waiting: parse('waiting'),
      minutesPerJob: QueueEntry._toInt(data['minutes_per_job']),
      stalled: meta['stalled'] == true,
      queueMessage: meta['queue_message']?.toString(),
    );
  }
}

/// Live queue state for the admin console.
///
/// Read-only on purpose. Cancelling somebody else's run from here would be a
/// different feature with different consequences, and mixing it into a screen
/// whose job is to answer a question invites doing it by accident.
class AdminQueueService {
  // The shared instance, not a new one: the constructor is private and the
  // auth interceptor is registered once against it.
  final ApiClient _api = ApiClient.instance;

  Future<QueueBoard> board() async {
    // `get` already hands back the decoded body — there is no response object
    // to unwrap.
    return QueueBoard.fromJson(await _api.get(ApiConfig.adminQueue));
  }
}

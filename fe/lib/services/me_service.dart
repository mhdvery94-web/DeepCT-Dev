import '../config/api_config.dart';
import '../models/activity_log.dart';
import '../models/me_stats.dart';
import '../models/pagination.dart';
import 'api_client.dart';

/// A model a researcher may submit work to, as returned by `/api/me/models`.
///
/// Deliberately thinner than [ModelInfo]: no endpoint URL, no job counters.
class AvailableModel {
  final int id;
  final String name;
  final String version;
  final String status;
  final String? description;
  final double? accuracy;
  final bool isAvailable;

  /// When the server last probed the worker. The console shows how old this
  /// is: without it, a stalled scheduler looks exactly like a healthy model.
  final DateTime? lastHealthCheck;

  /// Why it cannot be used, as a code rather than a sentence — `tunnel_down`,
  /// `unreachable`, `no_endpoint`, `slow`. Turned into words by
  /// [modelStatusMessage].
  ///
  /// The checker's raw message is deliberately not sent to this endpoint: it
  /// carries the worker's hostname, which `/api/me/models` withholds on
  /// purpose.
  final String? healthCheckReason;

  const AvailableModel({
    required this.id,
    required this.name,
    required this.version,
    required this.status,
    this.description,
    this.accuracy,
    required this.isAvailable,
    this.lastHealthCheck,
    this.healthCheckReason,
  });

  factory AvailableModel.fromJson(Map<String, dynamic> json) {
    final acc = json['accuracy'];

    return AvailableModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      name: json['name']?.toString() ?? '-',
      version: json['version']?.toString() ?? '',
      status: json['status']?.toString() ?? 'offline',
      description: json['description']?.toString(),
      // MySQL DECIMAL arrives as a string through PDO.
      accuracy: acc is num ? acc.toDouble() : double.tryParse('${acc ?? ''}'),
      isAvailable: json['is_available'] == true,
      lastHealthCheck: json['last_health_check'] == null
          ? null
          : DateTime.tryParse(json['last_health_check'].toString()),
      healthCheckReason: json['health_check_reason']?.toString(),
    );
  }

  String get label => version.isEmpty ? name : '$name $version';

  /// Answering, and answering promptly. [isAvailable] is wider: it also
  /// covers a worker that answers slowly, which can still take work.
  bool get isOnline => status == 'online';
}

/// Wraps the self-service endpoints under `/api/me`.
///
/// These are the only data endpoints an ordinary researcher can reach:
/// everything under `/api/admin` is gated behind the admin role. Each call is
/// scoped server-side to the authenticated user, so there is no user id to
/// pass in.
class MeService {
  final ApiClient _api = ApiClient.instance;

  /// GET /me/stats
  Future<MeStats> stats() async {
    final body = await _api.get(ApiConfig.meStats);
    return MeStats.fromJson(Map<String, dynamic>.from(body['data'] as Map));
  }

  /// GET /me/models — active models the researcher may submit work to.
  ///
  /// Returns the narrow view: no endpoint URLs, which stay admin-only.
  Future<List<AvailableModel>> models() async {
    final body = await _api.get(ApiConfig.meModels);

    return _parseModels(body);
  }

  /// POST /me/models/refresh — probe the endpoints, then answer as [models].
  ///
  /// The difference matters at the one moment it is used. [models] reports what
  /// the scheduler last wrote, and the scheduler runs once a minute; this asks
  /// the endpoints directly. Someone about to spend twenty minutes uploading
  /// should not be told a minute-old "online" about a tunnel that has since
  /// expired.
  ///
  /// It can take a few seconds when an endpoint is unreachable — that is the
  /// probe timing out, and it is the honest answer rather than a slow one.
  Future<List<AvailableModel>> refreshModels() async {
    final body = await _api.post(ApiConfig.meModelsRefresh);

    return _parseModels(body);
  }

  List<AvailableModel> _parseModels(Map<String, dynamic> body) {
    return (body['data'] as List? ?? [])
        .map(
          (e) => AvailableModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  /// POST /me/password — change your own password.
  ///
  /// [currentPassword] is required by the backend even though the caller is
  /// already authenticated, so a token left on a shared machine cannot take
  /// the account over permanently. On success every other device's token is
  /// revoked; the one making this request survives.
  Future<String> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    final body = await _api.post(
      ApiConfig.mePassword,
      data: {
        'current_password': currentPassword,
        'password': newPassword,
        'password_confirmation': newPasswordConfirmation,
      },
    );

    return body['message']?.toString() ?? 'Password changed.';
  }

  /// GET /me/activities — the caller's own audit trail, newest first.
  Future<PaginatedResult<ActivityLog>> activities({
    int page = 1,
    int perPage = 20,
    String? type,
  }) async {
    final body = await _api.get(
      ApiConfig.meActivities,
      query: {'page': page, 'per_page': perPage, 'type': type},
    );

    final items = (body['data'] as List? ?? [])
        .map((e) => ActivityLog.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return PaginatedResult(
      items: items,
      pagination: body['pagination'] != null
          ? Pagination.fromJson(
              Map<String, dynamic>.from(body['pagination'] as Map),
            )
          : const Pagination.empty(),
    );
  }
}

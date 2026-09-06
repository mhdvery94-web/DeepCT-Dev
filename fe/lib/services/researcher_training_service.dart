import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../models/prediction_frame.dart';
import '../utils/archive_source.dart';
import 'api_client.dart';
import 'upload_resume_store.dart';

/// Metrics, whatever shape they arrive in.
///
/// The API declares a map, and for a run that has reported nothing the backend
/// once sent `[]` — PHP has one array type and its empty form encodes as a JSON
/// list. `as Map?` on a List does not yield null in Dart, it **throws**, and
/// the throw escaped a `catch` that only covered `ApiException`: the list of
/// runs then spun for ever with no error shown anywhere.
///
/// The backend now sends an object. This stays because parsing is the wrong
/// place to be strict — a screen must not be able to hang on the shape of a
/// field it only displays.
Map<String, dynamic> asMetrics(dynamic raw) {
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return const {};
}

/// One epoch's numbers, as the notebook reported them.
///
/// The keys are the notebook's, not ours — `loss`, `psnr`, `ssim` today. Any
/// other key still arrives and is still shown; a fixed set here would have to
/// be edited every time the training code learns to measure something new.
class TrainingPoint {
  const TrainingPoint({required this.epoch, required this.metrics});

  final int epoch;
  final Map<String, dynamic> metrics;

  double? value(String key) {
    final raw = metrics[key];
    if (raw is num) return raw.toDouble();
    return double.tryParse('${raw ?? ''}');
  }

  factory TrainingPoint.fromJson(Map<String, dynamic> json) => TrainingPoint(
    epoch: (json['epoch'] as num?)?.toInt() ?? 0,
    metrics: asMetrics(json['metrics']),
  );
}

/// A training run belonging to the signed-in researcher.
class TrainingRun {
  const TrainingRun({
    required this.id,
    required this.name,
    required this.status,
    required this.totalEpochs,
    required this.currentEpoch,
    required this.progressPercent,
    this.metrics = const {},
    this.trainerName,
    this.errorMessage,
    this.createdAt,
    this.history = const [],
    this.queuePosition,
  });

  final int id;
  final String name;
  final String status;
  final int totalEpochs;
  final int currentEpoch;
  final double progressPercent;
  final Map<String, dynamic> metrics;
  final String? trainerName;
  final String? errorMessage;
  final DateTime? createdAt;
  final List<TrainingPoint> history;

  /// Place in line, for a run that has not started. Null once it is
  /// running or finished — a run the trainer already has is not waiting
  /// for anything, and numbering it alongside the queue would say it is.
  final int? queuePosition;

  bool get isFinished =>
      status == 'completed' || status == 'failed' || status == 'cancelled';

  factory TrainingRun.fromJson(Map<String, dynamic> json) => TrainingRun(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: json['name']?.toString() ?? '',
    status: json['status']?.toString() ?? 'queued',
    totalEpochs: (json['total_epochs'] as num?)?.toInt() ?? 0,
    currentEpoch: (json['current_epoch'] as num?)?.toInt() ?? 0,
    progressPercent: (json['progress_percent'] as num?)?.toDouble() ?? 0,
    metrics: asMetrics(json['metrics']),
    trainerName: (json['trainer'] as Map?)?['name']?.toString(),
    errorMessage: json['error_message']?.toString(),
    createdAt: json['created_at'] == null
        ? null
        : DateTime.tryParse(json['created_at'].toString()),
    history: (json['history'] as List? ?? const [])
        .map((e) => TrainingPoint.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    queuePosition: (json['queue_position'] as num?)?.toInt(),
  );
}

/// Training, from the researcher's side.
///
/// Named for its half of the app on purpose: `training_service.dart` is the
/// administrator's, and the two answer different endpoints.
///
/// The dataset goes up through the **same** resumable session a prediction
/// upload uses, told what the archive is for. A training set is the largest
/// thing this platform accepts and the least likely to arrive in one piece.
///
/// The chunk loop here is still its own rather than shared with
/// [PredictionService]. Both now keep a resume record — [UploadResumeStore]
/// holds one slot per purpose — and the two loops have converged far enough
/// that lifting them into one is worth doing. It is not done here: that
/// refactor touches the only upload path ever proven end to end against a real
/// GPU, and it deserves its own round rather than riding along with a feature.
class ResearcherTrainingService {
  final ApiClient _api = ApiClient.instance;
  final UploadResumeStore _store = UploadResumeStore();

  /// How many times one chunk is retried before the upload gives up.
  static const int _chunkAttempts = 3;

  /// A dataset upload that was started on this device and never finished.
  Future<PendingUpload?> pendingUpload() =>
      _store.read(purpose: UploadPurpose.training);

  /// Forget it without finishing it. The server sweeps its half of the
  /// session on its own schedule.
  Future<void> discardPending() =>
      _store.clear(purpose: UploadPurpose.training);

  Future<({List<TrainingRun> runs, bool trainerAvailable, int queuedTotal, int runningTotal})>
  list() async {
    final body = await _api.get(ApiConfig.meTrainingJobs);

    return (
      runs: (body['data'] as List? ?? const [])
          .map((e) => TrainingRun.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      // False means nothing will pick a queued run up. The screen says so
      // rather than leaving someone watching a queue that cannot move.
      trainerAvailable: (body['meta'] as Map?)?['trainer_available'] == true,
      queuedTotal: ((body['meta'] as Map?)?['queued_total'] as num?)?.toInt() ?? 0,
      runningTotal: ((body['meta'] as Map?)?['running_total'] as num?)?.toInt() ?? 0,
    );
  }

  Future<TrainingRun> show(int id) async {
    final body = await _api.get('${ApiConfig.meTrainingJobs}/$id');

    return TrainingRun.fromJson(Map<String, dynamic>.from(body['data'] as Map));
  }

  /// GET /me/training/jobs/{id}/dataset/frames
  ///
  /// Mapped to PredictionFrame with `kind: 'input'` — nothing here was
  /// generated by a model, so the ticks on the viewer's slider stay empty,
  /// which is correct rather than a gap.
  /// The flag rides along because an empty list has two meanings.
  ///
  /// `training:cleanup` frees a dataset archive once the retention window has
  /// passed and keeps the row, so the server answers with no frames — which is
  /// indistinguishable from an archive that never held any. Only the server
  /// knows which, so it says, and the screen picks its sentence from that
  /// rather than guessing.
  Future<({List<PredictionFrame> frames, bool archiveDeleted})> datasetFrames(
    int id,
  ) async {
    final body = await _api.get(
      '${ApiConfig.meTrainingJobs}/$id/dataset/frames',
    );

    final frames = (body['data'] as List? ?? const [])
        .map(
          (e) => PredictionFrame(
            name: (e as Map)['name'].toString(),
            kind: 'input',
            size: (e['size'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList();

    final meta = body['meta'];

    return (
      frames: frames,
      archiveDeleted:
          meta is Map && meta['archive_deleted'] == true,
    );
  }

  /// GET /me/training/jobs/{id}/dataset/frames/{name}/preview
  Future<Uint8List> datasetFramePreview(int id, String name) async {
    final result = await _api.getBytes(
      '${ApiConfig.meTrainingJobs}/$id/dataset/frames/'
      '${Uri.encodeComponent(name)}/preview',
    );

    return result.bytes;
  }

  /// GET /me/training/jobs/{id}/samples — which epochs produced a frame.
  Future<List<int>> samples(int id) async {
    final body = await _api.get('${ApiConfig.meTrainingJobs}/$id/samples');

    return (body['data'] as List? ?? const [])
        .map((e) => ((e as Map)['epoch'] as num).toInt())
        .toList();
  }

  /// GET /me/training/jobs/{id}/samples/{epoch} — the PNG itself.
  Future<Uint8List> sampleImage(int id, int epoch) async {
    final result = await _api.getBytes(
      '${ApiConfig.meTrainingJobs}/$id/samples/$epoch',
    );

    return result.bytes;
  }

  Future<void> cancel(int id) async {
    await _api.post('${ApiConfig.meTrainingJobs}/$id/cancel');
  }

  /// Upload a dataset and start a run.
  ///
  /// Returns the server's message and, when there is one, the reason nothing
  /// has started yet. A run with no trainer reachable is queued rather than
  /// refused, and saying so is the difference between a job that looks stuck
  /// and one that is honestly waiting.
  /// Takes an [ArchiveSource] rather than the bytes themselves.
  ///
  /// The loop below always asked for one chunk at a time; what it asked was a
  /// `Uint8List` that already held the entire archive, so the memory cost was
  /// the whole dataset no matter how small the chunks were. A source answers
  /// the same question off disk on a native target, and nothing but the
  /// current chunk is ever resident.
  Future<({int id, String message, String? warning})> start({
    required String name,
    required int totalEpochs,
    required ArchiveSource source,
    void Function(double progress)? onProgress,
  }) async {
    final total = source.length;

    final started = await _api.post(
      ApiConfig.predictionUploads,
      data: {
        'purpose': 'training',
        'name': name,
        'total_epochs': totalEpochs,
        'total_size': total,
        'filename': source.filename,
      },
    );

    final session = Map<String, dynamic>.from(started['data'] as Map);
    final uploadId = session['upload_id'].toString();
    final chunkSize = (session['chunk_size'] as num?)?.toInt() ?? 1 << 20;

    // Written before the first chunk goes out, so an upload interrupted ten
    // seconds in is still resumable. The digest is streamed off the source —
    // hashing the archive whole would put back the memory cost the source
    // exists to remove.
    await _store.save(
      PendingUpload(
        uploadId: uploadId,
        filename: source.filename,
        totalSize: total,
        digest: await digestOf(source),
        savedAt: DateTime.now(),
        purpose: UploadPurpose.training,
        name: name,
        totalEpochs: totalEpochs,
      ),
    );

    return _pushChunks(
      uploadId: uploadId,
      chunkSize: chunkSize,
      source: source,
      from: 0,
      onProgress: onProgress,
    );
  }

  /// Continues a dataset upload that was interrupted, from wherever the server
  /// got to.
  ///
  /// [source] must be the same archive. Splicing a different one into a
  /// half-written session produces a ZIP that unpacks to nonsense, and the
  /// first thing to notice would be a GPU hours into a run.
  Future<({int id, String message, String? warning})> resume({
    required PendingUpload pending,
    required ArchiveSource source,
    void Function(double progress)? onProgress,
  }) async {
    if (!pending.matches(
      size: source.length,
      digest: await digestOf(source),
    )) {
      throw const ApiException(
        'That is a different archive. Choose the same file, or discard the '
        'unfinished upload and start again.',
      );
    }

    final status = await _api.get(
      '${ApiConfig.predictionUploads}/${pending.uploadId}',
    );
    final data = Map<String, dynamic>.from(status['data'] as Map);

    final received = (data['received'] as num?)?.toInt() ?? 0;
    final chunkSize = (data['chunk_size'] as num?)?.toInt() ?? 1 << 20;

    onProgress?.call((received / source.length).clamp(0.0, 1.0));

    return _pushChunks(
      uploadId: pending.uploadId,
      chunkSize: chunkSize,
      source: source,
      from: received,
      onProgress: onProgress,
    );
  }

  /// The chunk loop, shared by a fresh upload and a resumed one.
  Future<({int id, String message, String? warning})> _pushChunks({
    required String uploadId,
    required int chunkSize,
    required ArchiveSource source,
    required int from,
    void Function(double progress)? onProgress,
  }) async {
    final total = source.length;
    var offset = from;

    while (offset < total) {
      final end = (offset + chunkSize).clamp(0, total);
      final slice = await source.read(offset, end);

      // Whether the server took this chunk. On the other path — a retry that
      // found the server further along than we thought — `offset` has already
      // moved there, and assuming `end` would skip what sits in between.
      var accepted = false;

      for (var attempt = 1; ; attempt++) {
        try {
          await _api.sendMultipart(
            '${ApiConfig.predictionUploads}/$uploadId',
            method: 'PATCH',
            data: FormData.fromMap({
              'offset': offset,
              'chunk': MultipartFile.fromBytes(slice, filename: 'chunk'),
            }),
            onSendProgress: (sent, total) {
              if (total <= 0) return;
              final done = offset + (sent / total) * slice.length;
              onProgress?.call((done / source.length).clamp(0.0, 1.0));
            },
          );
          accepted = true;
          break;
        } on ApiException {
          if (attempt >= _chunkAttempts) rethrow;

          await Future<void>.delayed(Duration(seconds: attempt));

          // The failed request may have landed anyway. The server is the
          // authority on how much it holds, and re-sending from a stale offset
          // earns a 409.
          final synced = await _receivedSoFar(uploadId);
          if (synced != null && synced != offset) {
            offset = synced;
            break;
          }
        }
      }

      if (accepted) offset = end;
      onProgress?.call(offset / total);
    }

    final body = await _api.post(
      '${ApiConfig.predictionUploads}/$uploadId/finalize',
    );

    // The session is finished; a record of it would only be offered back as
    // something to resume.
    await discardPending();

    return (
      id: ((body['data'] as Map)['id'] as num).toInt(),
      message: body['message']?.toString() ?? 'Training run queued.',
      warning: body['dispatch_message']?.toString(),
    );
  }

  /// How many bytes the server has, or null if even that call failed.
  Future<int?> _receivedSoFar(String uploadId) async {
    try {
      final status = await _api.get('${ApiConfig.predictionUploads}/$uploadId');

      return ((status['data'] as Map)['received'] as num?)?.toInt();
    } on ApiException {
      return null;
    }
  }
}

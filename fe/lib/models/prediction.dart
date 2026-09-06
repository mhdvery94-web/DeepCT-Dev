/// One interpolation job belonging to the signed-in researcher.
///
/// Mirrors the payloads of `GET /api/predictions` and
/// `GET /api/predictions/{id}`; the detail endpoint returns a few extra
/// fields, which stay null on list rows.
class Prediction {
  final int id;
  final String jobId;

  /// One of `pending`, `processing`, `completed`, `failed`.
  final String status;

  final String? fileName;
  final int inputFilesCount;
  final int outputFilesCount;

  /// Names of the frames the model generated, once completed.
  final List<String> interpolatedFrames;

  final String? modelName;
  final String? modelVersion;

  final String? errorMessage;
  final int? queuePosition;
  final int? estimatedWaitMinutes;

  /// Set only on the detail endpoint, only while [status] is `pending`, and
  /// only when nothing is actually consuming the queue -- see
  /// `App\Services\QueueHealth` on the backend. Null means either the job
  /// isn't pending, or a worker is (as far as the backend can tell) alive.
  final String? queueStalledMessage;

  final DateTime? createdAt;
  final DateTime? expiresAt;
  final DateTime? filesDeletedAt;

  /// Only present on the detail endpoint; null means "not reported".
  final bool? filesAvailable;

  /// Where each generated frame came from. Empty on jobs that finished before
  /// the platform started recording it, so nothing may assume it is populated
  /// just because the job completed.
  final List<FrameProvenance> frameProvenance;

  /// How the interpolation scored against a frame the archive already held.
  ///
  /// Null is the common case and not an error: it means the upload offered no
  /// three consecutive frames to hold one out from.
  final HoldOutValidation? validation;

  /// Every run made on the same input frames, this one included, ordered
  /// oldest first. Empty when there is only one — a table with a single row
  /// is not a comparison and reads as though something failed to load.
  final List<ComparisonRun> comparison;

  /// The job this one re-runs, or null when it is the original.
  final int? rerunOfId;

  /// Thumbnail names kept for good, so a run can still be looked at after its
  /// frames are deleted. Empty for jobs finished before this existed.
  final List<String> evidence;

  const Prediction({
    required this.id,
    required this.jobId,
    required this.status,
    this.fileName,
    required this.inputFilesCount,
    required this.outputFilesCount,
    this.interpolatedFrames = const [],
    this.modelName,
    this.modelVersion,
    this.errorMessage,
    this.queuePosition,
    this.estimatedWaitMinutes,
    this.queueStalledMessage,
    this.createdAt,
    this.expiresAt,
    this.filesDeletedAt,
    this.filesAvailable,
    this.frameProvenance = const [],
    this.validation,
    this.comparison = const [],
    this.rerunOfId,
    this.evidence = const [],
  });

  static int _toInt(dynamic v, [int fallback = 0]) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  static int? _toIntOrNull(dynamic v) => v == null ? null : _toInt(v);

  static DateTime? _toDate(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString());

  factory Prediction.fromJson(Map<String, dynamic> json) {
    // The list endpoint nests the model as an object; the detail endpoint
    // does the same, but either can be absent when the model was deleted.
    final model = json['model'];

    // `interpolated_frames` is cast to array server-side, but tolerate the
    // raw JSON string an older record might still hold.
    final rawFrames = json['interpolated_frames'];
    final frames = rawFrames is List
        ? rawFrames.map((e) => e.toString()).toList()
        : const <String>[];

    return Prediction(
      id: _toInt(json['id']),
      jobId: json['job_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      fileName: json['file_name']?.toString(),
      inputFilesCount: _toInt(json['input_files_count']),
      outputFilesCount: _toInt(json['output_files_count']),
      interpolatedFrames: frames,
      modelName: model is Map ? model['name']?.toString() : null,
      modelVersion: model is Map ? model['version']?.toString() : null,
      errorMessage: json['error_message']?.toString(),
      queuePosition: _toIntOrNull(json['queue_position']),
      estimatedWaitMinutes: _toIntOrNull(json['estimated_wait_minutes']),
      queueStalledMessage: json['queue_stalled_message']?.toString(),
      createdAt: _toDate(json['created_at']),
      expiresAt: _toDate(json['expires_at']),
      filesDeletedAt: _toDate(json['files_deleted_at']),
      filesAvailable: json['files_available'] is bool
          ? json['files_available'] as bool
          : null,
      frameProvenance: json['frame_provenance'] is List
          ? (json['frame_provenance'] as List)
                .whereType<Map>()
                .map((e) => FrameProvenance.fromJson(
                      Map<String, dynamic>.from(e),
                    ))
                .toList()
          : const <FrameProvenance>[],
      validation: json['validation'] is Map
          ? HoldOutValidation.fromJson(
              Map<String, dynamic>.from(json['validation'] as Map),
            )
          : null,
      comparison: json['comparison'] is List
          ? (json['comparison'] as List)
                .whereType<Map>()
                .map((e) => ComparisonRun.fromJson(
                      Map<String, dynamic>.from(e),
                    ))
                .toList()
          : const <ComparisonRun>[],
      rerunOfId: _toIntOrNull(json['rerun_of_id']),
      evidence: json['evidence'] is List
          ? (json['evidence'] as List).map((e) => e.toString()).toList()
          : const <String>[],
    );
  }

  /// Files are on the server and nothing is queued yet — the state a
  /// prediction sits in while the researcher looks at what they just sent.
  bool get isUploaded => status == 'uploaded';

  bool get isPending => status == 'pending';
  bool get isProcessing => status == 'processing';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';

  /// Still moving, so the UI should keep polling.
  bool get isActive => isPending || isProcessing;

  /// True when the results can still be downloaded.
  bool get canDownload =>
      isCompleted && filesDeletedAt == null && (filesAvailable ?? true);

  /// How long until the 24-hour retention window closes, or null once gone.
  Duration? get timeUntilExpiry {
    if (expiresAt == null || filesDeletedAt != null) return null;
    final remaining = expiresAt!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// e.g. "23h left", "45m left", "expired"
  String get expiryLabel {
    if (filesDeletedAt != null) return 'expired';
    final remaining = timeUntilExpiry;
    if (remaining == null) return '-';
    if (remaining == Duration.zero) return 'expiring now';
    if (remaining.inHours >= 1) return '${remaining.inHours}h left';
    return '${remaining.inMinutes}m left';
  }

  String get displayName => fileName ?? 'Job ${jobId.split('-').first}';

  String get modelLabel {
    if (modelName == null) return 'Unknown model';
    return modelVersion == null ? modelName! : '$modelName $modelVersion';
  }
}

/// Where one generated frame came from.
///
/// The platform fills a gap by drawing its midpoint first, then drawing the
/// midpoints of the two halves that leaves — so a frame can be interpolated
/// between two frames that came off the scanner, or between one that did and
/// one the model had drawn a moment earlier. Those are not equally
/// trustworthy, and [generation] is the number that says which is which: 1
/// when both boundaries were scanned, 2 when at least one was itself
/// generated, and so on upward as error compounds.
class FrameProvenance {
  /// Filename of the generated frame, e.g. `frame_003.tif`.
  final String frame;

  /// Its number in the sequence.
  final int index;

  /// The two frames it was drawn between.
  final int leftIndex;
  final int rightIndex;

  /// 1 when both boundaries came off the scanner; higher when the model was
  /// fed its own output.
  final int generation;

  /// How many of the two boundaries the model had drawn itself: 0, 1 or 2.
  final int syntheticParents;

  const FrameProvenance({
    required this.frame,
    required this.index,
    required this.leftIndex,
    required this.rightIndex,
    required this.generation,
    required this.syntheticParents,
  });

  /// True when neither boundary was invented — the most trustworthy case.
  bool get isFirstGeneration => generation <= 1;

  factory FrameProvenance.fromJson(Map<String, dynamic> json) {
    final from = json['from'];
    final pair = from is List && from.length >= 2
        ? from.map((e) => Prediction._toInt(e)).toList()
        : const <int>[0, 0];

    return FrameProvenance(
      frame: json['frame']?.toString() ?? '',
      index: Prediction._toInt(json['index']),
      leftIndex: pair[0],
      rightIndex: pair[1],
      generation: Prediction._toInt(json['generation'], 1),
      syntheticParents: Prediction._toInt(json['synthetic_parents']),
    );
  }
}

/// How the interpolation scored against a frame the archive already held.
///
/// The frames a researcher wants filled are, by definition, ones nobody has —
/// so there is no ground truth for them and there never will be. What the
/// platform can do is hold out a frame that *was* there: wherever the upload
/// contains three consecutive frames, the middle one is set aside, drawn again
/// from its two neighbours, and measured against the one that was really
/// there.
///
/// It is one measurement on one frame, not a study. Read it as evidence that
/// the model behaved on this data, not as its accuracy.
class HoldOutValidation {
  /// Set when the measurement could not be taken. Everything else is null.
  final String? error;

  /// The frame that was hidden and drawn again.
  final String? heldOutFrame;
  final int? index;
  final int? leftIndex;
  final int? rightIndex;

  /// Mean absolute difference, in raw 16-bit counts.
  final double? mae;

  /// Root mean squared error, same units as [mae].
  final double? rmse;

  /// Decibels, against the full 16-bit range. Null when the two frames were
  /// identical — there is no error to express.
  final double? psnr;

  /// The reference frame's own span, without which [mae] cannot be read: 40
  /// counts is a large error on a frame covering 300 and a negligible one on
  /// a frame covering 60,000.
  final int? referenceMin;
  final int? referenceMax;

  final int? pixels;

  const HoldOutValidation({
    this.error,
    this.heldOutFrame,
    this.index,
    this.leftIndex,
    this.rightIndex,
    this.mae,
    this.rmse,
    this.psnr,
    this.referenceMin,
    this.referenceMax,
    this.pixels,
  });

  bool get failed => error != null;

  /// How much of the reference frame's own range the average error covers.
  /// Null when the range is unknown or degenerate.
  double? get maeAsFractionOfRange {
    final m = mae;
    final lo = referenceMin;
    final hi = referenceMax;
    if (m == null || lo == null || hi == null || hi <= lo) return null;
    return m / (hi - lo);
  }

  static double? _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static int? _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  factory HoldOutValidation.fromJson(Map<String, dynamic> json) {
    final from = json['from'];
    final pair = from is List && from.length >= 2 ? from : const [null, null];

    return HoldOutValidation(
      error: json['error']?.toString(),
      heldOutFrame: json['held_out_frame']?.toString(),
      index: _toInt(json['index']),
      leftIndex: _toInt(pair[0]),
      rightIndex: _toInt(pair[1]),
      mae: _toDouble(json['mae']),
      rmse: _toDouble(json['rmse']),
      psnr: _toDouble(json['psnr']),
      referenceMin: _toInt(json['reference_min']),
      referenceMax: _toInt(json['reference_max']),
      pixels: _toInt(json['pixels']),
    );
  }
}

/// One run in a family of runs sharing the same input frames.
///
/// The model registry has always been able to hold several inference
/// endpoints. This is what makes that useful: the same frames put through two
/// of them, with the one number worth weighing them by.
class ComparisonRun {
  final int id;
  final String status;

  /// True for the run currently on screen.
  final bool isCurrent;

  final String? modelName;
  final String? modelVersion;

  final int outputFilesCount;
  final int? processingTimeSeconds;

  /// Null where that run's archive offered no frame to hold out — which is
  /// what makes two runs incomparable, and is worth saying rather than
  /// printing a dash.
  final double? mae;
  final double? psnr;

  const ComparisonRun({
    required this.id,
    required this.status,
    required this.isCurrent,
    this.modelName,
    this.modelVersion,
    this.outputFilesCount = 0,
    this.processingTimeSeconds,
    this.mae,
    this.psnr,
  });

  bool get isMeasured => mae != null;

  String get modelLabel {
    if (modelName == null) return 'Unknown model';
    return modelVersion == null ? modelName! : '$modelName $modelVersion';
  }

  factory ComparisonRun.fromJson(Map<String, dynamic> json) => ComparisonRun(
    id: Prediction._toInt(json['id']),
    status: json['status']?.toString() ?? 'pending',
    isCurrent: json['is_current'] == true,
    modelName: json['model']?.toString(),
    modelVersion: json['model_version']?.toString(),
    outputFilesCount: Prediction._toInt(json['output_files_count']),
    processingTimeSeconds: HoldOutValidation._toInt(json['processing_time_seconds']),
    mae: HoldOutValidation._toDouble(json['mae']),
    psnr: HoldOutValidation._toDouble(json['psnr']),
  );
}

/// How much room is left on the results volume, and how much of what is used
/// will come back on its own.
///
/// The total is the least interesting number here. A volume at 90% mostly
/// holding prediction output — deleted 24 hours after each job — is a
/// different situation from one at 90% of training datasets, which nothing
/// reclaims automatically. [reclaimableBytes] is what tells them apart.
class StorageReport {
  /// False when the results volume is not mounted. Uploads are refused in
  /// that state rather than written to whatever is behind the mount point.
  final bool mounted;

  /// Whether the mount check is switched on at all. Off on a single-disk
  /// install, where there is nothing to be absent.
  final bool sentinelEnforced;

  /// Null where the filesystem will not report; the panel says so rather than
  /// drawing a bar it cannot fill.
  final int? freeBytes;
  final int? totalBytes;

  /// Reclaimed by the retention sweep within a day of each job.
  final int predictionBytes;

  /// Kept for good, and small by design.
  final int evidenceBytes;

  /// Reclaimed by nobody. Up to 2 GB per run, and the only way out is an
  /// administrator deleting one.
  final int datasetBytes;

  final int temporaryBytes;

  const StorageReport({
    required this.mounted,
    required this.sentinelEnforced,
    this.freeBytes,
    this.totalBytes,
    this.predictionBytes = 0,
    this.evidenceBytes = 0,
    this.datasetBytes = 0,
    this.temporaryBytes = 0,
  });

  int? get usedBytes {
    final free = freeBytes;
    final total = totalBytes;
    if (free == null || total == null) return null;
    return total - free;
  }

  /// 0..1, or null when the volume will not report its size.
  double? get usedFraction {
    final used = usedBytes;
    final total = totalBytes;
    if (used == null || total == null || total <= 0) return null;
    return (used / total).clamp(0.0, 1.0);
  }

  /// What the retention sweep will hand back without anyone doing anything.
  int get reclaimableBytes => predictionBytes + temporaryBytes;

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static int? _toIntOrNull(dynamic v) => v == null ? null : _toInt(v);

  factory StorageReport.fromJson(Map<String, dynamic> json) {
    final breakdown = json['breakdown'] is Map
        ? Map<String, dynamic>.from(json['breakdown'] as Map)
        : const <String, dynamic>{};

    return StorageReport(
      mounted: json['mounted'] != false,
      sentinelEnforced: json['sentinel_enforced'] == true,
      freeBytes: _toIntOrNull(json['free_bytes']),
      totalBytes: _toIntOrNull(json['total_bytes']),
      predictionBytes: _toInt(breakdown['predictions']),
      evidenceBytes: _toInt(breakdown['evidence']),
      datasetBytes: _toInt(breakdown['training_datasets']),
      temporaryBytes: _toInt(breakdown['temporary']),
    );
  }

  /// `1.4 GB`. Shared by every figure on the panel so they read alike.
  static String human(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unit = 0;

    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }

    return '${value.toStringAsFixed(unit == 0 ? 0 : 1)} ${units[unit]}';
  }
}

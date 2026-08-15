/// One frame belonging to a prediction, as listed by
/// `GET /api/predictions/{id}/frames`.
class PredictionFrame {
  final String name;

  /// `input` for an uploaded boundary frame, `output` for a generated one.
  final String kind;

  final int size;

  const PredictionFrame({
    required this.name,
    required this.kind,
    required this.size,
  });

  factory PredictionFrame.fromJson(Map<String, dynamic> json) {
    final size = json['size'];

    return PredictionFrame(
      name: json['name']?.toString() ?? '-',
      kind: json['kind']?.toString() ?? 'output',
      size: size is num ? size.toInt() : int.tryParse('${size ?? ''}') ?? 0,
    );
  }

  bool get isGenerated => kind == 'output';

  /// Frame number parsed from the filename, used for ordering.
  int? get frameNumber {
    final match = RegExp(r'(\d+)(?!.*\d)').firstMatch(name);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  String get sizeLabel {
    if (size < 1024) return '$size B';
    if (size < 1048576) return '${(size / 1024).toStringAsFixed(0)} KB';
    return '${(size / 1048576).toStringAsFixed(1)} MB';
  }
}

/// The public assistant snapshot contract. Only named fields are admitted;
/// historical arrays, arbitrary errors and file locations are never rendered.
class EvidenceFact {
  final String label, value;
  const EvidenceFact(this.label, this.value);
}

const evidenceUnavailable = 'Tidak tersedia';
Map<String, dynamic> evidenceMap(dynamic value) => value is Map
    ? {
        for (final entry in value.entries)
          if (entry.key is String) entry.key as String: entry.value,
      }
    : {};
num? _number(dynamic v, [num min = 0, num max = 9007199254740991]) =>
    v is num && v.isFinite && v >= min && v <= max ? v : null;
int? _integer(dynamic v, [int min = 0]) =>
    v is int && v >= min && v <= 9007199254740991 ? v : null;
String _enum(dynamic v, List<String> values, String fallback) =>
    v is String && values.contains(v) ? v : fallback;
String? _text(dynamic v, int max) =>
    v is String &&
        v.isNotEmpty &&
        v.length <= max &&
        !RegExp(r'[<>\\/\x00-\x1f]').hasMatch(v)
    ? v
    : null;
// Slash-separated words are valid prose; metadata retains the strict validator.
// Reject path syntax, markup, raw JSON and exception text in document fields.
String? _documentProse(dynamic value, int max) {
  if (value is! String ||
      value.isEmpty ||
      value.length > max ||
      RegExp(r'[<>{}\\\x00-\x1f]').hasMatch(value) ||
      RegExp(
        r'(exception|[a-z]*error:|stack trace)',
        caseSensitive: false,
      ).hasMatch(value)) {
    return null;
  }
  final prosePair = RegExp(
    r'''^[('"“‘]*[\p{L}\p{N}]+/[\p{L}\p{N}]+[)'"”’.,;:!?]*$''',
    unicode: true,
  );
  return value
          .split(RegExp(r'\s+'))
          .every((token) => !token.contains('/') || prosePair.hasMatch(token))
      ? value
      : null;
}

String evidenceNumber(num v) =>
    v == v.truncateToDouble() ? v.toStringAsFixed(0) : v.toString();
const _metricLabels = {
  'mae': 'MAE',
  'rmse': 'RMSE',
  'psnr': 'PSNR (dB)',
  'ssim': 'SSIM',
  'pixels': 'Jumlah piksel',
  'reference_min': 'Minimum referensi',
  'reference_max': 'Maksimum referensi',
};

class EvidenceMeasurement {
  final Map<String, num?> metrics;
  final String psnrStatus, ssimStatus;
  EvidenceMeasurement(dynamic raw) : this._(evidenceMap(raw));
  EvidenceMeasurement._(Map<String, dynamic> v)
    : metrics = Map.unmodifiable({
        for (final key in _metricLabels.keys)
          key: _number(
            evidenceMap(v['metrics'])[key],
            key == 'ssim'
                ? -1
                : key == 'pixels'
                ? 1
                : 0,
            key == 'ssim'
                ? 1
                : key == 'psnr'
                ? 1000
                : key == 'pixels'
                ? 9007199254740991
                : 65535,
          ),
      }),
      psnrStatus = _enum(evidenceMap(v['metric_status'])['psnr'], [
        'available',
        'infinite',
        'unavailable',
      ], 'unknown'),
      ssimStatus = _enum(evidenceMap(v['metric_status'])['ssim'], [
        'available',
        'image_too_small',
        'unavailable',
      ], 'unknown');
  List<EvidenceFact> get facts => [
    for (final entry in _metricLabels.entries)
      EvidenceFact(
        entry.value,
        entry.key == 'psnr' && psnrStatus == 'infinite'
            ? 'Tak terhingga (galat tepat nol)'
            : entry.key == 'ssim' && ssimStatus == 'image_too_small'
            ? 'Tidak tersedia · Citra terlalu kecil'
            : metrics[entry.key] == null
            ? evidenceUnavailable
            : evidenceNumber(metrics[entry.key]!),
      ),
  ];
}

List<EvidenceFact> _modelFacts(dynamic raw) {
  final v = evidenceMap(raw);
  if (v['provenance'] == 'historical_model_snapshot_unavailable') {
    return [
      const EvidenceFact(
        'Model CT',
        'Versi historis / provenans model tidak tersedia',
      ),
    ];
  }
  final facts = <EvidenceFact>[];
  for (final row in [
    ('name', 'Model CT', 120),
    ('version', 'Versi model', 64),
    ('slug', 'Slug model', 120),
    ('model_id', 'Identitas model', 120),
  ]) {
    final text = _text(v[row.$1], row.$3);
    // Unicode letters and numbers, matching the server's model sanitizer.
    if (text != null &&
        !RegExp(r'[^\p{L}\p{N} ._()+-]', unicode: true).hasMatch(text)) {
      facts.add(EvidenceFact(row.$2, text));
    }
  }
  final id = _integer(v['id'], 1);
  if (id != null) facts.add(EvidenceFact('ID model', '$id'));
  final provenance = _enum(v['provenance'], [
    'managed_manifest_sha256',
    'legacy_registry_metadata',
  ], '');
  if (provenance.isNotEmpty) {
    facts.add(EvidenceFact('Provenans model', provenance));
  }
  if (v['sha256'] is String &&
      RegExp(r'^[a-f0-9]{64}$').hasMatch(v['sha256'])) {
    facts.add(EvidenceFact('SHA256', v['sha256']));
  }
  return List.unmodifiable(facts);
}

List<EvidenceFact> _methodFacts(dynamic raw) {
  final v = evidenceMap(raw), s = evidenceMap(evidenceMap(raw)['ssim']);
  return List.unmodifiable([
    for (final row in <(String, Object, String)>[
      ('sample_domain', 'raw_uint16', 'Domain sampel'),
      ('data_range', 65535, 'Rentang data'),
      ('mae_decimals', 3, 'Desimal MAE'),
      ('rmse_decimals', 3, 'Desimal RMSE'),
      ('psnr_decimals', 2, 'Desimal PSNR'),
      ('baseline', 'linear_midpoint', 'Metode baseline'),
      ('midpoint_rounding', 'half_up', 'Pembulatan midpoint'),
    ])
      if (v[row.$1] == row.$2) EvidenceFact(row.$3, '${row.$2}'),
    for (final row in <(String, Object, String)>[
      ('window_size', 7, 'Jendela SSIM'),
      ('weighting', 'uniform', 'Bobot SSIM'),
      ('boundary', 'valid', 'Batas SSIM'),
      ('covariance', 'sample', 'Kovarians SSIM'),
      ('k1', 0.01, 'K1 SSIM'),
      ('k2', 0.03, 'K2 SSIM'),
    ])
      if (s[row.$1] == row.$2) EvidenceFact(row.$3, '${row.$2}'),
  ]);
}

class EvidenceReference {
  final int index, left, right;
  const EvidenceReference(this.index, this.left, this.right);
  static EvidenceReference? parse(dynamic raw) {
    final r = evidenceMap(raw), from = evidenceMap(raw)['from'];
    final index = _integer(r['index']);
    if (r['source'] != 'uploaded_midpoint' ||
        index == null ||
        from is! List ||
        from.length != 2) {
      return null;
    }
    final left = _integer(from[0]), right = _integer(from[1]);
    return left != null &&
            right != null &&
            left < index &&
            right > index &&
            index - left == right - index
        ? EvidenceReference(index, left, right)
        : null;
  }
}

class EvaluationReport {
  final String status, baselineStatus;
  final EvidenceMeasurement measurement, baseline;
  final EvidenceReference? reference;
  final List<EvidenceFact> method, model, baselineMethod;
  final bool comparisonCompleted;
  final Map<String, num?> comparison;
  EvaluationReport(dynamic raw, dynamic legacyMetrics)
    : this._(evidenceMap(raw), legacyMetrics);
  EvaluationReport._(Map<String, dynamic> v, dynamic legacyMetrics)
    : status = v['schema_version'] == 1
          ? _enum(v['evaluation_status'], [
              'completed',
              'no_reference',
              'evaluation_failed',
            ], 'legacy_unknown')
          : 'legacy_unknown',
      measurement = EvidenceMeasurement(
        v['schema_version'] == 1 ? v : {'metrics': legacyMetrics},
      ),
      reference = v['schema_version'] == 1
          ? EvidenceReference.parse(v['reference'])
          : null,
      method = v['schema_version'] == 1 ? _methodFacts(v['method']) : const [],
      model = v['schema_version'] == 1 ? _modelFacts(v['model']) : const [],
      baseline = EvidenceMeasurement(
        v['schema_version'] == 1 ? v['baseline'] : null,
      ),
      baselineStatus = v['schema_version'] == 1
          ? _enum(evidenceMap(v['baseline'])['status'], [
              'completed',
              'baseline_failed',
            ], 'unavailable')
          : 'unavailable',
      baselineMethod = v['schema_version'] == 1
          ? _methodFacts(evidenceMap(v['baseline'])['method'])
          : const [],
      comparisonCompleted =
          v['schema_version'] == 1 &&
          evidenceMap(v['comparison'])['status'] == 'completed' &&
          evidenceMap(v['comparison'])['precision'] == 'recorded_precision',
      comparison = Map.unmodifiable({
        for (final key in [
          'mae_reduction',
          'rmse_reduction',
          'psnr_gain_db',
          'ssim_gain',
        ])
          key:
              v['schema_version'] == 1 &&
                  evidenceMap(v['comparison'])['status'] == 'completed' &&
                  evidenceMap(v['comparison'])['precision'] ==
                      'recorded_precision'
              ? _number(evidenceMap(v['comparison'])[key], -65535, 65535)
              : null,
      });
  String get label => const {
    'completed': 'Evaluasi selesai',
    'no_reference': 'Tidak ada referensi unggahan',
    'evaluation_failed': 'Pengukuran gagal',
    'legacy_unknown': 'Evaluasi historis tidak diketahui',
  }[status]!;
  List<EvidenceFact> get comparisonFacts => [
    for (final entry in const {
      'mae_reduction': 'Pengurangan MAE',
      'rmse_reduction': 'Pengurangan RMSE',
      'psnr_gain_db': 'Kenaikan PSNR (dB)',
      'ssim_gain': 'Kenaikan SSIM',
    }.entries)
      EvidenceFact(
        entry.value,
        comparison[entry.key] == null
            ? evidenceUnavailable
            : evidenceNumber(comparison[entry.key]!),
      ),
  ];
}

sealed class AiEvidenceSource {}

class AiDocumentSource extends AiEvidenceSource {
  final String id, version, title, text;
  AiDocumentSource(this.id, this.version, this.title, this.text);
}

class AiAnalysisSource extends AiEvidenceSource {
  final int id;
  final String status;
  final int? inputFiles, outputFiles;
  final num? processingSeconds;
  final bool? expired, filesDeleted;
  final List<EvidenceFact> model;
  final EvaluationReport evaluation;
  AiAnalysisSource(this.id, Map<String, dynamic> v)
    : status = _enum(v['status'], [
        'uploaded',
        'pending',
        'processing',
        'completed',
        'failed',
      ], 'unknown'),
      inputFiles = _integer(v['input_files_count']),
      outputFiles = _integer(v['output_files_count']),
      processingSeconds = _number(v['processing_time_seconds']),
      expired = v['expired'] is bool ? v['expired'] : null,
      filesDeleted = v['files_deleted'] is bool ? v['files_deleted'] : null,
      model = _modelFacts(v['model']),
      evaluation = EvaluationReport(v['evaluation'], v['metrics']);
  List<EvidenceFact> get facts {
    final r = evaluation.reference;
    String yesNo(bool? v) => v == null
        ? evidenceUnavailable
        : v
        ? 'Ya'
        : 'Tidak';
    return [
      EvidenceFact('Status evaluasi', evaluation.label),
      EvidenceFact(
        'Referensi',
        r == null
            ? evidenceUnavailable
            : 'Midpoint unggahan #${r.index} · ${r.left} → ${r.right}',
      ),
      ...(evaluation.model.isNotEmpty
          ? evaluation.model
          : model.isNotEmpty
          ? model
          : [const EvidenceFact('Model CT', evidenceUnavailable)]),
      EvidenceFact(
        'Berkas input / hasil',
        '${inputFiles ?? evidenceUnavailable} / ${outputFiles ?? evidenceUnavailable}',
      ),
      EvidenceFact(
        'Waktu analisis',
        processingSeconds == null
            ? evidenceUnavailable
            : '${evidenceNumber(processingSeconds!)} detik',
      ),
      EvidenceFact(
        'Kedaluwarsa / dihapus',
        '${yesNo(expired)} / ${yesNo(filesDeleted)}',
      ),
    ];
  }
}

List<AiEvidenceSource> parseAiSources(dynamic raw) {
  if (raw is! List) return const [];
  final result = <AiEvidenceSource>[];
  for (final item in raw) {
    final v = evidenceMap(item);
    if (v['type'] == 'document') {
      final id = _text(v['id'], 80),
          version = _text(v['version'], 40),
          title = _documentProse(v['title'], 120),
          text = _documentProse(v['text'], 900);
      if (id != null &&
          RegExp(r'^deepct-sop-[a-z-]+$').hasMatch(id) &&
          version != null &&
          title != null &&
          text != null) {
        result.add(AiDocumentSource(id, version, title, text));
      }
    } else if (v['type'] == 'analysis_record') {
      final id = _integer(v['id'], 1);
      if (id != null) result.add(AiAnalysisSource(id, v));
    }
  }
  return List.unmodifiable(result);
}

String providerMetric(String key, dynamic value) {
  final number = _number(value);
  if (number == null) return evidenceUnavailable;
  return key.endsWith('_duration')
      ? '${(number / 1000000000).toStringAsFixed(1)} detik'
      : evidenceNumber(number);
}

String assistantErrorMessage(dynamic value) {
  final text = _text(value, 240);
  return text != null &&
          !RegExp(
            r'(exception|[a-z]*error:|stack trace|[{}])',
            caseSensitive: false,
          ).hasMatch(text)
      ? text
      : 'Permintaan tidak dapat diselesaikan. Coba lagi.';
}

String requestFailureLabel(dynamic code) =>
    const {
      'provider_timeout': 'Batas waktu jawaban terlampaui (provider_timeout)',
      'worker_timeout': 'Batas waktu pemrosesan terlampaui (worker_timeout)',
      'context_unavailable': 'Konteks tidak tersedia (context_unavailable)',
      'generation_busy': 'Pemrosesan sedang sibuk (generation_busy)',
      'access_revoked': 'Akses tidak tersedia (access_revoked)',
    }[code] ??
    'Jawaban gagal dibuat';
const analysisStatusLabels = {
  'uploaded': 'Unggahan siap ditinjau',
  'pending': 'Dalam antrean',
  'processing': 'Sedang diproses',
  'completed': 'Selesai',
  'failed': 'Gagal',
  'unknown': 'Status tidak diketahui',
};

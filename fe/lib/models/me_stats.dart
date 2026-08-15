/// Counters shown on the researcher's own dashboard.
///
/// Mirrors `GET /api/me/stats`. The analysis counters stay at zero until the
/// FASE 3 prediction pipeline starts writing `analysis_records`; the shape is
/// already final so the UI will not need changing then.
class MeStats {
  final int activitiesTotal;
  final int activitiesToday;

  final int analysesTotal;
  final int analysesPending;
  final int analysesProcessing;
  final int analysesCompleted;
  final int analysesFailed;

  /// How many active models are currently reachable. The endpoint URLs
  /// themselves stay admin-only, so this is all a researcher can see.
  final int modelsOnline;
  final int modelsTotal;

  const MeStats({
    required this.activitiesTotal,
    required this.activitiesToday,
    required this.analysesTotal,
    required this.analysesPending,
    required this.analysesProcessing,
    required this.analysesCompleted,
    required this.analysesFailed,
    required this.modelsOnline,
    required this.modelsTotal,
  });

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  factory MeStats.fromJson(Map<String, dynamic> json) {
    final byStatus = json['analyses_by_status'] is Map
        ? Map<String, dynamic>.from(json['analyses_by_status'] as Map)
        : const <String, dynamic>{};

    return MeStats(
      activitiesTotal: _toInt(json['activities_total']),
      activitiesToday: _toInt(json['activities_today']),
      analysesTotal: _toInt(json['analyses_total']),
      analysesPending: _toInt(byStatus['pending']),
      analysesProcessing: _toInt(byStatus['processing']),
      analysesCompleted: _toInt(byStatus['completed']),
      analysesFailed: _toInt(byStatus['failed']),
      modelsOnline: _toInt(json['models_online']),
      modelsTotal: _toInt(json['models_total']),
    );
  }

  const MeStats.empty()
    : activitiesTotal = 0,
      activitiesToday = 0,
      analysesTotal = 0,
      analysesPending = 0,
      analysesProcessing = 0,
      analysesCompleted = 0,
      analysesFailed = 0,
      modelsOnline = 0,
      modelsTotal = 0;

  /// True when at least one model is reachable, i.e. a prediction could run.
  bool get canRunAnalysis => modelsOnline > 0;

  /// Short label for the model availability card.
  String get modelStatusLabel {
    if (modelsTotal == 0) return 'No model registered';
    if (modelsOnline == 0) return 'Offline';
    return 'Online';
  }
}

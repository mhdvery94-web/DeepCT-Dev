import 'package:flutter/material.dart';
import '../models/assistant_sources.dart';
import '../theme/app_theme.dart';

/// Server snapshots stay visually separate from experimental generated text.
class AssistantEvidence extends StatelessWidget {
  final Map<String, dynamic> request;
  const AssistantEvidence({super.key, required this.request});
  Widget fact(EvidenceFact fact) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Text(
      '${fact.label}: ${fact.value}',
      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
    ),
  );
  Widget heading(String value) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 4),
    child: Text(
      value,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    ),
  );
  Widget note(String value) => Text(
    value,
    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
  );
  List<Widget> analysis(AiAnalysisSource source) {
    final report = source.evaluation;
    return [
      heading(
        'Prediksi #${source.id} · ${analysisStatusLabels[source.status]}',
      ),
      ...source.facts.map(fact),
      heading('Metrik prediksi'),
      ...report.measurement.facts.map(fact),
      ExpansionTile(
        title: const Text('Metode pengukuran', style: TextStyle(fontSize: 12)),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: report.method.isEmpty
            ? [note(evidenceUnavailable)]
            : report.method.map(fact).toList(),
      ),
      heading('Baseline linear'),
      note(
        report.baselineStatus == 'completed'
            ? 'Baseline selesai'
            : report.baselineStatus == 'baseline_failed'
            ? 'Pengukuran baseline gagal'
            : 'Baseline tidak tersedia',
      ),
      ...report.baseline.facts.map(fact),
      ...report.baselineMethod.map(fact),
      heading('Selisih terhadap baseline'),
      note(
        report.comparisonCompleted
            ? 'Presisi metrik tersimpan (recorded_precision). Nilai negatif berarti lebih buruk dari baseline.'
            : 'Perbandingan tidak tersedia.',
      ),
      ...report.comparisonFacts.map(fact),
      note('Metrik dan provenans model tidak menyatakan persetujuan ilmiah.'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final sources = parseAiSources(request['sources']);
    final metrics = evidenceMap(request['metrics']);
    return Container(
      margin: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        color: AppTheme.background,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: Colors.transparent,
        child: ExpansionTile(
          title: const Text(
            'Sumber dan metrik tepercaya',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          childrenPadding: const EdgeInsets.all(14),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            note(
              'Metadata ini dicatat saat jawaban dibuat, bukan status terkini. Gunakan sumber ini untuk memeriksa jawaban; asisten tidak membaca piksel TIFF.',
            ),
            if (!sources.any((s) => s is AiAnalysisSource))
              note('Tidak ada konteks prediksi.'),
            for (final source in sources)
              ...switch (source) {
                AiDocumentSource() => [
                  heading('Dokumen SOP · ${source.title}'),
                  note('${source.id} · ${source.version}'),
                  note(source.text),
                ],
                AiAnalysisSource() => analysis(source),
              },
            heading('Metrik generasi'),
            for (final entry in const {
              'prompt_eval_count': 'Token input',
              'eval_count': 'Token output',
              'total_duration': 'Durasi total',
              'load_duration': 'Durasi pemuatan',
              'prompt_eval_duration': 'Durasi input',
              'eval_duration': 'Durasi output',
            }.entries)
              fact(
                EvidenceFact(
                  entry.value,
                  providerMetric(entry.key, metrics[entry.key]),
                ),
              ),
            note('Durasi server dikonversi dari nanodetik ke detik.'),
          ],
        ),
      ),
    );
  }
}

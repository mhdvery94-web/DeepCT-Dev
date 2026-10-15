import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/ai_chat_controller.dart';
import '../theme/app_theme.dart';

/// Server snapshots stay visually separate from experimental generated text.
class AssistantEvidence extends StatelessWidget {
  final Map<String, dynamic> request;
  const AssistantEvidence({super.key, required this.request});
  String value(dynamic value) => value?.toString() ?? 'Tidak tersedia';
  Widget fact(String label, dynamic data) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Text(
      '$label: ${value(data)}',
      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final sources = AiChatController.rows(request['sources']);
    final metrics = AiChatController.map(request['metrics']);
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
            const Text(
              'Gunakan sumber ini untuk memeriksa jawaban; asisten tidak membaca piksel TIFF.',
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
            if (sources.isEmpty) fact('Konteks prediksi', 'Tidak ada'),
            for (final source in sources) ...[
              const SizedBox(height: 12),
              Text(
                'Prediksi #${source['id']} · ${source['status']}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              fact(
                'Model CT',
                source['model'] == null
                    ? null
                    : AiChatController.map(source['model'])['provenance'] ==
                          'historical_model_snapshot_unavailable'
                    ? 'Versi historis / provenans model tidak tersedia'
                    : '${AiChatController.map(source['model'])['name']} · ${AiChatController.map(source['model'])['version']}',
              ),
              fact('Berkas input', source['input_files_count']),
              fact('Berkas hasil', source['output_files_count']),
              fact(
                'Waktu analisis',
                source['processing_time_seconds'] == null
                    ? null
                    : '${source['processing_time_seconds']} detik',
              ),
              fact(
                'Kedaluwarsa / dihapus',
                '${source['expired'] == true ? 'Ya' : 'Tidak'} / ${source['files_deleted'] == true ? 'Ya' : 'Tidak'}',
              ),
              for (final key in [
                'mae',
                'psnr',
                'rmse',
                'pixels',
                'reference_min',
                'reference_max',
              ])
                fact(key, AiChatController.map(source['metrics'])[key]),
              ExpansionTile(
                title: const Text(
                  'Provenans validasi dan frame',
                  style: TextStyle(fontSize: 12),
                ),
                children: [
                  Text(
                    const JsonEncoder.withIndent('  ').convert({
                      'validation': source['validation_provenance'],
                      'frames': source['frame_provenance'],
                    }),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Metrik generasi',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            for (final entry in const {
              'prompt_eval_count': 'Token input',
              'eval_count': 'Token output',
              'total_duration': 'Durasi total',
              'load_duration': 'Durasi pemuatan',
              'prompt_eval_duration': 'Durasi input',
              'eval_duration': 'Durasi output',
            }.entries)
              fact(
                entry.value,
                metrics[entry.key] == null
                    ? null
                    : entry.key.endsWith('_duration')
                    ? '${((metrics[entry.key] as num) / 1000000000).toStringAsFixed(1)} detik'
                    : metrics[entry.key],
              ),
            const Text(
              'Durasi server dikonversi dari nanodetik ke detik.',
              style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/widgets/assistant_evidence.dart';
import 'package:fe/models/assistant_sources.dart';

Map<String, dynamic> report([Map<String, dynamic> changes = const {}]) => {
  'schema_version': 1,
  'evaluation_status': 'completed',
  'metrics': {'mae': 2, 'rmse': 3, 'psnr': 40, 'ssim': 0.934},
  'metric_status': {'psnr': 'available', 'ssim': 'available'},
  'method': {
    'sample_domain': 'raw_uint16',
    'data_range': 65535,
    'ssim': {
      'window_size': 7,
      'weighting': 'uniform',
      'boundary': 'valid',
      'covariance': 'sample',
      'k1': 0.01,
      'k2': 0.03,
    },
  },
  'reference': {
    'source': 'uploaded_midpoint',
    'index': 1,
    'from': [0, 2],
  },
  'model': {
    'name': 'CT Model',
    'version': 'v1',
    'provenance': 'managed_manifest_sha256',
    'sha256': 'a' * 64,
  },
  'baseline': {
    'status': 'completed',
    'metrics': {'mae': 1, 'rmse': 2, 'psnr': 45, 'ssim': 0.95},
    'metric_status': {'psnr': 'available', 'ssim': 'available'},
    'method': {'baseline': 'linear_midpoint', 'midpoint_rounding': 'half_up'},
  },
  'comparison': {
    'status': 'completed',
    'precision': 'recorded_precision',
    'mae_reduction': -1,
    'rmse_reduction': -1,
    'psnr_gain_db': -5,
    'ssim_gain': -0.016,
  },
  ...changes,
};
Map<String, dynamic> source([Map<String, dynamic>? evaluation]) => {
  'type': 'analysis_record',
  'id': 1,
  'status': 'completed',
  'metrics': {'mae': 2, 'ssim': 0.934},
  'evaluation': evaluation ?? report(),
};
Future<void> show(WidgetTester tester, dynamic sources) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AssistantEvidence(request: {'sources': sources}),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Sumber dan metrik tepercaya'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'completed evaluation preserves reference model baseline and signed regression',
    (tester) async {
      await show(tester, [source()]);
      for (final value in [
        'Evaluasi selesai',
        'Midpoint unggahan #1',
        '0 → 2',
        'CT Model',
        'v1',
        'managed_manifest_sha256',
        'a' * 64,
        'Baseline linear',
        'half_up',
        '-1',
        '-5',
        'recorded_precision',
        'Nilai negatif berarti lebih buruk',
      ]) {
        expect(find.textContaining(value), findsWidgets, reason: value);
      }
      await tester.ensureVisible(find.text('Metode pengukuran'));
      await tester.tap(find.text('Metode pengukuran'));
      await tester.pumpAndSettle();
      for (final value in [
        'raw_uint16',
        '65535',
        'Jendela SSIM',
        'uniform',
        'valid',
        'sample',
        '0.01',
        '0.03',
      ]) {
        expect(find.textContaining(value), findsWidgets, reason: value);
      }
    },
  );
  for (final state in {
    'no_reference': 'Tidak ada referensi unggahan',
    'evaluation_failed': 'Pengukuran gagal',
    'legacy_unknown': 'Evaluasi historis tidak diketahui',
  }.entries) {
    testWidgets('recorded evaluation state ${state.key}', (tester) async {
      await show(tester, [
        source(report({'evaluation_status': state.key})),
      ]);
      expect(find.textContaining(state.value), findsOneWidget);
    });
  }
  testWidgets(
    'historical snapshot and legacy metrics never imply current model',
    (tester) async {
      await show(tester, [
        {
          ...source(),
          'evaluation': null,
          'model': {'provenance': 'historical_model_snapshot_unavailable'},
          'metrics': {'ssim': 0},
        },
      ]);
      expect(
        find.textContaining('Versi historis / provenans model tidak tersedia'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Evaluasi historis tidak diketahui'),
        findsOneWidget,
      );
      expect(find.text('SSIM: 0'), findsOneWidget);
      expect(find.textContaining('null · null'), findsNothing);
    },
  );
  testWidgets(
    'explicit infinite PSNR and small SSIM remain distinct from absent values',
    (tester) async {
      await show(tester, [
        source(
          report({
            'metrics': {'psnr': null, 'ssim': null},
            'metric_status': {'psnr': 'infinite', 'ssim': 'image_too_small'},
          }),
        ),
      ]);
      expect(
        find.textContaining('Tak terhingga (galat tepat nol)'),
        findsOneWidget,
      );
      expect(find.textContaining('Citra terlalu kecil'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await show(tester, [
        source(
          report({
            'metrics': {'psnr': null, 'ssim': null},
            'metric_status': {},
          }),
        ),
      ]);
      expect(find.textContaining('Tak terhingga'), findsNothing);
      expect(find.text('PSNR (dB): Tidak tersedia'), findsWidgets);
    },
  );
  testWidgets(
    'document-only citations preserve SOP identity version and snippet',
    (tester) async {
      await show(tester, [
        {
          'type': 'document',
          'id': 'deepct-sop-metrics',
          'version': '2026-10-16.v1',
          'title': 'Arti metrik',
          'text': 'SSIM memakai jendela 7.',
        },
      ]);
      for (final text in [
        'Dokumen SOP',
        'deepct-sop-metrics',
        '2026-10-16.v1',
        'Arti metrik',
        'SSIM memakai jendela 7.',
        'Tidak ada konteks prediksi',
      ]) {
        expect(find.textContaining(text), findsWidgets);
      }
      expect(find.textContaining('Prediksi #'), findsNothing);
    },
  );
  testWidgets(
    'malformed fields unknown sources and arbitrary provenance never render',
    (tester) async {
      await show(tester, [
        null,
        4,
        {'type': 'unexpected', 'error': '/etc/private'},
        {
          ...source(
            report({
              'method': {'sample_domain': '/etc/private'},
              'model': {'name': '/etc/private'},
              'metrics': {'ssim': '<script>', 'psnr': double.infinity},
            }),
          ),
          'validation_provenance': {'error': '/etc/private'},
        },
        {'type': 'document', 'id': 5, 'title': {}, 'text': '/etc/private'},
      ]);
      for (final text in ['/etc', '<script>', 'Infinity', 'null · null']) {
        expect(find.textContaining(text), findsNothing);
      }
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'parser copies immutable evaluation and ignores malformed containers and unknown schemas',
    () {
      final raw = [source()];
      final parsed = parseAiSources(raw).single as AiAnalysisSource;
      raw.single['evaluation']['metrics']['mae'] = 50;
      expect(parsed.evaluation.measurement.metrics['mae'], 2);
      expect(
        () => parsed.evaluation.measurement.metrics['mae'] = 3,
        throwsUnsupportedError,
      );
      expect(parseAiSources({'sources': []}), isEmpty);
      expect(
        parseAiSources([
          null,
          5,
          {'type': 'other'},
          {'type': 'analysis_record', 'id': '1'},
          {
            'type': 'document',
            'id': 'deepct-sop-metrics',
            'version': {},
            'title': [],
            'text': '/etc/private',
          },
        ]),
        isEmpty,
      );
      final unknown =
          parseAiSources([
                source(
                  report({
                    'schema_version': '1',
                    'metrics': {'mae': 100},
                  }),
                ),
              ]).single
              as AiAnalysisSource;
      expect(unknown.evaluation.status, 'legacy_unknown');
      expect(unknown.evaluation.measurement.metrics['mae'], 2);
      expect(unknown.evaluation.method, isEmpty);
    },
  );
  test(
    'numeric and status parser admits zero and finite values without coercion',
    () {
      final parsed =
          parseAiSources([
                source(
                  report({
                    'metrics': {
                      'mae': null,
                      'ssim': '0.9',
                      'psnr': double.infinity,
                    },
                    'reference': {
                      'source': 'uploaded_midpoint',
                      'index': 1,
                      'from': ['0', 2],
                    },
                    'method': {'data_range': '65535'},
                    'model': {'version': '/etc/private'},
                  }),
                ),
              ]).single
              as AiAnalysisSource;
      expect(parsed.evaluation.measurement.metrics['mae'], isNull);
      expect(parsed.evaluation.measurement.metrics['ssim'], isNull);
      expect(parsed.evaluation.measurement.metrics['psnr'], isNull);
      expect(parsed.evaluation.reference, isNull);
      expect(parsed.evaluation.model, isEmpty);
      expect(parsed.evaluation.method, isEmpty);
      expect(providerMetric('eval_count', 0), '0');
      expect(providerMetric('total_duration', 50000000000), '50.0 detik');
      expect(
        providerMetric('total_duration', '50000000000'),
        evidenceUnavailable,
      );
      expect(providerMetric('eval_count', double.nan), evidenceUnavailable);
    },
  );
  test('unknown errors never expose paths JSON or parser exceptions', () {
    expect(assistantErrorMessage('Jaringan terputus'), 'Jaringan terputus');
    for (final value in [
      '/etc/private',
      '{"exception":"bad"}',
      'TypeError: invalid data',
      {},
      null,
    ]) {
      expect(
        assistantErrorMessage(value),
        'Permintaan tidak dapat diselesaikan. Coba lagi.',
      );
    }
    expect(requestFailureLabel('/etc/private'), 'Jawaban gagal dibuat');
    expect(
      requestFailureLabel('provider_timeout'),
      contains('provider_timeout'),
    );
  });
  final corpus =
      jsonDecode(File('../be/resources/ai/sop.json').readAsStringSync())
          as Map<String, dynamic>;
  final documents = corpus['documents'] as List;
  test('regression fixture covers all five actual controlled SOP entries', () {
    expect(documents, hasLength(5));
  });
  for (final entry in documents) {
    testWidgets(
      'actual SOP ${entry['id']} survives parsing and document-only rendering verbatim',
      (tester) async {
        final document = {
          'type': 'document',
          for (final key in ['id', 'version', 'title', 'text']) key: entry[key],
        };
        final parsed = parseAiSources([document]);
        expect(parsed, hasLength(1));
        final source = parsed.single as AiDocumentSource;
        expect(
          [source.id, source.version, source.title, source.text],
          [entry['id'], entry['version'], entry['title'], entry['text']],
        );
        await show(tester, [document]);
        for (final key in ['id', 'version', 'title', 'text']) {
          expect(
            find.textContaining(entry[key] as String),
            findsWidgets,
            reason: key,
          );
        }
        expect(
          find.textContaining('Tidak ada konteks prediksi'),
          findsOneWidget,
        );
        expect(find.textContaining('Prediksi #'), findsNothing);
      },
    );
  }
  test(
    'document prose rejects unsafe content while metadata retains strict slash restrictions',
    () {
      const document = {
        'type': 'document',
        'id': 'deepct-sop-lifecycle',
        'version': '2026-10-16.v1',
        'title': 'Tahapan analisis',
        'text': 'Pilih Mulai/Start setelah peninjauan.',
      };
      for (final value in [
        '/etc/private',
        '/secret',
        '../private',
        'storage/private.tiff',
        'storage/private/data',
        r'C:\private',
        '<script>bad</script>',
        'bad\u0000text',
        '{"error":"private"}',
        'TypeError: invalid data',
        'Stack trace: private',
      ]) {
        for (final field in ['title', 'text']) {
          expect(
            parseAiSources([
              {...document, field: value},
            ]),
            isEmpty,
            reason: '$field: $value',
          );
        }
      }
      for (final limits in [('title', 120), ('text', 900)]) {
        for (final value in ['', <String, dynamic>{}, 'x' * (limits.$2 + 1)]) {
          expect(
            parseAiSources([
              {...document, limits.$1: value},
            ]),
            isEmpty,
            reason: '${limits.$1} is bounded prose',
          );
        }
      }
      expect(
        parseAiSources([
          {...document, 'version': '2026/10'},
        ]),
        isEmpty,
      );
      final parsed =
          parseAiSources([
                source(
                  report({
                    'model': {'name': 'Model/Private'},
                    'method': {'sample_domain': 'raw/uint16'},
                  }),
                ),
              ]).single
              as AiAnalysisSource;
      expect(parsed.evaluation.model, isEmpty);
      expect(parsed.evaluation.method, isEmpty);
    },
  );
}

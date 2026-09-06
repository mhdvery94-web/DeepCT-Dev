import 'package:flutter_test/flutter_test.dart';

import 'package:fe/models/prediction.dart';

/// The payload a completed job returns for frames 001 and 005: the midpoint
/// 003 is drawn first from two scanned frames, then 002 and 004 are drawn
/// against 003 — which the model had just invented.
Map<String, dynamic> _completed({List<dynamic>? provenance}) => {
  'id': 7,
  'job_id': 'abc-def',
  'status': 'completed',
  'input_files_count': 2,
  'output_files_count': 3,
  'interpolated_frames': ['frame_002.tif', 'frame_003.tif', 'frame_004.tif'],
  'frame_provenance': ?provenance,
};

const _threeFrames = [
  {
    'frame': 'frame_002.tif',
    'index': 2,
    'from': [1, 3],
    'generation': 2,
    'synthetic_parents': 1,
  },
  {
    'frame': 'frame_003.tif',
    'index': 3,
    'from': [1, 5],
    'generation': 1,
    'synthetic_parents': 0,
  },
  {
    'frame': 'frame_004.tif',
    'index': 4,
    'from': [3, 5],
    'generation': 2,
    'synthetic_parents': 1,
  },
];

void main() {
  group('FrameProvenance', () {
    test('reads the parents and the generation', () {
      final p = Prediction.fromJson(_completed(provenance: _threeFrames));

      expect(p.frameProvenance, hasLength(3));

      final midpoint = p.frameProvenance.firstWhere((e) => e.index == 3);
      expect(midpoint.leftIndex, 1);
      expect(midpoint.rightIndex, 5);
      expect(midpoint.generation, 1);
      expect(midpoint.syntheticParents, 0);
      expect(midpoint.isFirstGeneration, isTrue);
    });

    test('marks a frame drawn against the model own output', () {
      // This is the distinction the whole field exists for: frame 002 sits
      // between a scanned frame and a generated one, so whatever error the
      // generated one carried is now an input.
      final p = Prediction.fromJson(_completed(provenance: _threeFrames));

      final second = p.frameProvenance.firstWhere((e) => e.index == 2);
      expect(second.generation, 2);
      expect(second.syntheticParents, 1);
      expect(second.isFirstGeneration, isFalse);
    });

    test('a job recorded before this existed reads as empty, not broken', () {
      // Every completed job before the column was added has no provenance at
      // all, and the gallery still has to render them.
      final p = Prediction.fromJson(_completed());

      expect(p.frameProvenance, isEmpty);
      expect(p.interpolatedFrames, hasLength(3));
    });

    test('a null value is tolerated the same way', () {
      final p = Prediction.fromJson(_completed(provenance: null));

      expect(p.frameProvenance, isEmpty);
    });

    test('a malformed entry does not take the whole payload down', () {
      // The list is data from a server that may be older or newer than this
      // build. A missing `from` should cost that one row its parents, not the
      // page its render.
      final p = Prediction.fromJson(
        _completed(
          provenance: [
            {'frame': 'frame_003.tif', 'index': 3},
          ],
        ),
      );

      expect(p.frameProvenance, hasLength(1));
      expect(p.frameProvenance.first.leftIndex, 0);
      expect(p.frameProvenance.first.generation, 1);
    });
  });

  group('HoldOutValidation', () {
    Map<String, dynamic> withValidation(Map<String, dynamic> validation) => {
      ..._completed(provenance: _threeFrames),
      'validation': validation,
    };

    test('reads the measurement and the frame it was taken on', () {
      final p = Prediction.fromJson(
        withValidation({
          'held_out_frame': 'frame_002.tif',
          'index': 2,
          'from': [1, 3],
          'mae': 41.5,
          'rmse': 58.2,
          'psnr': 61.03,
          'reference_min': 1200,
          'reference_max': 5200,
          'pixels': 1048576,
        }),
      );

      final v = p.validation!;
      expect(v.failed, isFalse);
      expect(v.heldOutFrame, 'frame_002.tif');
      expect(v.index, 2);
      expect(v.leftIndex, 1);
      expect(v.rightIndex, 3);
      expect(v.mae, 41.5);
      expect(v.psnr, 61.03);
    });

    test('expresses the error against the reference frame own range', () {
      // An MAE of 40 counts means nothing on its own: it is a large error on a
      // frame spanning 300 counts and a negligible one on a frame spanning
      // 60,000. Here the span is 4,000 and the error 40, so 1%.
      final p = Prediction.fromJson(
        withValidation({
          'mae': 40.0,
          'reference_min': 1000,
          'reference_max': 5000,
        }),
      );

      expect(p.validation!.maeAsFractionOfRange, closeTo(0.01, 0.0001));
    });

    test('a degenerate range yields no fraction rather than a divide by zero', () {
      final p = Prediction.fromJson(
        withValidation({
          'mae': 40.0,
          'reference_min': 500,
          'reference_max': 500,
        }),
      );

      expect(p.validation!.maeAsFractionOfRange, isNull);
    });

    test('identical frames report no PSNR rather than infinity', () {
      final p = Prediction.fromJson(
        withValidation({'mae': 0, 'psnr': null, 'rmse': 0}),
      );

      expect(p.validation!.psnr, isNull);
      expect(p.validation!.mae, 0);
    });

    test('a measurement that could not be taken says so', () {
      final p = Prediction.fromJson(
        withValidation({'error': 'Model rejected hold-out frame 2'}),
      );

      expect(p.validation!.failed, isTrue);
      expect(p.validation!.error, contains('hold-out'));
      expect(p.validation!.mae, isNull);
    });

    test('no triplet in the archive means no validation, and that is fine', () {
      // The common case: an upload of frames 1 and 5 offers nothing to hold
      // out. Absence must never read as failure.
      final p = Prediction.fromJson(_completed(provenance: _threeFrames));

      expect(p.validation, isNull);
    });
  });
}

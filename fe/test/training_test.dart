import 'package:flutter_test/flutter_test.dart';

import 'package:fe/models/training.dart';

void main() {
  group('TrainingJob', () {
    test('reads a running job', () {
      final job = TrainingJob.fromJson(const {
        'id': 3,
        'name': 'Retrain on balanced t',
        'status': 'running',
        'current_epoch': 40,
        'total_epochs': 200,
        'progress': 0.2,
        'metrics': {'loss': 0.031, 'psnr': 34.2},
        'worker_label': 'kaggle-t4-1',
        'dataset': {'id': 1, 'name': 'Balanced-t frames'},
        'has_checkpoint': true,
      });

      expect(job.isActive, isTrue);
      expect(job.isFinished, isFalse);
      expect(job.epochLabel, 'epoch 40 / 200');
      expect(job.progress, 0.2);
      expect(job.workerLabel, 'kaggle-t4-1');
      expect(job.datasetName, 'Balanced-t frames');
    });

    test('a job whose worker went quiet reads as stalled', () {
      // Not an error: a Kaggle session ending is the normal course of events,
      // and the platform hands the job back with its checkpoint.
      final job = TrainingJob.fromJson({
        'id': 3,
        'status': 'running',
        'heartbeat_at': DateTime.now()
            .subtract(const Duration(minutes: 9))
            .toIso8601String(),
      });

      expect(job.looksStalled, isTrue);
    });

    test('a job beating normally does not look stalled', () {
      final job = TrainingJob.fromJson({
        'id': 3,
        'status': 'running',
        'heartbeat_at': DateTime.now()
            .subtract(const Duration(seconds: 30))
            .toIso8601String(),
      });

      expect(job.looksStalled, isFalse);
    });

    test('a queued job is never stalled — nobody is holding it', () {
      final job = TrainingJob.fromJson(const {'id': 3, 'status': 'queued'});

      expect(job.looksStalled, isFalse);
      expect(job.isQueued, isTrue);
    });

    test('finished statuses are recognised', () {
      for (final status in ['completed', 'failed', 'cancelled']) {
        final job = TrainingJob.fromJson({'id': 1, 'status': status});
        expect(job.isFinished, isTrue, reason: status);
        expect(job.isActive, isFalse, reason: status);
      }
    });

    test('survives a payload with missing keys', () {
      final job = TrainingJob.fromJson(const {});

      expect(job.status, 'queued');
      expect(job.metrics, isEmpty);
      expect(job.progress, isNull);
      expect(job.epochLabel, 'epoch 0');
    });
  });

  group('TrainingDataset', () {
    test('reads a hosted dataset and formats its size', () {
      final dataset = TrainingDataset.fromJson(const {
        'id': 1,
        'name': 'Small set',
        'source_type': 'upload',
        'size_bytes': 5 * 1024 * 1024,
        'jobs_count': 2,
      });

      expect(dataset.isHosted, isTrue);
      expect(dataset.sizeLabel, '5.0 MB');
      expect(dataset.jobsCount, 2);
    });

    test('reads a dataset the worker fetches itself', () {
      final dataset = TrainingDataset.fromJson(const {
        'id': 2,
        'name': 'Big set',
        'source_type': 'url',
        'source_url': 'https://example.org/frames.zip',
      });

      expect(dataset.isHosted, isFalse);
      expect(dataset.sourceUrl, 'https://example.org/frames.zip');
      // No size to report, and saying "0 B" would be a lie.
      expect(dataset.sizeLabel, '—');
    });

    test('formats gigabytes', () {
      final dataset = TrainingDataset.fromJson(const {
        'id': 3,
        'source_type': 'upload',
        'size_bytes': 3 * 1024 * 1024 * 1024,
      });

      expect(dataset.sizeLabel, '3.00 GB');
    });
  });
}

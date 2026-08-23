import 'package:flutter_test/flutter_test.dart';

import 'package:fe/models/training.dart';

void main() {
  test('the four asked-for metrics lead, in a fixed order', () {
    // A dynamic column order would shuffle between runs depending on which
    // keys a notebook happened to report first.
    final keys = orderedMetricKeys(const {
      'ssim': 0.9,
      'batches': 120,
      'psnr': 31.4,
      'mse': 0.001,
      'mae': 0.01,
    });

    expect(keys.take(4).toList(), ['mae', 'mse', 'psnr', 'ssim']);
  });

  test('bookkeeping is not a metric', () {
    // batches and samples say how much work was done, not how well. They
    // belong in the payload and not in a column beside PSNR.
    expect(orderedMetricKeys(const {'psnr': 31.4, 'batches': 120, 'samples': 900}),
        ['psnr']);
  });

  test('loss is hidden when mae is present, because they are one number', () {
    // The trainer's loss is tf.reduce_mean(tf.abs(...)) — MAE by definition.
    // Two columns of the same number is noise.
    expect(orderedMetricKeys(const {'mae': 0.01, 'loss': 0.01}), ['mae']);
  });

  test('loss survives alone, so older runs keep their column', () {
    // Runs recorded before the rename sent it only under `loss`, and dropping
    // it would empty their table.
    expect(orderedMetricKeys(const {'loss': 0.0123, 'psnr': 30.0}),
        ['loss', 'psnr']);
  });

  test('a metric the notebook invented still gets a column', () {
    // The table was built to survive a notebook measuring something new
    // without a code change here, and that stays true.
    expect(orderedMetricKeys(const {'psnr': 31.4, 'lpips': 0.08}),
        ['psnr', 'lpips']);
  });

  test('a non-numeric value is not a column', () {
    expect(orderedMetricKeys(const {'balanced_t': true, 'psnr': 31.4}),
        ['psnr']);
  });
}

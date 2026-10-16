<?php

namespace Tests\Unit;

use App\Services\FrameMetrics;
use App\Services\TiffPreview;
use PHPUnit\Framework\TestCase;
use RuntimeException;

/**
 * The arithmetic behind every quality figure this platform will ever report.
 *
 * Worth testing against numbers worked out by hand rather than against
 * whatever the code happens to produce: a wrong constant or a squared term in
 * the wrong place would not crash anything, it would quietly put wrong figures
 * into a thesis.
 */
class FrameMetricsTest extends TestCase
{
    private FrameMetrics $metrics;

    protected function setUp(): void
    {
        parent::setUp();
        $this->metrics = new FrameMetrics(new TiffPreview);
    }

    /**
     * A minimal but structurally valid 16-bit grayscale TIFF holding exactly
     * the pixels given, row-major.
     *
     * @param  array<int>  $pixels
     */
    private function tif(array $pixels, int $width, int $height): string
    {
        $data = '';
        foreach ($pixels as $value) {
            $data .= pack('v', $value);
        }

        $pixelOffset = 8;
        $ifdOffset = $pixelOffset + strlen($data);

        $tif = 'II'.pack('v', 42).pack('V', $ifdOffset).$data;

        $ifd = pack('v', 8);
        $ifd .= pack('vvVV', 256, 3, 1, $width);
        $ifd .= pack('vvVV', 257, 3, 1, $height);
        $ifd .= pack('vvVV', 258, 3, 1, 16);
        $ifd .= pack('vvVV', 259, 3, 1, 1);
        $ifd .= pack('vvVV', 262, 3, 1, 1);
        $ifd .= pack('vvVV', 273, 4, 1, $pixelOffset);
        $ifd .= pack('vvVV', 277, 3, 1, 1);
        $ifd .= pack('vvVV', 279, 4, 1, strlen($data));
        $ifd .= pack('V', 0);

        return $tif.$ifd;
    }

    public function test_mae_is_the_mean_absolute_difference(): void
    {
        // Differences of -10, +10, 0, 0. Absolute sum 20 over 4 pixels: 5.
        $reference = $this->tif([100, 200, 300, 400], 2, 2);
        $candidate = $this->tif([110, 190, 300, 400], 2, 2);

        $result = $this->metrics->compare($reference, $candidate);

        $this->assertEqualsWithDelta(5.0, $result['mae'], 0.001);
        $this->assertSame(4, $result['pixels']);
    }

    public function test_psnr_is_measured_against_the_full_16_bit_range(): void
    {
        // MSE = (100 + 100 + 0 + 0) / 4 = 50, so RMSE = sqrt(50) = 7.0711.
        // PSNR = 20 * log10(65535 / 7.0711) = 79.34 dB.
        $reference = $this->tif([100, 200, 300, 400], 2, 2);
        $candidate = $this->tif([110, 190, 300, 400], 2, 2);

        $result = $this->metrics->compare($reference, $candidate);

        $this->assertEqualsWithDelta(7.0711, $result['rmse'], 0.001);
        $this->assertEqualsWithDelta(79.34, $result['psnr'], 0.05);
        $this->assertSame(65535, FrameMetrics::MAX_VALUE);
    }

    public function test_identical_frames_report_no_error_rather_than_infinity(): void
    {
        // log10(0) is negative infinity, and an infinity cannot be written to
        // JSON. Null says "nothing to measure" and survives the round trip.
        $frame = $this->tif([100, 200, 300, 400], 2, 2);

        $result = $this->metrics->compare($frame, $frame);

        $this->assertSame(0.0, $result['mae']);
        $this->assertNull($result['psnr']);
    }

    public function test_the_reference_range_is_reported_alongside(): void
    {
        // Without it, an MAE of 40 counts is uninterpretable: it is a large
        // error on a frame spanning 300 counts and a negligible one on a frame
        // spanning 60,000.
        $reference = $this->tif([1000, 2000, 3000, 4000], 2, 2);
        $candidate = $this->tif([1000, 2000, 3000, 4000], 2, 2);

        $result = $this->metrics->compare($reference, $candidate);

        $this->assertSame(1000, $result['reference_min']);
        $this->assertSame(4000, $result['reference_max']);
    }

    public function test_frames_of_different_sizes_are_refused(): void
    {
        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessageMatches('/differ in size/');

        $this->metrics->compare(
            $this->tif([1, 2, 3, 4], 2, 2),
            $this->tif([1, 2], 2, 1)
        );
    }

    public function test_ssim_matches_independent_skimage_fixtures(): void
    {
        $fixtures = json_decode(file_get_contents(__DIR__.'/fixtures/ssim-skimage.json'), true);
        foreach ($fixtures['cases'] as $case) {
            $a = $b = [];
            for ($y = 0; $y < $case['height']; $y++) {
                for ($x = 0; $x < $case['width']; $x++) {
                    $value = ($x * 1237 + $y * 1973 + $x * $y * 83) % 65536;
                    $a[] = $value;
                    $b[] = $case['kind'] === 'inverted' ? 65535 - $value
                        : max(0, min(65535, $value + (($x + 2 * $y) % 5 - 2) * 311));
                }
            }
            $result = $this->metrics->compare($this->tif($a, $case['width'], $case['height']), $this->tif($b, $case['width'], $case['height']));
            $this->assertSame('available', $result['ssim_status']);
            $this->assertEqualsWithDelta($case['ssim'], $result['ssim'], 1e-9);
            $this->assertSame(7, $result['method']['ssim']['window_size']);
            $this->assertSame('sample', $result['method']['ssim']['covariance']);
            $this->assertSame('valid', $result['method']['ssim']['boundary']);
        }
    }

    public function test_identical_and_small_image_statuses_are_explicit(): void
    {
        $frame = $this->tif(array_fill(0, 49, 12345), 7, 7);
        $result = $this->metrics->compare($frame, $frame);
        $this->assertSame(1.0, $result['ssim']);
        $this->assertSame('infinite', $result['psnr_status']);
        $small = $this->tif([1, 2, 3, 4], 2, 2);
        $result = $this->metrics->compare($small, $small);
        $this->assertNull($result['ssim']);
        $this->assertSame('image_too_small', $result['ssim_status']);
    }

    public function test_tiny_error_is_not_reported_as_identical_when_mae_rounds_to_zero(): void
    {
        $a = array_fill(0, 4096, 10);
        $b = $a;
        $b[0] = 11;
        $result = $this->metrics->compare($this->tif($a, 64, 64), $this->tif($b, 64, 64));
        $this->assertSame(0.0, $result['mae']);
        $this->assertSame('available', $result['psnr_status']);
        $this->assertIsFloat($result['psnr']);
    }

    public function test_midpoint_rounds_half_up_in_raw_uint16_counts(): void
    {
        $result = $this->metrics->compareMidpoint($this->tif([1, 2, 65535, 32768], 2, 2),
            $this->tif([0, 1, 65535, 0], 2, 2), $this->tif([1, 2, 65535, 65535], 2, 2));
        $this->assertSame(0.0, $result['mae']);
        $this->assertSame('half_up', $result['method']['midpoint_rounding']);
    }

    public function test_midpoint_requires_matching_dimensions(): void
    {
        $this->expectException(RuntimeException::class);
        $this->metrics->compareMidpoint($this->tif([1, 2], 2, 1), $this->tif([1, 2], 2, 1), $this->tif([1], 1, 1));
    }
    public function test_wide_frames_are_rejected_without_exhausting_worker_memory(): void
    {
        $process = new \Symfony\Component\Process\Process([
            PHP_BINARY, '-d', 'memory_limit=512M', __DIR__.'/fixtures/wide-frame.php',
        ]);
        $process->setTimeout(30);
        $process->run();
        $this->assertSame(0, $process->getExitCode(), $process->getOutput().$process->getErrorOutput());
        $result = json_decode($process->getOutput(), true, 512, JSON_THROW_ON_ERROR);
        $this->assertSame(['compare', 'compareMidpoint'], $result['rejected']);
        $this->assertLessThan(128 * 1024 * 1024, $result['peak_bytes']);
    }

}

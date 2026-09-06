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
        $this->metrics = new FrameMetrics(new TiffPreview());
    }

    /**
     * A minimal but structurally valid 16-bit grayscale TIFF holding exactly
     * the pixels given, row-major.
     *
     * @param array<int> $pixels
     */
    private function tif(array $pixels, int $width, int $height): string
    {
        $data = '';
        foreach ($pixels as $value) {
            $data .= pack('v', $value);
        }

        $pixelOffset = 8;
        $ifdOffset = $pixelOffset + strlen($data);

        $tif = 'II' . pack('v', 42) . pack('V', $ifdOffset) . $data;

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

        return $tif . $ifd;
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
}

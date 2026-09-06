<?php

namespace Tests\Unit;

use App\Services\TiffPreview;
use PHPUnit\Framework\TestCase;
use RuntimeException;

/**
 * The TIFF decoder and PNG encoder, both written by hand because this machine
 * has neither GD nor Imagick.
 *
 * Raw byte handling is where silent corruption hides, so these assert on the
 * actual PNG structure rather than "it returned something".
 */
class TiffPreviewTest extends TestCase
{
    private TiffPreview $preview;

    protected function setUp(): void
    {
        parent::setUp();
        $this->preview = new TiffPreview();
    }

    /**
     * Build an uncompressed single-strip grayscale TIFF.
     *
     * @param  array<int>  $pixels  row-major, length must be $w * $h
     */
    private function tiff(
        int $w,
        int $h,
        array $pixels,
        int $bits = 16,
        int $compression = 1,
        int $samples = 1,
        int $photometric = 1,
        bool $little = true
    ): string {
        $packed = '';
        foreach ($pixels as $p) {
            $packed .= $bits === 16
                ? pack($little ? 'v' : 'n', $p)
                : pack('C', $p);
        }

        $s = fn(int $v) => pack($little ? 'v' : 'n', $v);
        $l = fn(int $v) => pack($little ? 'V' : 'N', $v);

        $pixelOffset = 8;
        $ifdOffset = $pixelOffset + strlen($packed);

        $header = ($little ? 'II' : 'MM') . $s(42) . $l($ifdOffset);

        $entry = fn(int $tag, int $type, int $count, int $value) =>
            $s($tag) . $s($type) . $l($count) .
            ($type === 3 ? $s($value) . $s(0) : $l($value));

        $ifd = $s(8)
            . $entry(256, 3, 1, $w)
            . $entry(257, 3, 1, $h)
            . $entry(258, 3, 1, $bits)
            . $entry(259, 3, 1, $compression)
            . $entry(262, 3, 1, $photometric)
            . $entry(273, 4, 1, $pixelOffset)
            . $entry(277, 3, 1, $samples)
            . $entry(279, 4, 1, strlen($packed))
            . $l(0);

        return $header . $packed . $ifd;
    }

    /** @return array{width:int,height:int,bitDepth:int,colorType:int} */
    private function readPngHeader(string $png): array
    {
        $this->assertSame("\x89PNG\r\n\x1a\n", substr($png, 0, 8), 'PNG signature');
        $this->assertSame('IHDR', substr($png, 12, 4), 'IHDR must come first');

        $ihdr = unpack('Nwidth/Nheight/CbitDepth/CcolorType', substr($png, 16, 10));

        return $ihdr;
    }

    // ---------------------------------------------------------------- tests

    public function test_it_renders_a_16_bit_frame_as_a_greyscale_png(): void
    {
        $pixels = [];
        for ($i = 0; $i < 64; $i++) {
            $pixels[] = $i * 1000;
        }

        $png = $this->preview->toPng($this->tiff(8, 8, $pixels), 512);

        $header = $this->readPngHeader($png);

        $this->assertSame(8, $header['width']);
        $this->assertSame(8, $header['height']);
        $this->assertSame(8, $header['bitDepth'], 'output is 8-bit');
        $this->assertSame(0, $header['colorType'], 'output is greyscale');
        $this->assertStringEndsWith('IEND' . pack('N', crc32('IEND')), $png);
    }

    public function test_it_reads_8_bit_frames_too(): void
    {
        $pixels = range(0, 15);

        $png = $this->preview->toPng($this->tiff(4, 4, $pixels, bits: 8), 512);

        $header = $this->readPngHeader($png);
        $this->assertSame(4, $header['width']);
        $this->assertSame(4, $header['height']);
    }

    public function test_it_reads_big_endian_frames(): void
    {
        $pixels = range(0, 15);

        $png = $this->preview->toPng(
            $this->tiff(4, 4, $pixels, little: false),
            512
        );

        $this->assertSame(4, $this->readPngHeader($png)['width']);
    }

    /**
     * The reason the conversion windows to min/max instead of shifting: a CT
     * frame occupying a narrow band of the 16-bit range must still be visible.
     */
    public function test_a_narrow_value_range_is_stretched_to_full_contrast(): void
    {
        // All values sit between 1000 and 1007 — a naive >>8 renders these as
        // four identical near-black pixels.
        $pixels = [1000, 1002, 1005, 1007];

        $png = $this->preview->toPng($this->tiff(2, 2, $pixels), 512);

        $this->assertSame(2, $this->readPngHeader($png)['width']);

        // The darkest pixel must map to 0 and the brightest to 255.
        $raw = gzuncompress($this->idat($png));
        $this->assertNotFalse($raw);

        // Two scanlines, each: filter byte + 2 pixels.
        $this->assertSame(6, strlen($raw));
        $this->assertSame(0, ord($raw[1]), 'minimum maps to black');
        $this->assertSame(255, ord($raw[5]), 'maximum maps to white');
    }

    public function test_a_flat_frame_does_not_divide_by_zero(): void
    {
        $png = $this->preview->toPng($this->tiff(2, 2, [500, 500, 500, 500]), 512);

        $raw = gzuncompress($this->idat($png));
        $this->assertSame(128, ord($raw[1]), 'a flat frame renders mid-grey');
    }

    public function test_it_downscales_and_preserves_the_aspect_ratio(): void
    {
        $pixels = array_fill(0, 64 * 32, 1234);

        $png = $this->preview->toPng($this->tiff(64, 32, $pixels), 16);

        $header = $this->readPngHeader($png);
        $this->assertSame(16, $header['width']);
        $this->assertSame(8, $header['height'], 'aspect ratio kept');
    }

    public function test_a_small_frame_is_not_upscaled(): void
    {
        $png = $this->preview->toPng($this->tiff(4, 4, range(0, 15)), 512);

        $this->assertSame(4, $this->readPngHeader($png)['width']);
    }

    public function test_white_is_zero_frames_are_inverted(): void
    {
        // photometric 0 means 0 is white; without inversion the preview would
        // come out as a negative.
        $png = $this->preview->toPng(
            $this->tiff(2, 1, [0, 65535], photometric: 0),
            512
        );

        $raw = gzuncompress($this->idat($png));
        $this->assertSame(255, ord($raw[1]), 'zero renders white');
        $this->assertSame(0, ord($raw[2]), 'max renders black');
    }

    // --- rejections -------------------------------------------------------

    public function test_it_refuses_a_compressed_frame(): void
    {
        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessageMatches('/uncompressed/i');

        $this->preview->toPng($this->tiff(2, 2, [1, 2, 3, 4], compression: 5));
    }

    public function test_it_refuses_a_multi_channel_frame(): void
    {
        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessageMatches('/grayscale/i');

        $this->preview->toPng($this->tiff(2, 2, [1, 2, 3, 4], samples: 3));
    }

    public function test_it_refuses_something_that_is_not_a_tiff(): void
    {
        $this->expectException(RuntimeException::class);

        $this->preview->toPng('this is definitely not a tiff file at all');
    }

    public function test_it_refuses_truncated_pixel_data(): void
    {
        $tiff = $this->tiff(8, 8, array_fill(0, 64, 100));

        // Chop the pixel block in half but leave the header claiming 8x8.
        $truncated = substr($tiff, 0, 8) . substr($tiff, 8, 40) . substr($tiff, 8 + 128);

        $this->expectException(RuntimeException::class);
        $this->preview->toPng($truncated);
    }

    /** Extract the IDAT payload so tests can inspect the pixels. */
    private function idat(string $png): string
    {
        $at = 8;

        while ($at < strlen($png)) {
            $length = unpack('N', substr($png, $at, 4))[1];
            $type = substr($png, $at + 4, 4);

            if ($type === 'IDAT') {
                return substr($png, $at + 8, $length);
            }

            $at += 12 + $length;
        }

        $this->fail('no IDAT chunk in the PNG');
    }

    // -------------------------------------------------------------- memory

    /**
     * A frame of $w x $h whose pixel data is built without a PHP array.
     *
     * The `tiff()` helper above takes an array of pixels, which for four
     * million of them would cost more memory than the thing under test — the
     * fixture would fail before the decoder got a chance to. One row is
     * packed and repeated instead: a horizontal gradient, constant down the
     * frame, which is enough to exercise windowing and box-averaging both.
     */
    private function largeTiff(int $w, int $h): string
    {
        $row = '';
        for ($x = 0; $x < $w; $x++) {
            $row .= pack('v', (int) ($x * 65535 / max(1, $w - 1)));
        }
        $packed = str_repeat($row, $h);

        $s = fn(int $v) => pack('v', $v);
        $l = fn(int $v) => pack('V', $v);

        $pixelOffset = 8;
        $ifdOffset = $pixelOffset + strlen($packed);

        $entry = fn(int $tag, int $type, int $count, int $value) =>
            $s($tag) . $s($type) . $l($count) .
            ($type === 3 ? $s($value) . $s(0) : $l($value));

        return 'II' . $s(42) . $l($ifdOffset)
            . $packed
            . $s(8)
            . $entry(256, 3, 1, $w)
            . $entry(257, 3, 1, $h)
            . $entry(258, 3, 1, 16)
            . $entry(259, 3, 1, 1)
            . $entry(262, 3, 1, 1)
            . $entry(273, 4, 1, $pixelOffset)
            . $entry(277, 3, 1, 1)
            . $entry(279, 4, 1, strlen($packed))
            . $l(0);
    }

    /**
     * The reason `MAX_PIXELS` was cut to 2048x2048 in the first place.
     *
     * Every pixel became an entry in a PHP array — twice over, while
     * `unpack`'s result was copied into the accumulator — and an array entry
     * costs an order of magnitude more than the two bytes the pixel occupies
     * on disk. On 25 August that overran the queue worker's `memory_limit`
     * mid-job: the process died, took the run with it, and left "queued" on
     * screen with nothing to explain it. Lowering the ceiling moved the wall;
     * it did not remove it.
     *
     * Four million pixels is 8 MB of TIFF. Decoding it should cost the same
     * order as the file itself, not ten times it. The budget below is
     * deliberately loose — the difference being measured is roughly 85 MB
     * against roughly 10 MB, so a threshold anywhere between them tells the
     * two implementations apart without being a benchmark.
     */
    public function test_a_full_size_frame_does_not_cost_a_php_array_per_pixel(): void
    {
        $tiff = $this->largeTiff(2048, 2048);

        memory_reset_peak_usage();
        $before = memory_get_usage();

        $png = $this->preview->toPng($tiff, 512);

        $used = memory_get_peak_usage() - $before;

        $header = $this->readPngHeader($png);
        $this->assertSame(512, $header['width']);
        $this->assertSame(512, $header['height']);

        $this->assertLessThan(
            32 * 1024 * 1024,
            $used,
            sprintf('decoding 2048x2048 used %.1f MB', $used / 1048576),
        );
    }

    /**
     * The same for [decode()], which `FrameMetrics` calls twice in a row to
     * compare a held-out frame against the model's answer for it. Two frames
     * alive at once is the worst case on this path, and it is the one that
     * runs inside the queue worker.
     */
    public function test_two_frames_can_be_compared_without_two_pixel_arrays(): void
    {
        $tiff = $this->largeTiff(2048, 2048);

        memory_reset_peak_usage();
        $before = memory_get_usage();

        $a = $this->preview->decode($tiff);
        $b = $this->preview->decode($tiff);

        $used = memory_get_peak_usage() - $before;

        $this->assertSame(2048, $a['width']);
        $this->assertSame(2048, $b['height']);

        $this->assertLessThan(
            48 * 1024 * 1024,
            $used,
            sprintf('decoding two 2048x2048 frames used %.1f MB', $used / 1048576),
        );
    }

    /**
     * A TIFF that *claims* a size but carries almost no pixels.
     *
     * The size guard runs before the pixel data is read, so this pins where
     * the ceiling sits without allocating a frame to prove it — a real
     * 4096x4096 fixture is 32 MB and two and a half seconds.
     */
    private function tiffDeclaring(int $w, int $h): string
    {
        $packed = str_repeat("\0", 8);

        $s = fn(int $v) => pack('v', $v);
        $l = fn(int $v) => pack('V', $v);
        $entry = fn(int $tag, int $type, int $count, int $value) =>
            $s($tag) . $s($type) . $l($count) .
            ($type === 3 ? $s($value) . $s(0) : $l($value));

        return 'II' . $s(42) . $l(8 + strlen($packed))
            . $packed
            . $s(8)
            . $entry(256, 4, 1, $w)
            . $entry(257, 4, 1, $h)
            . $entry(258, 3, 1, 16)
            . $entry(259, 3, 1, 1)
            . $entry(262, 3, 1, 1)
            . $entry(273, 4, 1, 8)
            . $entry(277, 3, 1, 1)
            . $entry(279, 4, 1, strlen($packed))
            . $l(0);
    }

    /**
     * Where the ceiling sits, from both sides.
     *
     * It was cut to 2048x2048 because the decoder could not survive more, and
     * goes back to 4096x4096 now that a frame costs its own size rather than
     * a multiple of it. Asserting only the refusal would let the limit drift
     * downwards unnoticed; asserting only the acceptance would let it drift
     * up. The accepted frame fails on its missing pixels, which is the proof
     * it got past the size guard.
     */
    public function test_the_ceiling_admits_4096_and_refuses_more(): void
    {
        try {
            $this->preview->toPng($this->tiffDeclaring(4096, 4096));
            $this->fail('a frame with no pixel data should not decode');
        } catch (RuntimeException $e) {
            $this->assertStringContainsString('truncated', $e->getMessage());
        }

        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('Frame is too large to preview.');

        $this->preview->toPng($this->tiffDeclaring(4096, 4097));
    }
}

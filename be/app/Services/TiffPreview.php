<?php

namespace App\Services;

use RuntimeException;

/**
 * Turns a 16-bit grayscale TIFF frame into a PNG the browser can show.
 *
 * Neither a browser nor Flutter can render TIFF, and this machine has neither
 * the GD nor the Imagick extension, so both halves are done here in plain PHP.
 * That is only reasonable because the input is narrow and predictable: the
 * worker returns uncompressed single-channel frames, and so do the uploads it
 * is given. Anything outside that is refused rather than guessed at.
 *
 * The 16 -> 8 bit conversion windows to the frame's own min/max rather than
 * simply dropping the low byte. CT frames rarely span the full 16-bit range,
 * and a naive shift renders most of them as an almost-black square.
 */
class TiffPreview
{
    /**
     * Refuse dimensions this decoder cannot actually handle.
     *
     * This was 8192x8192 while every pixel became an entry in a PHP array —
     * twice over, while `unpack`'s result was copied into the accumulator —
     * so the guard permitted what the implementation could not survive. The
     * failure was not a refusal but a fatal `memory_limit` error inside the
     * queue worker on 25 August: the process died mid-job, took the run with
     * it, and left "queued" on screen with nothing to explain it. The ceiling
     * was cut to 2048x2048 to stop that, which moved the wall rather than
     * removing it.
     *
     * Pixels now stay in a binary string and are unpacked a block at a time,
     * so the cost is the frame's own size rather than a multiple of it.
     * Measured on this machine, PHP 8.2:
     *
     * | Frame       | TIFF   | `toPng` | two frames | `toPng` time |
     * |-------------|--------|---------|------------|--------------|
     * | 1024x1024   | 2 MB   | 5.7 MB  | 8 MB       | 0.30 s       |
     * | 2048x2048   | 8 MB   | 11.7 MB | 20 MB      | 0.69 s       |
     * | 4096x4096   | 32 MB  | 36.6 MB | 68 MB      | 2.36 s       |
     * | 8192x8192   | 128 MB | 142.8 MB| 260 MB     | 10.24 s      |
     *
     * 2048x2048 cost 196 MB before this, and two of them 262 MB — inside a
     * worker budgeted at 512 MB at the time.
     *
     * So the ceiling goes back up, but to 4096x4096 rather than all the way.
     * **Memory is no longer what decides it; time is.** A preview endpoint
     * that answers in 2.4 seconds is slow and defensible; one that takes ten
     * is neither, and 260 MB for the two-frame comparison would still be most
     * of a queue worker's budget with a job's other work beside it.
     *
     * Only the *preview* is refused past this. The frame itself still
     * downloads untouched.
     */
    private const MAX_PIXELS = 4096 * 4096;

    /**
     * @param  string  $tiff     raw TIFF bytes
     * @param  int     $maxSide  longest edge of the output, preserving aspect
     * @return string PNG bytes
     *
     * @throws RuntimeException when the frame is not a form we can read
     */
    public function toPng(string $tiff, int $maxSide = 512): string
    {
        $image = $this->decode($tiff);

        // Downscaled first, so the window is measured on what will actually be
        // drawn rather than on pixels about to be averaged away.
        [$samples, $width, $height] = $this->downscale($image, $maxSide);

        [$min, $max] = $this->range($samples);

        return $this->encodePng(
            $this->windowTo8Bit($samples, $min, $max),
            $width,
            $height,
        );
    }

    // ----------------------------------------------------------------- TIFF

    /**
     * Public because `FrameMetrics` needs the same pixels to compare two
     * frames against each other, and a second TIFF reader in the codebase
     * would be a second place for the same bugs to live.
     *
     * @return array{pixels: array<int>, width: int, height: int, maxValue: int}
     */
    public function decode(string $tiff): array
    {
        if (strlen($tiff) < 8) {
            throw new RuntimeException('Not a TIFF: file is too short.');
        }

        $byteOrder = substr($tiff, 0, 2);

        $little = match ($byteOrder) {
            'II' => true,
            'MM' => false,
            default => throw new RuntimeException('Not a TIFF: bad byte-order mark.'),
        };

        if ($this->u16($tiff, 2, $little) !== 42) {
            throw new RuntimeException('Not a TIFF: bad magic number.');
        }

        $ifdOffset = $this->u32($tiff, 4, $little);
        $entryCount = $this->u16($tiff, $ifdOffset, $little);

        $tags = [];
        for ($i = 0; $i < $entryCount; $i++) {
            $entry = $ifdOffset + 2 + ($i * 12);

            $tag = $this->u16($tiff, $entry, $little);
            $type = $this->u16($tiff, $entry + 2, $little);
            $count = $this->u32($tiff, $entry + 4, $little);

            // Values of 4 bytes or fewer are stored inline in the entry.
            $value = match ($type) {
                3 => $count === 1
                    ? $this->u16($tiff, $entry + 8, $little)
                    : $this->u16($tiff, $this->u32($tiff, $entry + 8, $little), $little),
                4 => $count === 1
                    ? $this->u32($tiff, $entry + 8, $little)
                    : $this->u32($tiff, $this->u32($tiff, $entry + 8, $little), $little),
                default => $this->u32($tiff, $entry + 8, $little),
            };

            $tags[$tag] = ['value' => $value, 'type' => $type, 'count' => $count, 'entry' => $entry];
        }

        $width = $tags[256]['value'] ?? null;
        $height = $tags[257]['value'] ?? null;
        $bits = $tags[258]['value'] ?? 8;
        $compression = $tags[259]['value'] ?? 1;
        $samples = $tags[277]['value'] ?? 1;
        $photometric = $tags[262]['value'] ?? 1;

        if ($width === null || $height === null) {
            throw new RuntimeException('TIFF is missing its dimensions.');
        }

        if ($width * $height > self::MAX_PIXELS) {
            throw new RuntimeException('Frame is too large to preview.');
        }

        if ($compression !== 1) {
            throw new RuntimeException(
                'Only uncompressed TIFF frames can be previewed (compression ' . $compression . ').'
            );
        }

        if ($samples !== 1) {
            throw new RuntimeException('Only single-channel (grayscale) frames can be previewed.');
        }

        if ($bits !== 8 && $bits !== 16) {
            throw new RuntimeException("Unsupported bit depth: {$bits}.");
        }

        $strips = $this->stripOffsets($tiff, $tags, $little);
        $wanted = $width * $height * ($bits === 16 ? 2 : 1);

        // The strips are concatenated as bytes and nothing is interpreted yet.
        // This is the line that used to cost an array entry per pixel; it now
        // costs one copy of the frame, which is what the frame costs.
        $raw = '';
        foreach ($strips as $offset) {
            $need = $wanted - strlen($raw);
            if ($need <= 0) break;

            $raw .= substr($tiff, $offset, $need);
        }

        if (strlen($raw) < $wanted) {
            throw new RuntimeException('TIFF pixel data is truncated.');
        }

        return [
            // Always 16-bit little-endian, whatever came in, so that
            // everything downstream reads one format. WhiteIsZero is inverted
            // here too — in the same pass, rather than in one of its own.
            'samples' => $this->toSamples($raw, $bits, $little, $photometric === 0),
            'width' => $width,
            'height' => $height,
            'maxValue' => (1 << $bits) - 1,
        ];
    }

    /**
     * How many pixels are turned into a PHP array at a time.
     *
     * The point of the rewrite is that pixels live in a binary string, but the
     * byte-level work still belongs in `unpack`, which is C. So the string is
     * walked in blocks: `unpack` does the decoding at its own speed, and no
     * more than one block exists as an array at any moment. Eight thousand
     * pixels is about a hundred kilobytes — small enough to be invisible next
     * to the frame itself, large enough that the per-call cost disappears.
     */
    public const BLOCK_PIXELS = 8192;

    /**
     * Normalise raw strip bytes to 16-bit little-endian samples.
     *
     * The frames this platform actually handles are already in that form, and
     * that case returns the string untouched — no decoding, no re-packing, no
     * second copy. Everything else is converted in blocks.
     */
    private function toSamples(string $raw, int $bits, bool $little, bool $invert): string
    {
        if ($bits === 16 && $little && !$invert) {
            return $raw;
        }

        $ceiling = (1 << $bits) - 1;
        $step = $bits === 16 ? 2 : 1;
        $format = $bits === 16 ? ($little ? 'v*' : 'n*') : 'C*';
        $length = strlen($raw);

        $out = '';
        for ($at = 0; $at < $length; $at += self::BLOCK_PIXELS * $step) {
            $values = unpack($format, substr($raw, $at, self::BLOCK_PIXELS * $step));

            if ($invert) {
                // WhiteIsZero: invert, or the preview is a photographic
                // negative of the frame.
                foreach ($values as $i => $v) {
                    $values[$i] = $ceiling - $v;
                }
            }

            $out .= pack('v*', ...$values);
        }

        return $out;
    }

    /**
     * The lowest and highest sample in a frame.
     *
     * Public because [FrameMetrics] quotes the reference frame's range beside
     * its error figures, and a second implementation of "what range is this
     * frame in" would be a second answer to the question.
     *
     * `min()` and `max()` run over a block at C speed; the PHP loop is over
     * blocks, not pixels.
     *
     * @return array{0: int, 1: int}
     */
    public function range(string $samples): array
    {
        $low = PHP_INT_MAX;
        $high = 0;
        $length = strlen($samples);

        for ($at = 0; $at < $length; $at += self::BLOCK_PIXELS * 2) {
            $values = unpack('v*', substr($samples, $at, self::BLOCK_PIXELS * 2));

            $low = min($low, min($values));
            $high = max($high, max($values));
        }

        return [$low === PHP_INT_MAX ? 0 : $low, $high];
    }

    /** @return array<int> byte offsets of each strip */
    private function stripOffsets(string $tiff, array $tags, bool $little): array
    {
        if (!isset($tags[273])) {
            throw new RuntimeException('TIFF has no strip offsets.');
        }

        $tag = $tags[273];

        if ($tag['count'] === 1) {
            return [$tag['value']];
        }

        // Multiple strips: the entry holds a pointer to the offset array.
        $arrayAt = $this->u32($tiff, $tag['entry'] + 8, $little);
        $size = $tag['type'] === 3 ? 2 : 4;

        $offsets = [];
        for ($i = 0; $i < $tag['count']; $i++) {
            $at = $arrayAt + ($i * $size);
            $offsets[] = $size === 2
                ? $this->u16($tiff, $at, $little)
                : $this->u32($tiff, $at, $little);
        }

        return $offsets;
    }

    private function u16(string $s, int $at, bool $little): int
    {
        $bytes = substr($s, $at, 2);
        if (strlen($bytes) < 2) {
            throw new RuntimeException('TIFF ended unexpectedly.');
        }

        return unpack($little ? 'v' : 'n', $bytes)[1];
    }

    private function u32(string $s, int $at, bool $little): int
    {
        $bytes = substr($s, $at, 4);
        if (strlen($bytes) < 4) {
            throw new RuntimeException('TIFF ended unexpectedly.');
        }

        return unpack($little ? 'V' : 'N', $bytes)[1];
    }

    // -------------------------------------------------------------- scaling

    /**
     * Box-average down to [$maxSide]. Averaging rather than nearest-neighbour
     * because dropping pixels makes CT noise look like structure.
     *
     * Only the source rows one output row is built from are unpacked at a
     * time — `factor` rows, so four of them for a 2048-wide frame going to
     * 512. The whole frame is never an array, and the result is packed back
     * into a string as it is produced.
     *
     * @param  array{samples: string, width: int, height: int}  $image
     * @return array{0: string, 1: int, 2: int}
     */
    private function downscale(array $image, int $maxSide): array
    {
        ['samples' => $samples, 'width' => $width, 'height' => $height] = $image;

        $longest = max($width, $height);
        if ($longest <= $maxSide) {
            return [$samples, $width, $height];
        }

        $factor = (int) ceil($longest / $maxSide);
        $outW = (int) max(1, floor($width / $factor));
        $outH = (int) max(1, floor($height / $factor));

        $out = '';
        for ($y = 0; $y < $outH; $y++) {
            // The band of source rows this output row averages, unpacked once
            // and 1-indexed: source pixel ($dy, $sx) is at $dy * $width + $sx + 1.
            $band = unpack('v*', substr(
                $samples,
                $y * $factor * $width * 2,
                $factor * $width * 2,
            ));

            $row = '';
            for ($x = 0; $x < $outW; $x++) {
                $srcXStart = $x * $factor;
                $sum = 0;
                $n = 0;

                for ($dy = 0; $dy < $factor; $dy++) {
                    $at = $dy * $width + $srcXStart + 1;
                    for ($dx = 0; $dx < $factor; $dx++) {
                        // Past the end reads as zero, as it did before: a
                        // frame whose height is not a multiple of the factor
                        // leaves the last band short.
                        $sum += $band[$at + $dx] ?? 0;
                        $n++;
                    }
                }

                $row .= pack('v', $n > 0 ? intdiv($sum, $n) : 0);
            }

            $out .= $row;
        }

        return [$out, $outW, $outH];
    }

    /**
     * Map to 0-255 across the range the caller measured.
     *
     * The range arrives as an argument rather than being computed here
     * because [range()] is the second pass and this is the third; asking for
     * min and max again would walk the frame one more time for an answer
     * already in hand.
     */
    private function windowTo8Bit(string $samples, int $min, int $max): string
    {
        $count = intdiv(strlen($samples), 2);
        $span = $max - $min;

        // A flat frame carries no information; render it mid-grey rather than
        // dividing by zero.
        if ($span <= 0) {
            return str_repeat(chr(128), $count);
        }

        $out = '';
        for ($at = 0; $at < strlen($samples); $at += self::BLOCK_PIXELS * 2) {
            $values = unpack('v*', substr($samples, $at, self::BLOCK_PIXELS * 2));

            $block = '';
            foreach ($values as $v) {
                $block .= chr((int) (($v - $min) * 255 / $span));
            }

            $out .= $block;
        }

        return $out;
    }

    // ------------------------------------------------------------------ PNG

    /** Minimal 8-bit greyscale PNG. */
    private function encodePng(string $gray, int $width, int $height): string
    {
        $raw = '';
        for ($y = 0; $y < $height; $y++) {
            // Filter type 0 (none) per scanline.
            $raw .= "\x00" . substr($gray, $y * $width, $width);
        }

        $ihdr = pack('NNCCCCC', $width, $height, 8, 0, 0, 0, 0);

        return "\x89PNG\r\n\x1a\n"
            . $this->chunk('IHDR', $ihdr)
            . $this->chunk('IDAT', gzcompress($raw, 6))
            . $this->chunk('IEND', '');
    }

    private function chunk(string $type, string $data): string
    {
        return pack('N', strlen($data))
            . $type
            . $data
            . pack('N', crc32($type . $data));
    }
}

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
    /** Refuse absurd dimensions before allocating anything. */
    private const MAX_PIXELS = 8192 * 8192;

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

        [$pixels, $width, $height] = [$image['pixels'], $image['width'], $image['height']];

        [$pixels, $width, $height] = $this->downscale($pixels, $width, $height, $maxSide);

        $gray = $this->windowTo8Bit($pixels, $image['maxValue']);

        return $this->encodePng($gray, $width, $height);
    }

    // ----------------------------------------------------------------- TIFF

    /**
     * @return array{pixels: array<int>, width: int, height: int, maxValue: int}
     */
    private function decode(string $tiff): array
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
        $expected = $width * $height;

        $pixels = [];
        foreach ($strips as $offset) {
            $remaining = $expected - count($pixels);
            if ($remaining <= 0) break;

            $chunk = $bits === 16
                ? unpack($little ? 'v*' : 'n*', substr($tiff, $offset, $remaining * 2))
                : unpack('C*', substr($tiff, $offset, $remaining));

            foreach ($chunk as $p) {
                $pixels[] = $p;
            }
        }

        if (count($pixels) < $expected) {
            throw new RuntimeException('TIFF pixel data is truncated.');
        }

        // WhiteIsZero: invert so the preview is not a photographic negative.
        if ($photometric === 0) {
            $max = (1 << $bits) - 1;
            foreach ($pixels as $i => $p) {
                $pixels[$i] = $max - $p;
            }
        }

        return [
            'pixels' => $pixels,
            'width' => $width,
            'height' => $height,
            'maxValue' => (1 << $bits) - 1,
        ];
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
     * @param  array<int>  $pixels
     * @return array{0: array<int>, 1: int, 2: int}
     */
    private function downscale(array $pixels, int $width, int $height, int $maxSide): array
    {
        $longest = max($width, $height);
        if ($longest <= $maxSide) {
            return [$pixels, $width, $height];
        }

        $factor = (int) ceil($longest / $maxSide);
        $outW = (int) max(1, floor($width / $factor));
        $outH = (int) max(1, floor($height / $factor));

        $out = [];
        for ($y = 0; $y < $outH; $y++) {
            $srcYStart = $y * $factor;

            for ($x = 0; $x < $outW; $x++) {
                $srcXStart = $x * $factor;
                $sum = 0;
                $n = 0;

                for ($dy = 0; $dy < $factor; $dy++) {
                    $row = ($srcYStart + $dy) * $width;
                    for ($dx = 0; $dx < $factor; $dx++) {
                        $sum += $pixels[$row + $srcXStart + $dx] ?? 0;
                        $n++;
                    }
                }

                $out[] = $n > 0 ? intdiv($sum, $n) : 0;
            }
        }

        return [$out, $outW, $outH];
    }

    /**
     * Map to 0-255 across the frame's own range.
     *
     * @param  array<int>  $pixels
     */
    private function windowTo8Bit(array $pixels, int $maxValue): string
    {
        $min = min($pixels);
        $max = max($pixels);
        $span = $max - $min;

        // A flat frame carries no information; render it mid-grey rather than
        // dividing by zero.
        if ($span <= 0) {
            return str_repeat(chr(128), count($pixels));
        }

        $out = '';
        foreach ($pixels as $p) {
            $out .= chr((int) (($p - $min) * 255 / $span));
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

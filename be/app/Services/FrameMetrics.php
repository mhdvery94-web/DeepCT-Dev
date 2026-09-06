<?php

namespace App\Services;

use RuntimeException;

/**
 * Compares two 16-bit grayscale frames and says how far apart they are.
 *
 * Used for the hold-out check: a frame the archive already contained is
 * regenerated from its two neighbours, and the result is measured against the
 * one that was really there. That is the only ground truth this platform can
 * ever have — the frames a researcher actually wants filled are, by
 * definition, ones nobody has.
 *
 * Two numbers, deliberately, and they answer different questions:
 *
 * - **MAE** is in raw 16-bit counts. It is the average absolute difference per
 *   pixel and needs no reference point to interpret: 40 counts on a frame
 *   whose data spans 3,000 counts is a very different thing from 40 counts on
 *   one that spans 60,000, and reporting the reference frame's own range is
 *   what lets a reader tell those apart.
 * - **PSNR** is in decibels against the full 16-bit range, which is the
 *   convention. Be careful reading it: CT frames rarely fill that range, so
 *   the figure runs flattering compared with the same scene measured against
 *   its actual span. It is comparable between runs on this platform and should
 *   not be compared against papers without checking what MAX they used.
 */
class FrameMetrics
{
    public function __construct(private TiffPreview $tiff) {}

    /** The denominator PSNR is quoted against: a full 16-bit range. */
    public const MAX_VALUE = 65535;

    /**
     * @return array{
     *     mae: float,
     *     psnr: float|null,
     *     rmse: float,
     *     pixels: int,
     *     reference_min: int,
     *     reference_max: int
     * }
     *
     * @throws RuntimeException when either frame will not decode, or the two
     *                          disagree about their dimensions.
     */
    public function compare(string $referenceTiff, string $candidateTiff): array
    {
        $a = $this->tiff->decode($referenceTiff);
        $b = $this->tiff->decode($candidateTiff);

        if ($a['width'] !== $b['width'] || $a['height'] !== $b['height']) {
            throw new RuntimeException(
                "Frames differ in size: {$a['width']}x{$a['height']} against " .
                "{$b['width']}x{$b['height']}."
            );
        }

        $reference = $a['samples'];
        $candidate = $b['samples'];
        $count = intdiv(strlen($reference), 2);

        if ($count === 0) {
            throw new RuntimeException('Frame decoded to no pixels.');
        }

        [$min, $max] = $this->tiff->range($reference);

        $absolute = 0.0;
        $squared = 0.0;

        // Two frames, walked together a block at a time. Holding both as PHP
        // arrays cost 262 MB for a pair of 2048x2048 frames — inside a queue
        // worker whose whole budget was 512 MB, which is how a run died
        // mid-job on 25 August with nothing on screen but "queued".
        $step = TiffPreview::BLOCK_PIXELS * 2;

        for ($at = 0; $at < strlen($reference); $at += $step) {
            $r = unpack('v*', substr($reference, $at, $step));
            $c = unpack('v*', substr($candidate, $at, $step));

            foreach ($r as $i => $value) {
                $difference = $value - $c[$i];

                $absolute += abs($difference);
                $squared += $difference * $difference;
            }
        }

        $mae = $absolute / $count;
        $mse = $squared / $count;
        $rmse = sqrt($mse);

        return [
            'mae' => round($mae, 3),
            // Identical frames give an MSE of zero, and log10(0) is negative
            // infinity rather than a very large number. Null says "no error to
            // measure" instead of writing an infinity into JSON.
            'psnr' => $mse > 0
                ? round(20 * log10(self::MAX_VALUE / $rmse), 2)
                : null,
            'rmse' => round($rmse, 3),
            'pixels' => $count,
            'reference_min' => $min === PHP_INT_MAX ? 0 : $min,
            'reference_max' => $max,
        ];
    }
}

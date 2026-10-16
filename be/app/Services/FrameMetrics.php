<?php

namespace App\Services;

use RuntimeException;

/** Measurements on decoded raw uint16 samples, never display-windowed previews. */
class FrameMetrics
{
    public const MAX_VALUE = 65535;

    private const WINDOW = 7;

    public function __construct(private TiffPreview $tiff) {}

    public static function method(): array
    {
        return [
            'sample_domain' => 'raw_uint16', 'data_range' => self::MAX_VALUE,
            'mae_decimals' => 3, 'rmse_decimals' => 3, 'psnr_decimals' => 2,
            'ssim' => ['window_size' => self::WINDOW, 'weighting' => 'uniform',
                'boundary' => 'valid', 'covariance' => 'sample', 'k1' => 0.01, 'k2' => 0.03],
        ];
    }

    /** Existing rounded flat metrics remain compatible; PSNR status uses exact MSE. */
    public function compare(string $referenceTiff, string $candidateTiff): array
    {
        return $this->measure($this->decode($referenceTiff), $this->decode($candidateTiff));
    }

    /** Linear t=.5 baseline, rounded to uint16 half up, in bounded blocks. */
    public function compareMidpoint(string $referenceTiff, string $leftTiff, string $rightTiff): array
    {
        $reference = $this->decode($referenceTiff);
        $left = $this->decode($leftTiff);
        $right = $this->decode($rightTiff);
        $this->sameSize($reference, $left);
        $this->sameSize($reference, $right);
        $samples = '';
        $step = TiffPreview::BLOCK_PIXELS * 2;
        $length = strlen($left['samples']);
        for ($at = 0; $at < $length; $at += $step) {
            $a = unpack('v*', substr($left['samples'], $at, $step));
            $b = unpack('v*', substr($right['samples'], $at, $step));
            foreach ($a as $i => $v) {
                $a[$i] = intdiv($v + $b[$i] + 1, 2);
            }
            $samples .= pack('v*', ...$a);
        }
        unset($left, $right, $a, $b);
        $result = $this->measure($reference, ['width' => $reference['width'], 'height' => $reference['height'], 'samples' => $samples]);
        $result['method'] += ['baseline' => 'linear_midpoint', 'midpoint_rounding' => 'half_up'];

        return $result;
    }

    private function decode(string $bytes): array
    {
        $image = $this->tiff->decode($bytes);
        if ($image['maxValue'] !== self::MAX_VALUE) {
            throw new RuntimeException('Evaluation requires raw uint16 frames.');
        }

        return $image;
    }

    private function sameSize(array $a, array $b): void
    {
        if ($a['width'] !== $b['width'] || $a['height'] !== $b['height']) {
            throw new RuntimeException('Frames differ in size.');
        }
    }

    private function measure(array $a, array $b): array
    {
        $this->sameSize($a, $b);
        $reference = $a['samples'];
        $candidate = $b['samples'];
        $length = strlen($reference);
        $count = intdiv($length, 2);
        if ($count === 0) {
            throw new RuntimeException('Frame decoded to no pixels.');
        }
        [$min, $max] = $this->tiff->range($reference);
        $absolute = $squared = 0.0;
        $step = TiffPreview::BLOCK_PIXELS * 2;
        for ($at = 0; $at < $length; $at += $step) {
            $r = unpack('v*', substr($reference, $at, $step));
            $c = unpack('v*', substr($candidate, $at, $step));
            foreach ($r as $i => $value) {
                $difference = $value - $c[$i];
                $absolute += abs($difference);
                $squared += $difference * $difference;
            }
        }
        unset($r, $c);
        $mse = $squared / $count;
        $rmse = sqrt($mse);
        $ssim = $this->ssim($reference, $candidate, $a['width'], $a['height']);

        return [
            'mae' => round($absolute / $count, 3),
            'psnr' => $mse > 0 ? round(20 * log10(self::MAX_VALUE / $rmse), 2) : null,
            'rmse' => round($rmse, 3), 'ssim' => $ssim,
            'pixels' => $count, 'reference_min' => $min, 'reference_max' => $max,
            'psnr_status' => $mse === 0.0 ? 'infinite' : 'available',
            'ssim_status' => $ssim === null ? 'image_too_small' : 'available',
            'method' => self::method(),
        ];
    }

    /**
     * Separable sliding box moments: seven unpacked rows and five column sums.
     * O(width * window) working arrays; no frame-sized PHP arrays or SSIM map.
     * Matches skimage's uniform 7x7, sample covariance, cropped valid mean.
     */
    private function ssim(string $reference, string $candidate, int $width, int $height): ?float
    {
        $window = self::WINDOW;
        if (min($width, $height) < $window) {
            return null;
        }
        $sx = $sy = $sxx = $syy = $sxy = array_fill(1, $width, 0);
        $rowsA = $rowsB = [];
        $total = 0.0;
        $windows = 0;
        $n = $window * $window;
        $covariance = $n / ($n - 1);
        $c1 = (0.01 * self::MAX_VALUE) ** 2;
        $c2 = (0.03 * self::MAX_VALUE) ** 2;
        for ($y = 0; $y < $height; $y++) {
            $slot = $y % $window;
            $oldA = $rowsA[$slot] ?? null;
            $oldB = $rowsB[$slot] ?? null;
            $a = unpack('v*', substr($reference, $y * $width * 2, $width * 2));
            $b = unpack('v*', substr($candidate, $y * $width * 2, $width * 2));
            for ($x = 1; $x <= $width; $x++) {
                $u = $a[$x];
                $v = $b[$x];
                $ou = $oldA[$x] ?? 0;
                $ov = $oldB[$x] ?? 0;
                $sx[$x] += $u - $ou;
                $sy[$x] += $v - $ov;
                $sxx[$x] += $u * $u - $ou * $ou;
                $syy[$x] += $v * $v - $ov * $ov;
                $sxy[$x] += $u * $v - $ou * $ov;
            }
            $rowsA[$slot] = $a;
            $rowsB[$slot] = $b;
            if ($y < $window - 1) {
                continue;
            }
            $tx = $ty = $txx = $tyy = $txy = 0.0;
            for ($x = 1; $x <= $width; $x++) {
                $expired = $x - $window;
                $tx += $sx[$x] - ($sx[$expired] ?? 0);
                $ty += $sy[$x] - ($sy[$expired] ?? 0);
                $txx += $sxx[$x] - ($sxx[$expired] ?? 0);
                $tyy += $syy[$x] - ($syy[$expired] ?? 0);
                $txy += $sxy[$x] - ($sxy[$expired] ?? 0);
                if ($x < $window) {
                    continue;
                }
                $ux = $tx / $n;
                $uy = $ty / $n;
                $vx = $covariance * ($txx / $n - $ux * $ux);
                $vy = $covariance * ($tyy / $n - $uy * $uy);
                $vxy = $covariance * ($txy / $n - $ux * $uy);
                $total += ((2 * $ux * $uy + $c1) * (2 * $vxy + $c2))
                    / (($ux * $ux + $uy * $uy + $c1) * ($vx + $vy + $c2));
                $windows++;
            }
        }

        return max(-1.0, min(1.0, $total / $windows));
    }
}

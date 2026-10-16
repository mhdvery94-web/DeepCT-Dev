<?php

namespace App\Services;

use App\Models\AnalysisRecord;

/** Public evaluation contract. Never copy arbitrary persisted arrays or error text. */
class AnalysisEvidence
{
    public function fromRecord(AnalysisRecord $record): array
    {
        $v = is_array($record->validation) ? $record->validation : [];
        $status = ($v['schema_version'] ?? null) === 1
            && in_array($v['evaluation_status'] ?? null, ['completed', 'no_reference', 'evaluation_failed'], true)
            ? $v['evaluation_status'] : 'legacy_unknown';
        $reason = match ($status) {
            'no_reference' => 'no_uploaded_midpoint',
            'evaluation_failed' => 'measurement_failed',
            default => null,
        };

        return [
            'schema_version' => 1, 'evaluation_status' => $status, 'reason_code' => $reason,
            'metrics' => $this->metrics($v), 'metric_status' => $this->statuses($v),
            'method' => $this->method($v['method'] ?? null),
            'reference' => $this->reference($v),
            'model' => $this->model($v['model'] ?? $record->model_snapshot),
            'baseline' => $this->baseline($v['baseline'] ?? null),
            'comparison' => $this->comparison($v['comparison'] ?? null),
        ];
    }

    private function number(mixed $value, float $min, float $max): int|float|null
    {
        return (is_int($value) || is_float($value)) && is_finite((float) $value)
            && $value >= $min && $value <= $max ? $value : null;
    }

    private function metrics(array $v): array
    {
        $result = [];
        foreach (['mae' => [0, 65535], 'rmse' => [0, 65535], 'psnr' => [0, 1000],
            'ssim' => [-1, 1], 'pixels' => [1, PHP_INT_MAX],
            'reference_min' => [0, 65535], 'reference_max' => [0, 65535]] as $key => [$min, $max]) {
            $result[$key] = $this->number($v[$key] ?? null, $min, $max);
        }

        return $result;
    }

    private function statuses(array $v): array
    {
        return [
            'psnr' => in_array($v['psnr_status'] ?? null, ['available', 'infinite', 'unavailable'], true) ? $v['psnr_status'] : 'unknown',
            'ssim' => in_array($v['ssim_status'] ?? null, ['available', 'image_too_small', 'unavailable'], true) ? $v['ssim_status'] : 'unknown',
        ];
    }

    private function method(mixed $v): ?array
    {
        if (! is_array($v)) {
            return null;
        }
        $result = [];
        foreach (FrameMetrics::method() + ['baseline' => 'linear_midpoint', 'midpoint_rounding' => 'half_up'] as $key => $expected) {
            if ($key === 'ssim' && is_array($v[$key] ?? null)) {
                foreach ($expected as $parameter => $value) {
                    if (($v[$key][$parameter] ?? null) == $value && is_scalar($v[$key][$parameter] ?? null)) {
                        $result[$key][$parameter] = $value;
                    }
                }
            } elseif (isset($v[$key]) && is_scalar($v[$key]) && $v[$key] == $expected) {
                $result[$key] = $expected;
            }
        }

        return $result ?: null;
    }

    private function reference(array $v): ?array
    {
        $r = is_array($v['reference'] ?? null) ? $v['reference'] : $v;
        $index = $r['index'] ?? null;
        $from = $r['from'] ?? null;
        if (! is_int($index) || $index < 0 || ! is_array($from) || count($from) !== 2
            || ! isset($from[0], $from[1]) || ! is_int($from[0]) || ! is_int($from[1])
            || $from[0] < 0 || $from[0] >= $index || $from[1] <= $index
            || $index - $from[0] !== $from[1] - $index) {
            return null;
        }

        return ['source' => 'uploaded_midpoint', 'index' => $index, 'from' => array_values($from)];
    }

    private function model(mixed $v): ?array
    {
        if (! is_array($v)) {
            return null;
        }
        $result = [];
        if (is_int($v['id'] ?? null) && $v['id'] > 0) {
            $result['id'] = $v['id'];
        }
        foreach (['name' => 120, 'slug' => 120, 'version' => 64, 'model_id' => 120] as $key => $limit) {
            if (is_string($v[$key] ?? null) && mb_strlen($v[$key]) <= $limit
                && preg_match('/\A[\pL\pN ._()+-]+\z/u', $v[$key]) === 1) {
                $result[$key] = $v[$key];
            }
        }
        if (is_string($v['sha256'] ?? null) && preg_match('/\A[a-f0-9]{64}\z/', $v['sha256'])) {
            $result['sha256'] = $v['sha256'];
        }
        if (in_array($v['provenance'] ?? null, ['managed_manifest_sha256', 'legacy_registry_metadata'], true)) {
            $result['provenance'] = $v['provenance'];
        }

        return $result ?: null;
    }

    private function baseline(mixed $v): array
    {
        $v = is_array($v) ? $v : [];
        $status = in_array($v['status'] ?? null, ['completed', 'baseline_failed'], true) ? $v['status'] : 'unavailable';

        return ['status' => $status, 'reason_code' => $status === 'baseline_failed' ? 'baseline_failed' : null,
            'metrics' => $this->metrics($v), 'metric_status' => $this->statuses($v),
            'method' => $this->method($v['method'] ?? null)];
    }

    private function comparison(mixed $v): array
    {
        $v = is_array($v) ? $v : [];
        $completed = ($v['status'] ?? null) === 'completed' && ($v['precision'] ?? null) === 'recorded_precision';
        $result = ['status' => $completed ? 'completed' : 'unavailable',
            'precision' => $completed ? 'recorded_precision' : null];
        foreach (['mae_reduction', 'rmse_reduction', 'psnr_gain_db', 'ssim_gain'] as $key) {
            $result[$key] = $completed ? $this->number($v[$key] ?? null, -65535, 65535) : null;
        }

        return $result;
    }
}

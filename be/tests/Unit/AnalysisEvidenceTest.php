<?php

namespace Tests\Unit;

use App\Models\AnalysisRecord;
use App\Services\AnalysisEvidence;
use PHPUnit\Framework\TestCase;

class AnalysisEvidenceTest extends TestCase
{
    private function evidence(?array $validation, ?array $snapshot = null): array
    {
        return (new AnalysisEvidence)->fromRecord(new AnalysisRecord(['validation' => $validation, 'model_snapshot' => $snapshot]));
    }

    public function test_null_and_legacy_have_unknown_cause(): void
    {
        foreach ([null, ['error' => 'token=secret /private/path'], ['mae' => 3, 'psnr' => null]] as $legacy) {
            $result = $this->evidence($legacy);
            $this->assertSame(1, $result['schema_version']);
            $this->assertSame('legacy_unknown', $result['evaluation_status']);
            $this->assertNull($result['reason_code']);
            $this->assertStringNotContainsString('secret', json_encode($result));
        }
    }

    public function test_allowlist_drops_nested_paths_secrets_and_forged_codes(): void
    {
        $result = $this->evidence([
            'schema_version' => 1, 'evaluation_status' => 'completed', 'reason_code' => 'token=secret',
            'mae' => 2, 'psnr' => 99, 'psnr_status' => '/private/secret', 'ssim_status' => 'forged',
            'reference' => ['source' => 'uploaded_midpoint', 'index' => 3, 'from' => [1, 5], 'path' => '/private/secret'],
            'method' => ['secret' => ['token' => 'secret']],
            'baseline' => ['status' => 'completed', 'mae' => 3, 'endpoint' => 'https://secret'],
            'comparison' => ['status' => 'completed', 'precision' => 'raw', 'secret' => 'secret'],
        ], ['id' => 1, 'name' => 'Model A', 'version' => '1.0', 'endpoint_url' => 'https://secret', 'token' => 'secret']);
        $this->assertSame('completed', $result['evaluation_status']);
        $this->assertNull($result['reason_code']);
        $this->assertSame(2, $result['metrics']['mae']);
        $this->assertSame('unknown', $result['metric_status']['psnr']);
        $this->assertSame('Model A', $result['model']['name']);
        $this->assertSame(['source' => 'uploaded_midpoint', 'index' => 3, 'from' => [1, 5]], $result['reference']);
        $json = json_encode($result);
        foreach (['secret', '/private', 'endpoint', 'forged'] as $unsafe) {
            $this->assertStringNotContainsString($unsafe, $json);
        }
    }

    public function test_forged_status_and_reason_are_unknown(): void
    {
        $result = $this->evidence(['schema_version' => 1, 'evaluation_status' => 'forged', 'reason_code' => 'no_uploaded_midpoint']);
        $this->assertSame('legacy_unknown', $result['evaluation_status']);
        $this->assertNull($result['reason_code']);
        $result = $this->evidence(['schema_version' => 1, 'evaluation_status' => 'no_reference', 'reason_code' => 'measurement_failed']);
        $this->assertSame('no_uploaded_midpoint', $result['reason_code']);
    }

    public function test_non_finite_metrics_cannot_escape_json(): void
    {
        $record = new AnalysisRecord;
        // Avoid JSON cast rejecting NaN before the sanitizer can inspect it.
        $record->setRawAttributes(['validation' => '{"schema_version":1,"evaluation_status":"completed","mae":1e999,"rmse":-1,"ssim":2,"psnr":null,"psnr_status":"infinite"}']);
        $result = (new AnalysisEvidence)->fromRecord($record);
        $this->assertNull($result['metrics']['mae']);
        $this->assertNull($result['metrics']['rmse']);
        $this->assertNull($result['metrics']['ssim']);
        $this->assertSame('infinite', $result['metric_status']['psnr']);
        $this->assertIsString(json_encode($result, JSON_THROW_ON_ERROR));
    }
    public function test_malformed_boolean_method_values_are_not_canonicalized(): void
    {
        $result = $this->evidence([
            'schema_version' => 1, 'evaluation_status' => 'completed',
            'method' => ['sample_domain' => true, 'data_range' => true,
                'mae_decimals' => true, 'baseline' => true, 'midpoint_rounding' => true,
                'ssim' => ['window_size' => true, 'weighting' => true, 'boundary' => true,
                    'covariance' => true, 'k1' => true, 'k2' => true]],
        ]);
        $this->assertNull($result['method']);
        foreach ([['ssim' => true], ['data_range' => '65535', 'ssim' => ['k1' => '0.01']]] as $malformed) {
            $result = $this->evidence(['schema_version' => 1, 'evaluation_status' => 'completed', 'method' => $malformed]);
            $this->assertNull($result['method']);
        }
        $canonical = \App\Services\FrameMetrics::method();
        $result = $this->evidence(['schema_version' => 1, 'evaluation_status' => 'completed', 'method' => $canonical]);
        $this->assertSame($canonical, $result['method']);
    }

}

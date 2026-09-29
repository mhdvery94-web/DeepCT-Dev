<?php

namespace Tests\Feature;

use App\Models\Model;
use App\Services\ModelHealthChecker;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/**
 * What the health checker writes down about a failure.
 *
 * Two columns, two audiences. `health_check_error` keeps the checker's own
 * words for the administrator who has to act on them; `health_check_reason`
 * is the code the client turns into a sentence a researcher can read.
 */
class ModelHealthCheckTest extends TestCase
{
    use RefreshDatabase;

    private function model(array $overrides = []): Model
    {
        return Model::create(array_merge([
            'name' => 'deepCT TC-D',
            'version' => 'v1',
            'kind' => 'inference',
            'endpoint_url' => 'https://worker.example/predict',
            'status' => 'offline',
            'is_active' => true,
        ], $overrides));
    }

    public function test_a_model_without_an_endpoint_is_not_a_dead_server(): void
    {
        $model = $this->model(['endpoint_url' => null]);

        (new ModelHealthChecker())->check($model);

        $model->refresh();
        $this->assertSame('offline', $model->status);
        // Not `unreachable`: nothing was ever configured to reach. Telling
        // someone to restart a server that was never registered is the wrong
        // instruction.
        $this->assertSame('no_endpoint', $model->health_check_reason);
    }

    public function test_an_ngrok_error_header_is_recorded_as_a_dead_tunnel(): void
    {
        Http::fake([
            '*' => Http::response('', 502, ['ngrok-error-code' => 'ERR_NGROK_3200']),
        ]);

        $model = $this->model();

        (new ModelHealthChecker())->check($model);

        $model->refresh();
        $this->assertSame('offline', $model->status);
        $this->assertSame('tunnel_down', $model->health_check_reason);
        // The raw words survive, because the administrator is the one who
        // restarts Kaggle and this code is what says which failure it was.
        $this->assertStringContainsString(
            'ERR_NGROK_3200',
            $model->health_check_error
        );
    }

    public function test_a_status_the_app_did_not_serve_is_unreachable(): void
    {
        // 502 without an ngrok header: something answered, but not FastAPI.
        Http::fake(['*' => Http::response('', 502)]);

        $model = $this->model();

        (new ModelHealthChecker())->check($model);

        $model->refresh();
        $this->assertSame('offline', $model->status);
        $this->assertSame('unreachable', $model->health_check_reason);
    }

    public function test_a_healthy_probe_clears_the_reason(): void
    {
        // 404 on the tunnel root means FastAPI answered: only /predict exists.
        Http::fake(['*' => Http::response('', 404)]);

        $model = $this->model([
            'status' => 'offline',
            'health_check_error' => 'Tunnel is not running (ERR_NGROK_3200)',
            'health_check_reason' => 'tunnel_down',
        ]);

        (new ModelHealthChecker())->check($model);

        $model->refresh();
        $this->assertSame('online', $model->status);
        $this->assertNull($model->health_check_reason);
        $this->assertNull($model->health_check_error);
    }

    public function test_a_catalogued_model_is_online_only_when_it_is_listed(): void
    {
        Http::fake([
            'https://worker.example/models' => Http::response([
                'models' => [[
                    'name' => 'deepct-tc-d',
                    'endpoint' => '/predict/deepct-tc-d',
                    'active' => true,
                ]],
            ]),
        ]);

        $model = $this->model([
            'slug' => 'deepct-tc-d',
            'base_url' => 'https://worker.example',
            'endpoint' => '/predict/deepct-tc-d',
            'full_endpoint_url' => 'https://worker.example/predict/deepct-tc-d',
        ]);

        (new ModelHealthChecker())->check($model);

        $model->refresh();
        $this->assertSame('online', $model->status);
        $this->assertTrue($model->worker_active);
    }
}

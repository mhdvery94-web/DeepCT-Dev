<?php

namespace Tests\Feature;

use App\Models\Model;
use App\Models\User;
use App\Services\ModelHealthChecker;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class ModelCatalogSyncTest extends TestCase
{
    use RefreshDatabase;

    private string $token;

    protected function setUp(): void
    {
        parent::setUp();

        User::create([
            'name' => 'Administrator',
            'email' => 'admin@brin.go.id',
            'password' => Hash::make('password123'),
            'role' => 'admin',
            'is_active' => true,
        ]);

        $this->token = $this->tokenFor('admin@brin.go.id', 'password123');
    }

    public function test_an_admin_can_sync_models_from_one_server_without_duplicates(): void
    {
        $this->fakeServer('old-weights.h5');

        $this->apiAs($this->token)->postJson('/api/admin/models/sync', [
            'base_url' => 'https://worker.example',
            'auth_token' => 'server-secret',
            'verify_tls' => true,
        ])
            ->assertOk()
            ->assertJsonPath('data.created', 1)
            ->assertJsonPath('data.updated', 0);

        $model = Model::firstOrFail();
        $this->assertSame('ginet-tcd-revisi', $model->slug);
        $this->assertSame('https://worker.example', $model->base_url);
        $this->assertSame('/predict/ginet-tcd-revisi', $model->endpoint);
        $this->assertSame(
            'https://worker.example/predict/ginet-tcd-revisi',
            $model->full_endpoint_url
        );
        $this->assertSame($model->full_endpoint_url, $model->endpoint_url);
        $this->assertSame('old-weights.h5', $model->model_file);
        $this->assertSame('server-secret', $model->auth_token);
        $this->assertTrue($model->is_active);

        // Admin choices survive sync; only remote catalogue fields change.
        $model->update(['is_active' => false, 'auth_token' => 'kept-secret']);
        $this->fakeServer('new-weights.keras');

        $this->apiAs($this->token)->postJson('/api/admin/models/sync', [
            'base_url' => 'https://worker.example',
        ])
            ->assertOk()
            ->assertJsonPath('data.created', 0)
            ->assertJsonPath('data.updated', 1);

        $this->assertSame(1, Model::count());
        $model->refresh();
        $this->assertSame('new-weights.keras', $model->model_file);
        $this->assertFalse($model->is_active);
        $this->assertSame('kept-secret', $model->auth_token);
    }

    public function test_sync_marks_a_model_missing_without_deleting_it(): void
    {
        $this->fakeServer('weights.h5');
        $this->apiAs($this->token)->postJson('/api/admin/models/sync', [
            'base_url' => 'https://worker.example',
        ])->assertOk();

        Http::fake([
            'https://worker.example/' => Http::response(['status' => 'running']),
            'https://worker.example/models' => Http::response([
                'count' => 0,
                'models' => [],
            ]),
        ]);

        $this->apiAs($this->token)->postJson('/api/admin/models/sync', [
            'base_url' => 'https://worker.example',
        ])
            ->assertOk()
            ->assertJsonPath('data.missing', 1);

        $model = Model::firstOrFail();
        $this->assertSame('offline', $model->status);
        $this->assertSame(ModelHealthChecker::REASON_MODEL_MISSING, $model->health_check_reason);
    }

    public function test_model_health_requires_the_slug_to_remain_in_the_catalogue(): void
    {
        $model = Model::create([
            'name' => 'Ginet TC-D Revisi',
            'slug' => 'ginet-tcd-revisi',
            'version' => 'remote',
            'kind' => 'inference',
            'base_url' => 'https://worker.example',
            'endpoint' => '/predict/ginet-tcd-revisi',
            'full_endpoint_url' => 'https://worker.example/predict/ginet-tcd-revisi',
            'endpoint_url' => 'https://worker.example/predict/ginet-tcd-revisi',
            'status' => 'online',
            'is_active' => true,
        ]);

        Http::fake([
            'https://worker.example/models' => Http::response([
                'count' => 1,
                'models' => [[
                    'name' => 'another-model',
                    'endpoint' => '/predict/another-model',
                ]],
            ]),
        ]);

        app(ModelHealthChecker::class)->check($model);

        $this->assertSame('offline', $model->fresh()->status);
        $this->assertSame(
            ModelHealthChecker::REASON_MODEL_MISSING,
            $model->fresh()->health_check_reason
        );
    }

    private function fakeServer(string $file): void
    {
        Http::fake([
            'https://worker.example/' => Http::response([
                'service' => 'tomography-ai',
                'status' => 'running',
            ]),
            'https://worker.example/models' => Http::response([
                'count' => 1,
                'active_model' => null,
                'models' => [[
                    'name' => 'ginet-tcd-revisi',
                    'file' => $file,
                    'endpoint' => '/predict/ginet-tcd-revisi',
                    'active' => false,
                ]],
            ]),
        ]);
    }
}

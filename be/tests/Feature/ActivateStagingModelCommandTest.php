<?php

namespace Tests\Feature;

use App\Models\Model;
use App\Models\ModelUpload;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class ActivateStagingModelCommandTest extends TestCase
{
    use RefreshDatabase;

    private function fixture(): array
    {
        $this->app->detectEnvironment(fn () => 'staging');
        config([
            'model_uploads.internal_url' => 'https://tuf.internal',
            'model_uploads.public_url' => 'https://tuf.example/registry',
            'model_uploads.management_token' => 'management',
            'model_uploads.inference_token' => 'inference',
        ]);
        $owner = User::factory()->create(['role' => 'admin', 'is_active' => true]);
        $manifest = [
            'schema_version' => 1, 'model_id' => 'fixture', 'version' => '1.0.0', 'name' => 'Fixture',
            'description' => '', 'framework' => 'tensorflow', 'adapter' => 'ginet-tcd-v1',
            'weight_file' => 'model.h5', 'sha256' => str_repeat('a', 64), 'size_bytes' => 100,
            'input' => ['width' => 1024, 'height' => 1024, 'dtype' => 'uint16', 'time_scalar' => 0.5],
        ];
        $upload = ModelUpload::create([
            'user_id' => $owner->id,
            'tuf_id' => '11111111-1111-4111-8111-111111111111',
            'manifest' => $manifest,
            'state' => 'ready_for_activate',
        ]);
        Model::create([
            'name' => 'Fixture', 'slug' => 'fixture-v1-0-0', 'version' => '1.0.0',
            'managed_model_id' => 'fixture', 'weight_sha256' => str_repeat('a', 64),
            'base_url' => 'https://tuf.internal',
            'endpoint' => '/predict/fixture/1.0.0',
            'full_endpoint_url' => 'https://tuf.internal/predict/fixture/1.0.0',
            'endpoint_url' => 'https://tuf.internal/predict/fixture/1.0.0',
            'is_active' => false, 'worker_active' => false,
        ]);

        return [$upload, $manifest];
    }

    public function test_audit_is_read_only_and_works_across_upload_owners(): void
    {
        [, $manifest] = $this->fixture();
        Http::fake(['https://tuf.internal/management/uploads/*' => Http::response([
            'id' => '11111111-1111-4111-8111-111111111111', 'manifest' => $manifest,
            'state' => 'ready_for_activate', 'published' => true,
        ])]);

        $this->artisan('models:activate-staging fixture 1.0.0')
            ->expectsOutputToContain('Audit passed')
            ->assertSuccessful();
        $this->assertFalse(Model::firstOrFail()->is_active);
        Http::assertSentCount(1);
    }

    public function test_apply_uses_revisioned_activation_and_reconciles_catalog(): void
    {
        [, $manifest] = $this->fixture();
        Http::fake(function ($request) use ($manifest) {
            if ($request->method() === 'POST') {
                return Http::response([
                    'id' => '11111111-1111-4111-8111-111111111111', 'manifest' => $manifest,
                    'state' => 'active', 'published' => true,
                ]);
            }
            if (str_ends_with($request->url(), '/models')) {
                return Http::response(['models' => [[
                    'name' => 'fixture-v1-0-0', 'display_name' => 'Fixture', 'model_id' => 'fixture',
                    'version' => '1.0.0', 'sha256' => str_repeat('a', 64),
                    'endpoint' => '/predict/fixture/1.0.0', 'active' => true,
                ]]]);
            }
            if ($request->url() === 'https://tuf.internal/') {
                return Http::response(['status' => 'ok']);
            }

            return Http::response([
                'id' => '11111111-1111-4111-8111-111111111111', 'manifest' => $manifest,
                'state' => 'ready_for_activate', 'published' => true,
            ]);
        });

        $this->artisan('models:activate-staging fixture 1.0.0 --apply')
            ->expectsOutputToContain('Activated fixture 1.0.0')
            ->assertSuccessful();
        $model = Model::firstOrFail();
        $this->assertTrue($model->is_active);
        $this->assertTrue($model->worker_active);
        $this->assertNull($model->availability_transition);
        Http::assertSent(fn ($request) => $request->method() === 'POST'
            && $request->url() === 'https://tuf.internal/management/uploads/11111111-1111-4111-8111-111111111111/activate'
            && $request['revision'] === 1);
    }

    public function test_command_refuses_non_staging_environments(): void
    {
        $this->app->detectEnvironment(fn () => 'production');

        $this->artisan('models:activate-staging fixture 1.0.0')->assertFailed();
        Http::assertNothingSent();
    }
}

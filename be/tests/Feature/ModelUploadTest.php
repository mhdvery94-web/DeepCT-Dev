<?php

namespace Tests\Feature;

use App\Models\Model;
use App\Models\ModelUpload;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class ModelUploadTest extends TestCase
{
    use RefreshDatabase;

    private function admin(): array
    {
        $user = User::factory()->create(['role' => 'admin', 'is_active' => true]);

        return [$user, $user->createToken('test')->plainTextToken];
    }

    private function manifest(): array
    {
        return ['schema_version' => 1, 'model_id' => 'fixture', 'version' => '1.0.0', 'name' => 'Fixture',
            'description' => '', 'framework' => 'tensorflow', 'adapter' => 'ginet-tcd-v1', 'weight_file' => 'model.h5',
            'sha256' => str_repeat('a', 64), 'size_bytes' => 100,
            'input' => ['width' => 1024, 'height' => 1024, 'dtype' => 'uint16', 'time_scalar' => 0.5]];
    }

    public function test_upload_control_auth_ownership_and_permission_revocation(): void
    {
        config(['model_uploads.internal_url' => 'https://tuf.internal', 'model_uploads.public_url' => 'https://tuf.example/models-ingress',
            'model_uploads.management_token' => 'management-secret', 'model_uploads.inference_token' => 'inference-secret']);
        $manifest = $this->manifest();
        $uuid = '11111111-1111-4111-8111-111111111111';
        Http::fake(['*' => Http::response(['id' => $uuid, 'token' => 'scoped', 'expires_at' => time() + 900,
            'manifest' => $manifest, 'offset' => 0, 'state' => 'uploading', 'published' => false])]);
        $this->apiAs(null)->postJson('/api/admin/model-uploads', $manifest)->assertUnauthorized();
        [$owner, $token] = $this->admin();
        $response = $this->apiAs($token)->postJson('/api/admin/model-uploads', $manifest)->assertCreated();
        $id = $response->json('data.id');
        $response->assertJsonPath('data.upload_url', 'https://tuf.example/models-ingress/uploads/'.$uuid);
        $this->assertStringNotContainsString('management-secret', $response->getContent());
        Http::assertSent(fn ($r) => $r->url() === 'https://tuf.internal/management/uploads' && $r->hasHeader('Authorization', 'Bearer management-secret'));
        [, $other] = $this->admin();
        $this->apiAs($other)->getJson('/api/admin/model-uploads/'.$id)->assertNotFound();
        $owner->update(['role' => 'user']);
        foreach (['renew', 'finalize', 'test', 'publish', 'activate'] as $action) {
            $this->apiAs($token)->postJson('/api/admin/model-uploads/'.$id.'/'.$action)->assertForbidden();
        }
    }

    public function test_client_cannot_select_server_credentials_or_adaptor_source(): void
    {
        [, $token] = $this->admin();
        Http::fake();
        foreach (['internal_url', 'public_url', 'auth_token', 'path', 'adapter_source'] as $field) {
            $this->apiAs($token)->postJson('/api/admin/model-uploads', $this->manifest() + [$field => 'evil'])->assertUnprocessable();
        }
        Http::assertNothingSent();
    }

    public function test_managed_identity_cannot_be_edited_or_toggled_by_legacy_form(): void
    {
        [, $token] = $this->admin();
        $model = Model::create(['name' => 'Original', 'version' => '1.0.0', 'managed_model_id' => 'fixture',
            'weight_sha256' => str_repeat('a', 64), 'endpoint_url' => 'https://tuf.internal/predict/fixture/1.0.0', 'is_active' => false]);
        $this->apiAs($token)->putJson('/api/admin/models/'.$model->id, ['version' => '2.0.0'])->assertUnprocessable();
        $this->apiAs($token)->patchJson('/api/admin/models/'.$model->id.'/toggle')->assertConflict();
        $this->apiAs($token)->putJson('/api/admin/models/'.$model->id, ['name' => 'Edited'])->assertOk();
        $this->assertSame('fixture', $model->fresh()->managed_model_id);
    }

    public function test_poll_reconciles_completed_background_publication_and_safe_errors(): void
    {
        config(['model_uploads.internal_url' => 'https://tuf.internal', 'model_uploads.public_url' => 'https://public.tuf',
            'model_uploads.management_token' => 'management', 'model_uploads.inference_token' => 'inference']);
        [$owner, $token] = $this->admin();
        $manifest = $this->manifest();
        $uuid = '11111111-1111-4111-8111-111111111111';
        $upload = ModelUpload::create(['user_id' => $owner->id, 'tuf_id' => $uuid, 'manifest' => $manifest, 'state' => 'ready_for_activate']);
        Http::fake([
            'https://tuf.internal/management/uploads/*' => Http::response(['id' => $uuid, 'manifest' => $manifest,
                'offset' => 100, 'state' => 'ready_for_activate', 'published' => true, 'last_error' => 'unavailable']),
            'https://tuf.internal/models' => Http::response(['models' => [['name' => 'fixture-v1-0-0',
                'display_name' => 'Fixture', 'model_id' => 'fixture', 'version' => '1.0.0', 'sha256' => str_repeat('a', 64),
                'endpoint' => '/predict/fixture/1.0.0', 'active' => false]]]),
            'https://tuf.internal/' => Http::response(['status' => 'ok']),
        ]);
        $this->apiAs($token)->getJson('/api/admin/model-uploads/'.$upload->id)->assertOk()
            ->assertJsonPath('data.last_error', 'unavailable');
        $model = Model::where('managed_model_id', 'fixture')->first();
        $this->assertNotNull($model, 'Background publish completion must register the immutable tuple during polling.');
        $this->assertFalse($model->is_active);
    }

    public function test_manual_targets_cannot_alias_managed_namespace_but_legacy_path_and_display_edits_work(): void
    {
        config(['model_uploads.internal_url' => 'http://worker.internal:8000',
            'model_uploads.public_url' => 'https://shared.example/registry']);
        [, $token] = $this->admin();
        Http::fake(['*' => Http::response(['status' => 'ok'])]);
        foreach (['http://worker.internal:8000/predict/fixture/1.0.0',
            'https://shared.example/registry/predict/fixture/1.0.0',
            'https://SHARED.example:443/registry/../registry/predict/fixture/1.0.0'] as $endpoint) {
            $this->apiAs($token)->postJson('/api/admin/models', ['name' => 'Alias', 'version' => 'v1',
                'endpoint_url' => $endpoint])->assertUnprocessable();
        }
        foreach (['http://worker.internal:8000', 'https://shared.example/registry'] as $base) {
            $this->apiAs($token)->postJson('/api/admin/models/sync', ['base_url' => $base])->assertUnprocessable();
        }
        $legacy = Model::create(['name' => 'Legacy', 'version' => 'v1', 'endpoint_url' => 'https://shared.example/predict']);
        $this->apiAs($token)->putJson('/api/admin/models/'.$legacy->id, ['name' => 'Display edit'])->assertOk();
        $this->assertSame('https://shared.example/predict', $legacy->fresh()->endpoint_url);
        $this->apiAs($token)->putJson('/api/admin/models/'.$legacy->id,
            ['endpoint_url' => 'https://shared.example/registry/predict/fixture/1.0.0'])->assertUnprocessable();
        $this->apiAs($token)->postJson('/api/admin/models', ['name' => 'Other legacy', 'version' => 'v1',
            'endpoint_url' => 'https://shared.example/predict'])->assertCreated();
    }

    public function test_existing_alias_blocks_managed_availability_without_relinking_history(): void
    {
        config(['model_uploads.internal_url' => 'http://worker.internal:8000',
            'model_uploads.public_url' => 'https://shared.example/registry',
            'model_uploads.management_token' => 'management', 'model_uploads.inference_token' => 'inference']);
        [$owner, $token] = $this->admin();
        $model = Model::create(['name' => 'Managed', 'version' => '1.0.0', 'managed_model_id' => 'fixture',
            'weight_sha256' => str_repeat('a', 64), 'endpoint_url' => 'http://worker.internal:8000/predict/fixture/1.0.0',
            'is_active' => true, 'worker_active' => true]);
        $alias = Model::create(['name' => 'Historical alias', 'version' => 'old',
            'endpoint_url' => 'https://shared.example/registry/predict/fixture/1.0.0', 'is_active' => true]);
        $upload = ModelUpload::create(['user_id' => $owner->id, 'tuf_id' => '11111111-1111-4111-8111-111111111111',
            'manifest' => $this->manifest(), 'state' => 'active']);
        Http::fake();
        $this->apiAs($token)->postJson('/api/admin/model-uploads/'.$upload->id.'/deactivate')->assertConflict();
        Http::assertNothingSent();
        $this->assertTrue($model->fresh()->is_active);
        $this->assertNull($alias->fresh()->managed_model_id);
        $this->assertSame('Historical alias', $alias->fresh()->name);
    }
}
